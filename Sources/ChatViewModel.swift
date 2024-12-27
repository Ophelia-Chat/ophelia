//
//  ChatViewModel.swift
//  Ophelia
//
//  Description:
//  This file defines the primary ViewModel (ChatViewModel) for managing the chat experience.
//  It coordinates sending user messages, receiving AI responses, and orchestrating memory storage,
//  voice synthesis, and persistent user settings.
//
//  Dependencies (external to this file):
//  - MutableMessage: A class representing a single chat message (with text, timestamps, etc.).
//  - ChatServiceProtocol & concrete implementations (e.g. OpenAIChatService, AnthropicService, GitHubModelChatService)
//  - VoiceServiceProtocol & concrete implementations (e.g. OpenAITTSService, SystemVoiceService)
//  - AppSettings: Stores user preferences & credentials
//  - MemoryStore: Handles user "memories" across sessions
//  - ChatServiceError: An enum describing possible error states from the chat service
//  - MessageDTO: A Codable struct that helps persist messages to disk/user defaults
//  - iOS-specific frameworks (UIKit, SwiftUI, Combine, AVFoundation) used for background tasks,
//    notifications, speech, etc.
//
//  Created by rob on 2024-11-27.
//  Updated & refined for best practices and inline documentation.
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

    /// Creates a new DTO from a MutableMessage, capturing all relevant fields for serialization.
    init(from message: MutableMessage) {
        self.id = message.id
        self.text = message.text
        self.isUser = message.isUser
        self.timestamp = message.timestamp
        self.originProvider = message.originProvider
        self.originModel = message.originModel
    }

    /// Recreates a MutableMessage from the DTO. Useful when loading saved data.
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

