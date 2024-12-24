//
//  ChatViewModel.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//
//  Updates include:
//   - An async memory retrieval call for advanced semantic matching.
//   - Efficient token streaming with batching/throttling.
//   - Truncation of older messages to manage context length.
//   - Summarizing large sets of relevant memories to reduce token usage.
//   - An optional TTS flow, persistent settings, and exportable conversation logs.
//

import SwiftUI
import AVFoundation
import Combine

/// A lightweight wrapper for converting between our MutableMessage type and a codable structure.
/// This helps us persist messages to disk or user defaults.
private struct MessageDTO: Codable {
    let id: UUID
    let text: String
    let isUser: Bool
    let timestamp: Date
    let originProvider: String?
    let originModel: String?

    init(from message: MutableMessage) {
        self.id = message.id
        self.text = message.text
        self.isUser = message.isUser
        self.timestamp = message.timestamp
        self.originProvider = message.originProvider
        self.originModel = message.originModel
    }

    func toMessage() -> MutableMessage {
        MutableMessage(
            id: id,
            text: text,
            isUser: isUser,
            timestamp: timestamp,
            originProvider: originProvider,
            originModel: originModel
        )
    }
}

/// The main ViewModel for our chat application.
/// Manages sending/receiving messages to an AI service, storing/retrieving
/// user memories, voice synthesis, and persistent user settings.
@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The chat messages currently visible in the UI.
    @Published private(set) var messages: [MutableMessage] = []

    /// The user's typed input (bound to a TextField or similar).
    @Published var inputText: String = ""

    /// Indicates whether an AI response is currently streaming/processing.
    @Published var isLoading: Bool = false

    /// The app’s user-configurable settings (API keys, provider choice, etc.).
    @Published private(set) var appSettings: AppSettings

    /// If we encounter an error (e.g. invalid key), store it here to surface in the UI.
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    /// The store managing user "memories" (facts) across sessions.
    @Published var memoryStore: MemoryStore

    // MARK: - Private Services

    private var chatService: ChatServiceProtocol?
    private var voiceService: VoiceServiceProtocol?
    private var activeTask: Task<Void, Never>?
    private var speechTask: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()

    private var openAITTSService: OpenAITTSService?
    private var systemVoiceService: SystemVoiceService?

    // MARK: - Persistence Tools

    private let userDefaults: UserDefaults
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    // MARK: - Token Batching Configuration

    /// Number of tokens to accumulate before flushing to the AI message text.
    private let tokenBatchSize = 5

    /// Max time interval before forcibly flushing tokens, to keep UI responsive.
    private let tokenFlushInterval: TimeInterval = 0.2

    private var tokenBuffer: String = ""
    private var lastFlushDate = Date()
    private var flushTask: Task<Void, Never>? = nil

    // MARK: - Message History Truncation

    /// We keep up to 10 recent user/assistant messages (plus possible summary).
    private let maxHistoryCount = 10

    /// If we prune older messages, we can insert a short placeholder or summary.
    private let truncatedSummaryText =
        "Previous context has been summarized to keep message size manageable."

    // MARK: - Initialization

    /**
     Creates a new ChatViewModel, setting up user defaults and JSON coders,
     plus a MemoryStore for user facts. Optionally provide a custom userDefaults
     (for testing or advanced usage).
     */
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()

        // Load your default app settings
        self.appSettings = AppSettings()

        // Optionally create an EmbeddingService if you want advanced memory
        // e.g. let embeddingService = EmbeddingService(apiKey: "<OPENAI_API_KEY>")
        // and pass it to MemoryStore:
        self.memoryStore = MemoryStore(
            // embeddingService: embeddingService // only if you wish
        )

        setupNotifications()
    }

    // MARK: - Lifecycle Setup

    /**
     Called (for instance) when the app or view first appears.
     Loads persisted settings/messages, sets up the ChatService,
     and finishes any other initialization steps.
     */
    func finalizeSetup() async {
        await loadSettings()
        await loadInitialData()
        initializeChatService(with: appSettings)
        initializeVoiceService(with: appSettings)

        print("[ChatViewModel] Setup complete: Provider = \(appSettings.selectedProvider), Model = \(appSettings.selectedModelId)")
    }

    // MARK: - Masking API Key in Logs

    /**
     Takes an API key string and returns a masked version for logs,
     e.g. "sk-12ab...***...89xy".
     */
    private func maskAPIKey(_ key: String) -> String {
        guard key.count > 8 else { return "***" }
        return "\(key.prefix(4))...***...\(key.suffix(4))"
    }

    // MARK: - Sending Messages

    /**
     Handles the user pressing "Send" or otherwise confirming input.
     - Validates that we have text and a provider key.
     - Appends the user's message to `messages`.
     - Checks if it's a memory command, potentially adds an "ack" response.
     - Triggers the AI flow to get a new response.
     */
    func sendMessage() {
        print("[Debug] Provider: \(appSettings.selectedProvider)")
        print("[Debug] Using API Key: \(maskAPIKey(appSettings.currentAPIKey))")

        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !appSettings.currentAPIKey.isEmpty else {
            print("[ChatViewModel] No valid API key for provider \(appSettings.selectedProvider).")
            handleError(ChatServiceError.invalidAPIKey)
            return
        }

        // 1) Store the user's message in the conversation
        let userMessage = MutableMessage(text: inputText, isUser: true)
        messages.append(userMessage)

        // Save now so we don't lose it
        Task { await saveMessages() }

        // Capture the text, then clear input
        let currentUserText = inputText
        inputText = ""

        // 2) Check if it's a memory command
        if let ackText = processMemoryCommand(currentUserText) {
            // Add an acknowledgment message from the assistant perspective
            let ack = MutableMessage(text: ackText, isUser: false)
            messages.append(ack)
        }

        // 3) Even if it's a memory command, we still want to see an AI response
        isLoading = true
        stopCurrentOperations()

        activeTask = Task {
            await performSendFlow()
        }
    }

    // MARK: - Memory Command Logic

    /**
     Checks if user typed a known memory command:
     - "Remember that ..."
     - "Forget that ..."
     - "Forget everything"
     - "What do you remember about me?"
     If recognized, returns a short assistant text acknowledging the command. Otherwise `nil`.
     */
    private func processMemoryCommand(_ text: String) -> String? {
        let lowered = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if lowered.hasPrefix("remember that ") {
            let content = String(lowered.dropFirst("remember that ".count))
            memoryStore.addMemory(content: content)
            return "Got it! I'll remember that."

        } else if lowered.hasPrefix("forget that ") {
            let content = String(lowered.dropFirst("forget that ".count))
            memoryStore.removeMemory(content: content)
            return "Okay, I've forgotten that."

        } else if lowered == "forget everything" {
            memoryStore.clearAll()
            return "All memories cleared."

        } else if lowered == "what do you remember about me?" {
            // Summarize stored memories
            let allMemories = memoryStore.memories.map {
                "• \($0.content) (on \($0.timestamp.formatted()))"
            }
            if allMemories.isEmpty {
                return "I don't have any memories about you yet."
            } else {
                return "Here's what I remember:\n\n" + allMemories.joined(separator: "\n")
            }
        }

        // Not a recognized command
        return nil
    }

    // MARK: - Stopping Tasks

    /**
     Stops any in-progress chat or voice tasks, sets `isLoading` to false.
     Useful if user taps "Stop" or app goes to background.
     */
    func stopCurrentOperations() {
        stopCurrentSpeech()
        activeTask?.cancel()
        activeTask = nil
        isLoading = false
    }

    // MARK: - Clearing Messages

    /**
     Clears all messages from the current conversation, then persists the empty list.
     */
    func clearMessages() {
        stopCurrentOperations()
        messages.removeAll()
        Task {
            await saveMessages()
        }
        print("[ChatViewModel] Messages cleared.")
    }

    // MARK: - Settings Management

    /**
     Called when the user changes any app settings, such as API key or provider.
     - Re-initializes the chat service if needed.
     - Re-initializes or updates the voice service if TTS changed.
     - Persists the updated settings to user defaults.
     */
    func updateAppSettings(_ newSettings: AppSettings) {
        stopCurrentOperations()

        let oldProvider = appSettings.selectedProvider
        let oldVoiceProvider = appSettings.selectedVoiceProvider
        let oldSystemVoiceId = appSettings.selectedSystemVoiceId
        let oldOpenAIVoice = appSettings.selectedOpenAIVoice
        let oldOpenAIKey = appSettings.openAIKey

        appSettings = newSettings

        if appSettings.currentAPIKey.isEmpty {
            print("[ChatViewModel] Warning: Provider \(appSettings.selectedProvider) selected without a valid key.")
        }

        // Re-init chat service if provider or key changed
        if oldProvider != newSettings.selectedProvider ||
           appSettings.currentAPIKey != newSettings.currentAPIKey {
            initializeChatService(with: newSettings)
        }

        // Re-init voice service if TTS settings changed
        if oldVoiceProvider != newSettings.selectedVoiceProvider ||
           oldSystemVoiceId != newSettings.selectedSystemVoiceId ||
           oldOpenAIVoice != newSettings.selectedOpenAIVoice ||
           oldOpenAIKey != newSettings.openAIKey {
            updateVoiceService(with: newSettings, oldVoiceProvider: oldVoiceProvider)
        }

        Task { await saveSettings() }
        print("[ChatViewModel] App settings updated and saved.")
    }

    // MARK: - App Lifecycle Notifications

    /**
     Subscribes to notifications (e.g. willResignActive) so we can
     stop tasks if user backgrounds the app.
     */
    private func setupNotifications() {
        NotificationCenter.default
            .publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.stopCurrentOperations()
            }
            .store(in: &subscriptions)
    }

    // MARK: - Chat Service Initialization

    /**
     Creates or re-creates a chat service instance based on the current AppSettings.
     Typically called when user changes provider or API key.
     */
    private func initializeChatService(with settings: AppSettings) {
        guard !settings.currentAPIKey.isEmpty else {
            chatService = nil
            print("[ChatViewModel] No valid API key for provider \(settings.selectedProvider).")
            return
        }

        switch settings.selectedProvider {
        case .openAI:
            chatService = OpenAIChatService(apiKey: settings.openAIKey)
            print("[ChatViewModel] Initialized OpenAI Chat Service with key: \(maskAPIKey(settings.openAIKey))")

        case .anthropic:
            chatService = AnthropicService(apiKey: settings.anthropicKey)
            print("[ChatViewModel] Initialized Anthropic Chat Service with key: \(maskAPIKey(settings.anthropicKey))")

        case .githubModel:
            chatService = GitHubModelChatService(apiKey: settings.githubToken)
            print("[ChatViewModel] Initialized GitHub Model Chat Service with key: \(maskAPIKey(settings.githubToken))")
        }
    }

    // MARK: - Voice Service Initialization

    /**
     Sets up or tears down text-to-speech services, based on the user’s chosen TTS provider.
     */
    private func initializeVoiceService(with settings: AppSettings) {
        stopCurrentSpeech()

        switch settings.selectedVoiceProvider {
        case .system:
            let systemService = SystemVoiceService(voiceIdentifier: settings.selectedSystemVoiceId)
            self.systemVoiceService = systemService
            self.voiceService = systemService
            print("[ChatViewModel] Initialized system voice with ID: \(settings.selectedSystemVoiceId)")

        case .openAI:
            guard !settings.openAIKey.isEmpty else {
                voiceService = nil
                openAITTSService = nil
                print("[ChatViewModel] No OpenAI API key provided for TTS.")
                return
            }
            let openAIService = OpenAITTSService(apiKey: settings.openAIKey,
                                                 voiceId: settings.selectedOpenAIVoice)
            self.openAITTSService = openAIService
            self.voiceService = openAIService
            print("[ChatViewModel] Initialized OpenAI voice with ID: \(settings.selectedOpenAIVoice)")
        }
    }

    /**
     If only certain TTS settings changed (like the voice ID), we can update
     rather than recreate the entire voice service, if desired.
     */
    private func updateVoiceService(with settings: AppSettings,
                                    oldVoiceProvider: VoiceProvider) {
        stopCurrentSpeech()

        if oldVoiceProvider == settings.selectedVoiceProvider {
            switch settings.selectedVoiceProvider {
            case .system:
                let systemService = SystemVoiceService(voiceIdentifier: settings.selectedSystemVoiceId)
                self.systemVoiceService = systemService
                self.voiceService = systemService
                print("[ChatViewModel] Updated system voice to: \(settings.selectedSystemVoiceId)")

            case .openAI:
                if let service = openAITTSService {
                    service.updateVoice(settings.selectedOpenAIVoice)
                    print("[ChatViewModel] Updated OpenAI voice to: \(settings.selectedOpenAIVoice)")
                } else {
                    initializeVoiceService(with: settings)
                }
            }
        } else {
            initializeVoiceService(with: settings)
        }
    }

    // MARK: - Load/Save Settings and Messages

    /**
     Asynchronously loads any persisted app settings from `UserDefaults`.
     If none found, uses defaults in `AppSettings` (like an empty API key).
     */
    private func loadSettings() async {
        if let savedSettings = userDefaults.data(forKey: "appSettingsData"),
           let decodedSettings = try? decoder.decode(AppSettings.self, from: savedSettings) {
            self.appSettings = decodedSettings
            print("[ChatViewModel] Loaded saved app settings.")
        } else {
            print("[ChatViewModel] Using default app settings.")
        }
    }

    /**
     Loads the saved chat messages from `UserDefaults`. If none found, starts empty.
     */
    func loadInitialData() async {
        if let savedMessages = userDefaults.data(forKey: "savedMessages"),
           let decodedMessages = try? decoder.decode([MessageDTO].self, from: savedMessages) {
            self.messages = decodedMessages.map { $0.toMessage() }
            print("[ChatViewModel] Loaded saved messages.")
        } else {
            print("[ChatViewModel] No saved messages found.")
        }
    }

    /**
     Encodes the current `messages` array to JSON and persists it in `UserDefaults`.
     */
    private func saveMessages() async {
        guard let encoded = try? encoder.encode(messages.map { MessageDTO(from: $0) }) else { return }
        userDefaults.set(encoded, forKey: "savedMessages")
        print("[ChatViewModel] Messages saved.")
    }

    /**
     Persists the current `appSettings` to `UserDefaults`.
     */
    private func saveSettings() async {
        guard let encoded = try? encoder.encode(appSettings) else { return }
        userDefaults.set(encoded, forKey: "appSettingsData")
        print("[ChatViewModel] App settings saved.")
    }

    // MARK: - Main Send Flow (Chat Completion)

    /**
     Orchestrates sending the user’s message to the chosen AI service,
     then processes the streaming response tokens as they arrive.
     */
    private func performSendFlow() async {
        print("[ChatViewModel] Sending message to API...")

        // Create a placeholder AI message that we'll populate with tokens
        let aiMessage = MutableMessage(
            text: "",
            isUser: false,
            originProvider: appSettings.selectedProvider.rawValue,
            originModel: appSettings.selectedModel.name
        )
        messages.append(aiMessage)

        do {
            guard let service = chatService else {
                throw ChatServiceError.invalidAPIKey
            }

            // Build the chat payload (and possibly truncate older messages)
            // Note: We call `await` now, because prepareMessagesPayload might do async retrieval
            let payload = await prepareMessagesPayload()

            // Insert a system message if needed (OpenAI or GitHub)
            if (appSettings.selectedProvider == .openAI || appSettings.selectedProvider == .githubModel),
               !appSettings.systemMessage.isEmpty {
                // Prepend a system message
                var updated = payload
                updated.insert(["role": "system", "content": appSettings.systemMessage], at: 0)

                // For the Anthropic provider, we pass `systemMessage` separately below.
                let systemMessage = appSettings.selectedProvider == .anthropic
                    ? (appSettings.systemMessage.isEmpty ? nil : appSettings.systemMessage)
                    : nil

                // Now request streaming from the chat service
                let stream = try await service.streamCompletion(
                    messages: updated,
                    model: appSettings.selectedModelId,
                    system: systemMessage
                )
                let completeResponse = try await handleResponseStream(stream, aiMessage: aiMessage)
                await finalizeResponseProcessing(completeResponse: completeResponse)
            }
            else {
                // If not OpenAI or GitHub, handle Anthropic or other providers similarly
                let systemMessage = appSettings.selectedProvider == .anthropic
                    ? (appSettings.systemMessage.isEmpty ? nil : appSettings.systemMessage)
                    : nil

                let stream = try await service.streamCompletion(
                    messages: payload,
                    model: appSettings.selectedModelId,
                    system: systemMessage
                )
                let completeResponse = try await handleResponseStream(stream, aiMessage: aiMessage)
                await finalizeResponseProcessing(completeResponse: completeResponse)
            }
        } catch {
            print("[ChatViewModel] Error fetching response: \(error)")
            handleError(error)
            removeLastAIMessage()
        }

        isLoading = false
    }

    /**
     After we receive the final AI text, decide if we should remove the placeholder
     (in case it’s empty) or speak the message. Then persist messages.
     */
    private func finalizeResponseProcessing(completeResponse: String) async {
        print("[ChatViewModel] Received response: \(completeResponse)")
        let trimmed = completeResponse.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty, let last = messages.last, !last.isUser {
            messages.removeLast()
        } else {
            speakMessage(trimmed)
            await saveMessages()
        }
    }

    // MARK: - Incorporating Memories

    /**
     Builds the payload of user/assistant messages to send to the AI, optionally retrieving
     relevant user memories if an advanced memory system is in place. This function is async
     because memory retrieval can involve embeddings or network calls.
     */
    private func prepareMessagesPayload() async -> [[String: String]] {
        var messagesPayload: [[String: String]] = []

        // 1) If there's a last user message, see if we can retrieve relevant user facts.
        if let lastUserMsg = messages.last(where: { $0.isUser })?.text {
            // If you have an embedding-based MemoryStore, call it async:
            // let relevantMemories = await memoryStore.retrieveRelevant(to: lastUserMsg, topK: 5)
            //
            // If your MemoryStore is substring-based only, you can remove the 'await':
            // let relevantMemories = memoryStore.retrieveRelevant(to: lastUserMsg)
            let relevantMemories = await memoryStore.retrieveRelevant(to: lastUserMsg, topK: 5)

            // If any relevant memories found, inject them as a system message.
            if !relevantMemories.isEmpty {
                if relevantMemories.count > 5 {
                    // Summarize if we have many relevant memories
                    let shortSummary = summarizeMemories(relevantMemories)
                    messagesPayload.append([
                        "role": "system",
                        "content": shortSummary
                    ])
                } else {
                    let bulletList = relevantMemories
                        .map { "- \($0.content)" }
                        .joined(separator: "\n")
                    messagesPayload.append([
                        "role": "system",
                        "content": "Relevant facts:\n\(bulletList)"
                    ])
                }
            }
        }

        // 2) Next, gather existing messages (excluding the newly appended AI placeholder)
        var truncatedMessages = Array(messages.dropLast())

        // If we have more than maxHistoryCount, prune older ones
        if truncatedMessages.count > maxHistoryCount {
            let olderCount = truncatedMessages.count - maxHistoryCount
            truncatedMessages.removeFirst(olderCount)

            // Optionally insert a short summary placeholder or an actual summary
            truncatedMessages.insert(.init(
                id: UUID(),
                text: truncatedSummaryText,
                isUser: false
            ), at: 0)
        }

        // Convert truncated messages to the standard format
        for message in truncatedMessages {
            let cleaned = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { continue }

            messagesPayload.append([
                "role": message.isUser ? "user" : "assistant",
                "content": cleaned
            ])
        }

        return messagesPayload
    }

    /**
     Summarizes a large list of relevant memories into one short paragraph
     to reduce token usage and keep the prompt concise. A naive approach:
     just concatenates them. In production, you could call an LLM or do
     more advanced summarizing.
     */
    private func summarizeMemories(_ memories: [Memory]) -> String {
        let allContent = memories.map { $0.content }.joined(separator: ". ")
        return "Summary of user's known information: \(allContent)."
    }

    // MARK: - Stream Handling

    /**
     Consumes tokens from an AsyncThrowingStream (provided by the chat service)
     and progressively updates the AI message text in the UI. Supports haptic
     feedback and a flush mechanism to keep partial text responsive.
     */
    private func handleResponseStream(
        _ stream: AsyncThrowingStream<String, Error>,
        aiMessage: MutableMessage
    ) async throws -> String {
        var completeResponse = ""
        var tokenCount = 0

        let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
        let finalFeedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.prepare()
        finalFeedbackGenerator.prepare()

        tokenBuffer = ""
        lastFlushDate = Date()
        flushTask?.cancel()
        flushTask = nil

        for try await content in stream {
            if Task.isCancelled { break }

            tokenBuffer.append(content)
            completeResponse.append(content)
            tokenCount += 1

            // Flush tokens in batches
            if tokenCount % tokenBatchSize == 0 {
                await flushTokens(aiMessage: aiMessage)
            } else {
                scheduleFlush(aiMessage: aiMessage)
            }

            // Haptic feedback every 5 tokens
            if tokenCount % 5 == 0 {
                feedbackGenerator.impactOccurred()
            }
        }

        // Ensure any leftover tokens are applied at the end
        await flushTokens(aiMessage: aiMessage, force: true)
        finalFeedbackGenerator.notificationOccurred(.success)

        return completeResponse
    }

    /**
     If we haven't flushed tokens in a while, schedule a flush after tokenFlushInterval
     unless new tokens come in. This keeps partial text from building up too long.
     */
    private func scheduleFlush(aiMessage: MutableMessage) {
        flushTask?.cancel()
        flushTask = Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.tokenFlushInterval * 1_000_000_000))
            await self.flushTokens(aiMessage: aiMessage)
        }
    }

    /**
     Moves any accumulated tokens into the final AI message text. If `force` is true,
     flushes even if we haven't hit the batch size or time limit.
     */
    private func flushTokens(aiMessage: MutableMessage, force: Bool = false) async {
        guard force || !tokenBuffer.isEmpty else { return }

        let tokensToApply = tokenBuffer
        tokenBuffer = ""

        aiMessage.text.append(tokensToApply)
        objectWillChange.send()
        lastFlushDate = Date()
    }

    // MARK: - Error Handling

    /**
     Processes an error from chat or TTS. If it's a known ChatServiceError,
     set a user-facing message. Otherwise, show a generic error.
     */
    private func handleError(_ error: Error) {
        if let chatError = error as? ChatServiceError {
            switch chatError {
            case .invalidAPIKey:
                errorMessage = """
                No valid API key found for \(appSettings.selectedProvider.rawValue). \
                Please open Settings and enter a valid API key.
                """
            default:
                errorMessage = chatError.errorDescription
            }
        } else {
            errorMessage = "An unexpected error occurred"
        }
        showError = true
        print("[ChatViewModel] Error: \(errorMessage ?? "Unknown error")")
    }

    /**
     If the last message is from the AI, remove it—used when an error occurs
     or if the response was empty.
     */
    private func removeLastAIMessage() {
        if let last = messages.last, !last.isUser {
            messages.removeLast()
        }
    }

    // MARK: - Speech Handling

    /**
     Stops any in-progress speech synthesis tasks.
     */
    private func stopCurrentSpeech() {
        speechTask?.cancel()
        speechTask = nil
        voiceService?.stop()
    }

    /**
     If the user enabled `autoplayVoice` in settings, speak the AI's response text asynchronously.
     */
    private func speakMessage(_ text: String) {
        guard appSettings.autoplayVoice, !text.isEmpty else { return }

        speechTask?.cancel()
        speechTask = Task {
            do {
                try await voiceService?.speak(text)
                print("[ChatViewModel] Speech completed successfully.")
            } catch {
                print("[ChatViewModel] Speech error: \(error)")
                // Optionally add fallback logic if TTS fails
            }
        }
    }

    /**
     Optionally updates the last assistant message if you want to do partial updates
     without creating new messages. Currently not widely used in this flow.
     */
    private func updateLastAssistantMessage(with content: String) {
        if let lastMessage = messages.last, !lastMessage.isUser {
            lastMessage.text.append(content)
            objectWillChange.send()
        }
    }

    // MARK: - Exporting Conversation

    /**
     Generates a temporary JSON file containing the entire conversation. Useful
     if the user wants to export or back up their chat session.
     - Returns: The file URL if successful, or `nil` on error.
     */
    func exportConversationAsJSONFile() -> URL? {
        let messageDTOs = messages.map { MessageDTO(from: $0) }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(messageDTOs)

            let tempDir = FileManager.default.temporaryDirectory
            let filename = "conversation-\(UUID().uuidString).json"
            let fileURL = tempDir.appendingPathComponent(filename)

            try jsonData.write(to: fileURL, options: .atomic)
            print("[ChatViewModel] Exported conversation to file: \(fileURL)")
            return fileURL
        } catch {
            print("[ChatViewModel] Export error: \(error)")
            return nil
        }
    }

    // MARK: - Deinit

    deinit {
        print("[ChatViewModel] Deinitialized.")
    }
}