/// The main ViewModel for the chat application.
/// Manages sending/receiving messages from an AI service, storing/retrieving user memories,
/// handling voice synthesis (TTS), and maintaining persistent user settings.
///
/// **Key Responsibilities:**
/// - Storing and displaying the list of chat messages (`messages`).
/// - Handling user input (`inputText`) and sending messages to the AI model.
/// - Integrating with MemoryStore to embed user "memories" (facts) in prompts.
/// - Managing user settings (API keys, model choices, TTS preferences) via AppSettings.
/// - Persisting messages and settings to UserDefaults.
/// - Providing a mechanism to export the conversation as JSON.
@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The chat messages currently visible in the UI.
    @Published private(set) var messages: [MutableMessage] = []

    /// The user's typed input (bound to a TextField or similar).
    @Published var inputText: String = ""

    /// Indicates whether an AI response is currently streaming or processing.
    @Published var isLoading: Bool = false

    /// The app’s user-configurable settings (API keys, provider choice, etc.).
    @Published private(set) var appSettings: AppSettings

    /// If an error (e.g. invalid key) occurs, store the message here to surface in the UI.
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    /// The store managing user "memories" (facts) across sessions.
    @Published var memoryStore: MemoryStore

    // MARK: - Private Services

    /// Service responsible for sending requests and streaming AI responses.
    private var chatService: ChatServiceProtocol?

    /// Service responsible for text-to-speech.
    private var voiceService: VoiceServiceProtocol?

    /// Handles ongoing chat tasks (so they can be cancelled if needed).
    private var activeTask: Task<Void, Never>?

    /// Handles ongoing speech tasks (so they can be cancelled if needed).
    private var speechTask: Task<Void, Never>?

    /// For handling various Combine subscriptions (e.g., notifications).
    private var subscriptions = Set<AnyCancellable>()

    /// Concrete TTS services (for both OpenAI and system-based).
    private var openAITTSService: OpenAITTSService?
    private var systemVoiceService: SystemVoiceService?

    // MARK: - Persistence Tools

    /// Reference to UserDefaults for reading/writing settings and messages.
    private let userDefaults: UserDefaults

    /// JSON decoders/encoders for saving/loading messages and settings.
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    // MARK: - Token Batching Configuration

    /// Number of tokens to accumulate before flushing to the AI message text.
    private let tokenBatchSize = 5

    /// Max time interval before forcibly flushing tokens, to keep UI responsive.
    private let tokenFlushInterval: TimeInterval = 0.2

    /// Accumulates tokens as they stream in, so we can update the UI in batches.
    private var tokenBuffer: String = ""

    /// Track the time we last flushed tokens, to handle forced flush scheduling.
    private var lastFlushDate = Date()

    /// A scheduled task for automatically flushing tokens if no new tokens arrive soon.
    private var flushTask: Task<Void, Never>? = nil

    // MARK: - Message History Truncation

    /// We keep up to 10 recent user/assistant messages (plus possibly a summary).
    private let maxHistoryCount = 10

    /// If older messages are pruned, this placeholder text notes that a summary was performed.
    private let truncatedSummaryText =
    "Previous context has been summarized to keep message size manageable."

    // MARK: - Initialization

    /**
     Initializes a new `ChatViewModel`, setting up default user settings and memory store.
     - Parameter userDefaults: The UserDefaults instance to use for loading/saving settings and messages.
     */
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()

        // Load default app settings (they can later be overwritten by loadSettings()).
        self.appSettings = AppSettings()

        // Initialize the memory store (optionally with an embedding service).
        self.memoryStore = MemoryStore(
            // embeddingService: ...
        )

        setupNotifications()
    }

    // MARK: - Lifecycle Setup

    /**
     Called when the app or view first appears.
     Loads persisted settings and messages, sets up the chosen chat/voice services,
     and completes initialization.
     */
    func finalizeSetup() async {
        await loadSettings()
        await loadInitialData()
        initializeChatService(with: appSettings)
        initializeVoiceService(with: appSettings)

        print("[ChatViewModel] Setup complete: Provider = \(appSettings.selectedProvider), Model = \(appSettings.selectedModelId)")
    }

    // MARK: - Masking API Keys

    /**
     Returns a masked version of the given API key for safe logging, e.g. "sk-12ab...***...89xy".
     - Parameter key: The actual API key string.
     - Returns: A partially masked string suitable for logs.
     */
    private func maskAPIKey(_ key: String) -> String {
        guard key.count > 8 else { return "***" }
        return "\(key.prefix(4))...***...\(key.suffix(4))"
    }

    // MARK: - Sending Messages

    /**
     Called when the user presses "Send" or confirms input in the chat UI.
     - Validates that we have text and a provider key.
     - Stores the user's message in `messages`.
     - Checks if the input is a memory command (e.g. "remember that ..."), and handles if so.
     - Initiates the AI completion flow to get the assistant’s response.
     */
    func sendMessage() {
        print("[Debug] Provider: \(appSettings.selectedProvider)")
        print("[Debug] Using API Key: \(maskAPIKey(appSettings.currentAPIKey))")

        // 1) Validate non-empty input and valid API key.
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !appSettings.currentAPIKey.isEmpty else {
            print("[ChatViewModel] No valid API key for provider \(appSettings.selectedProvider).")
            handleError(ChatServiceError.invalidAPIKey)
            return
        }

        // 2) Append the user's message to the conversation.
        let userMessage = MutableMessage(text: inputText, isUser: true)
        messages.append(userMessage)

        // Persist messages so we don't lose them if the app closes.
        Task { await saveMessages() }

        // Capture the user text; clear the input field.
        let currentUserText = inputText
        inputText = ""

        // 3) Check if it's a recognized memory command, and respond if so.
        if let ackText = processMemoryCommand(currentUserText) {
            let ack = MutableMessage(text: ackText, isUser: false)
            messages.append(ack)
        }

        // 4) Regardless of memory commands, we request an AI response next.
        isLoading = true
        stopCurrentOperations()

        activeTask = Task {
            await performSendFlow()
        }
    }

    // MARK: - Memory Command Logic

    /**
     Checks if user typed a known memory command:
     - "remember that ..."
     - "forget that ..."
     - "forget everything"
     - "what do you remember about me?"
     If recognized, returns an assistant response acknowledging the command.
     Otherwise returns `nil`.
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
            let allMemories = memoryStore.memories.map {
                "• \($0.content) (on \($0.timestamp.formatted()))"
            }
            if allMemories.isEmpty {
                return "I don't have any memories about you yet."
            } else {
                return "Here's what I remember:\n\n" + allMemories.joined(separator: "\n")
            }
        }

        return nil
    }

    // MARK: - Managing Tasks

    /**
     Stops any in-progress chat or voice tasks, and resets `isLoading`.
     Useful if the user cancels or the app background/foreground changes.
     */
    func stopCurrentOperations() {
        stopCurrentSpeech()
        activeTask?.cancel()
        activeTask = nil
        isLoading = false
    }

    // MARK: - Clearing Messages

    /**
     Removes all messages from the current session, then persists the updated empty state.
     */
    func clearMessages() {
        stopCurrentOperations()
        messages.removeAll()
        Task { await saveMessages() }
        print("[ChatViewModel] Messages cleared.")
    }

    // MARK: - Settings Management

    /**
     Updates the ViewModel with a new `AppSettings` object (possibly from the UI).
     - Stops current tasks.
     - Re-initializes services if the provider or TTS settings changed.
     - Persists updated settings to disk.
     */
    func updateAppSettings(_ newSettings: AppSettings) {
        stopCurrentOperations()

        // Capture old states to see what changed.
        let oldProvider = appSettings.selectedProvider
        let oldVoiceProvider = appSettings.selectedVoiceProvider
        let oldSystemVoiceId = appSettings.selectedSystemVoiceId
        let oldOpenAIVoice = appSettings.selectedOpenAIVoice
        let oldOpenAIKey = appSettings.openAIKey

        appSettings = newSettings

        // Warn if the new provider has no key set.
        if appSettings.currentAPIKey.isEmpty {
            print("[ChatViewModel] Warning: Provider \(appSettings.selectedProvider) selected without a valid key.")
        }

        // If provider or API key changed, re-init the chat service.
        if oldProvider != newSettings.selectedProvider ||
           appSettings.currentAPIKey != newSettings.currentAPIKey {
            initializeChatService(with: newSettings)
        }

        // If TTS settings changed, re-init or update the voice service.
        if oldVoiceProvider != newSettings.selectedVoiceProvider ||
           oldSystemVoiceId != newSettings.selectedSystemVoiceId ||
           oldOpenAIVoice != newSettings.selectedOpenAIVoice ||
           oldOpenAIKey != newSettings.openAIKey {
            updateVoiceService(with: newSettings, oldVoiceProvider: oldVoiceProvider)
        }

        // Persist new settings.
        Task { await saveSettings() }
        print("[ChatViewModel] App settings updated and saved.")
    }

    // MARK: - App Lifecycle Notifications

    /**
     Subscribes to `UIApplication.willResignActiveNotification` so we can
     stop chat or speech tasks if the app is backgrounded.
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
     Sets up or re-sets the chat service based on the current provider and API key.
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
     Sets up or tears down the TTS services based on the user’s chosen TTS provider.
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
     Called when TTS-specific settings change (e.g., switching voices).
     If the TTS provider remains the same, we can sometimes just update the service.
     Otherwise, we re-initialize from scratch.
     */
    private func updateVoiceService(with settings: AppSettings,
                                    oldVoiceProvider: VoiceProvider) {
        stopCurrentSpeech()

        // If the voice provider is the same, we may only need to update its voice setting.
        if oldVoiceProvider == settings.selectedVoiceProvider {
            switch settings.selectedVoiceProvider {
            case .system:
                let systemService = SystemVoiceService(voiceIdentifier: settings.selectedSystemVoiceId)
                self.systemVoiceService = systemService
                self.voiceService = systemService
                print("[ChatViewModel] Updated system voice to: \(settings.selectedSystemVoiceId)")

            case .openAI:
                // If we already have an OpenAITTSService, just update its voice.
                if let service = openAITTSService {
                    service.updateVoice(settings.selectedOpenAIVoice)
                    print("[ChatViewModel] Updated OpenAI voice to: \(settings.selectedOpenAIVoice)")
                } else {
                    initializeVoiceService(with: settings)
                }
            }
        } else {
            // Provider changed entirely, do a full re-init.
            initializeVoiceService(with: settings)
        }
    }

    // MARK: - Load/Save Settings and Messages

    /**
     Loads any saved AppSettings from UserDefaults, replacing the defaults if found.
     */
    private func loadSettings() async {
        if let savedSettingsData = userDefaults.data(forKey: "appSettingsData"),
           let decodedSettings = try? decoder.decode(AppSettings.self, from: savedSettingsData) {
            self.appSettings = decodedSettings
            print("[ChatViewModel] Loaded saved app settings.")
        } else {
            print("[ChatViewModel] Using default app settings.")
        }
    }

    /**
     Loads the saved conversation messages from UserDefaults. If none found, starts empty.
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
     Persists the current list of messages to UserDefaults by encoding them into JSON.
     */
    private func saveMessages() async {
        guard let encoded = try? encoder.encode(messages.map { MessageDTO(from: $0) }) else { return }
        userDefaults.set(encoded, forKey: "savedMessages")
        print("[ChatViewModel] Messages saved.")
    }

    /**
     Persists the current AppSettings to UserDefaults by encoding to JSON.
     */
    private func saveSettings() async {
        guard let encoded = try? encoder.encode(appSettings) else { return }
        userDefaults.set(encoded, forKey: "appSettingsData")
        print("[ChatViewModel] App settings saved.")
    }

    // MARK: - Main Send Flow (Chat Completion)

    /**
     Coordinates sending the user message to the AI service, then receiving and handling the
     streaming response tokens. Also manages insertion of system messages (e.g. instructions).
     */
    private func performSendFlow() async {
        print("[ChatViewModel] Sending message to API...")

        // 1) Create a placeholder AI message that we'll update with streaming tokens.
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

            // 2) Build the list of messages to send, possibly including relevant memories.
            let payload = await prepareMessagesPayload()

            // 3) If using OpenAI or GitHub, prepend a system message to the conversation if set.
            if (appSettings.selectedProvider == .openAI || appSettings.selectedProvider == .githubModel),
               !appSettings.systemMessage.isEmpty {
                var updated = payload
                updated.insert(["role": "system", "content": appSettings.systemMessage], at: 0)

                // For Anthropic, we pass the system message separately instead of as a list item.
                let systemMessage = (appSettings.selectedProvider == .anthropic && !appSettings.systemMessage.isEmpty)
                                    ? appSettings.systemMessage
                                    : nil

                // Stream the response.
                let stream = try await service.streamCompletion(
                    messages: updated,
                    model: appSettings.selectedModelId,
                    system: systemMessage
                )
                let completeResponse = try await handleResponseStream(stream, aiMessage: aiMessage)
                await finalizeResponseProcessing(completeResponse: completeResponse)

            } else {
                // For Anthropic or other providers, handle system messages differently.
                let systemMessage = (appSettings.selectedProvider == .anthropic && !appSettings.systemMessage.isEmpty)
                                    ? appSettings.systemMessage
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
            // If we fail to fetch a response, handle the error and remove the empty AI placeholder.
            print("[ChatViewModel] Error fetching response: \(error)")
            handleError(error)
            removeLastAIMessage()
        }

        isLoading = false
    }

    /**
     Once the complete text of the AI response is obtained, decides whether to remove
     an empty placeholder or keep the message and optionally speak it. Then persists messages.
     */
    private func finalizeResponseProcessing(completeResponse: String) async {
        print("[ChatViewModel] Received response: \(completeResponse)")

        let trimmed = completeResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty, let last = messages.last, !last.isUser {
            // If the AI message is empty, remove the placeholder.
            messages.removeLast()
        } else {
            // If we have text, optionally speak it if autoplay is on.
            speakMessage(trimmed)
            await saveMessages()
        }
    }

    // MARK: - Incorporating Memories

    /**
     Constructs the list of user/assistant messages to be sent to the AI service,
     optionally appending relevant user "memories" as system content. Prunes older messages
     if the conversation is very long, to reduce token usage.
     */
    private func prepareMessagesPayload() async -> [[String: String]] {
        var messagesPayload: [[String: String]] = []

        // 1) Check the last user message to see if we can retrieve relevant memories.
        if let lastUserMsg = messages.last(where: { $0.isUser })?.text {
            // Memory retrieval can be async if it involves embeddings or network requests.
            let relevantMemories = await memoryStore.retrieveRelevant(to: lastUserMsg, topK: 5)

            if !relevantMemories.isEmpty {
                if relevantMemories.count > 5 {
                    // Summarize if there are many relevant memories.
                    let shortSummary = summarizeMemories(relevantMemories)
                    messagesPayload.append(["role": "system", "content": shortSummary])
                } else {
                    // Otherwise, insert them as bullet-list facts.
                    let bulletList = relevantMemories
                        .map { "- \($0.content)" }
                        .joined(separator: "\n")
                    messagesPayload.append(["role": "system", "content": "Relevant facts:\n\(bulletList)"])
                }
            }
        }

        // 2) Exclude the newly appended AI placeholder from the conversation history.
        var truncatedMessages = Array(messages.dropLast())

        // If we have more messages than allowed, prune the oldest.
        if truncatedMessages.count > maxHistoryCount {
            let olderCount = truncatedMessages.count - maxHistoryCount
            truncatedMessages.removeFirst(olderCount)

            // Insert a summary placeholder so the user knows older content was truncated.
            truncatedMessages.insert(MutableMessage(
                id: UUID(),
                text: truncatedSummaryText,
                isUser: false
            ), at: 0)
        }

        // 3) Convert truncated messages into the format the AI expects (role, content).
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
     Summarizes a list of memories into a short string to reduce token usage.
     Could be improved by calling a separate summarization routine or LLM.
     */
    private func summarizeMemories(_ memories: [Memory]) -> String {
        let allContent = memories.map { $0.content }.joined(separator: ". ")
        return "Summary of user's known information: \(allContent)."
    }

    // MARK: - Stream Handling

    /**
     Consumes tokens from an `AsyncThrowingStream<String, Error>` (provided by the chat service),
     progressively appending them to the AI message in the UI. Supports batching and haptic feedback.
     - Parameter stream: The async stream of partial text tokens.
     - Parameter aiMessage: The placeholder AI message to which tokens are appended.
     - Returns: The final concatenated response from the AI.
     */
    private func handleResponseStream(
        _ stream: AsyncThrowingStream<String, Error>,
        aiMessage: MutableMessage
    ) async throws -> String {
        var completeResponse = ""
        var tokenCount = 0

        // Prepare haptic feedback
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
        let finalFeedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.prepare()
        finalFeedbackGenerator.prepare()

        // Reset token buffering
        tokenBuffer = ""
        lastFlushDate = Date()
        flushTask?.cancel()
        flushTask = nil

        // Consume tokens as they arrive.
        for try await content in stream {
            if Task.isCancelled { break }

            tokenBuffer.append(content)
            completeResponse.append(content)
            tokenCount += 1

            // Flush every tokenBatchSize tokens for responsiveness.
            if tokenCount % tokenBatchSize == 0 {
                await flushTokens(aiMessage: aiMessage)
            } else {
                scheduleFlush(aiMessage: aiMessage)
            }

            // Provide light haptic feedback every 5 tokens.
            if tokenCount % 5 == 0 {
                feedbackGenerator.impactOccurred()
            }
        }

        // Ensure we flush any leftover tokens at the end.
        await flushTokens(aiMessage: aiMessage, force: true)
        finalFeedbackGenerator.notificationOccurred(.success)

        return completeResponse
    }

    /**
     Schedules a flush after `tokenFlushInterval` if no further tokens arrive,
     preventing partial text from building up too long.
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
     Moves any accumulated tokens into the AI message text.
     - Parameter aiMessage: The AI message being updated.
     - Parameter force: If `true`, flushes even if batch/time thresholds aren't reached.
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
     Sets an error message for display if the error is recognized as a ChatServiceError,
     otherwise displays a generic fallback. Triggers a UI alert or error banner.
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
     If the last message is from the AI (i.e., a placeholder), remove it—useful if the response
     is empty or if an error occurs.
     */
    private func removeLastAIMessage() {
        if let last = messages.last, !last.isUser {
            messages.removeLast()
        }
    }

    // MARK: - Speech Handling

    /**
     Stops any currently playing TTS.
     */
    private func stopCurrentSpeech() {
        speechTask?.cancel()
        speechTask = nil
        voiceService?.stop()
    }

    /**
     If `autoplayVoice` is enabled in settings, speaks the AI response with the chosen TTS provider.
     - Parameter text: The AI’s response to be spoken aloud.
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
            }
        }
    }

    /**
     Helper for partial updating of the last assistant message, if you want to append partial text
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
     Creates a temporary JSON file containing the entire conversation. Useful for export/share.
     - Returns: The file URL if successful, or `nil` on failure.
     */
    func exportConversationAsJSONFile() -> URL? {
        let messageDTOs = messages.map { MessageDTO(from: $0) }
        do {
            let exportEncoder = JSONEncoder()
            exportEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try exportEncoder.encode(messageDTOs)

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

    // MARK: - Deinitialization

    /// Called when this ViewModel is about to be removed from memory.
    deinit {
        print("[ChatViewModel] Deinitialized.")
    }
}
