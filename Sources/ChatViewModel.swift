//
//  ChatViewModel.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//  Updated to include efficient token streaming with batching and optional throttling.
//  *** Modified to truncate older messages in `prepareMessagesPayload()`. ***
//  *** Integrated with a MemoryStore to handle "remember" commands and relevant context,
//      ensuring both user and AI messages remain in the history. ***
//  *** Added in-context memory summarization to reduce token usage for large memory sets. ***
//

import SwiftUI
import AVFoundation
import Combine

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

@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var messages: [MutableMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published private(set) var appSettings: AppSettings
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    /// The store managing user "memories" (facts) across sessions.
    @Published var memoryStore = MemoryStore()

    // MARK: - Private Services

    private var chatService: ChatServiceProtocol?
    private var voiceService: VoiceServiceProtocol?
    private var activeTask: Task<Void, Never>?
    private var speechTask: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()

    private var openAITTSService: OpenAITTSService?
    private var systemVoiceService: SystemVoiceService?

    // MARK: - Persistence

    private let userDefaults: UserDefaults
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    // MARK: - Token Batching Configuration

    private let tokenBatchSize = 5
    private let tokenFlushInterval: TimeInterval = 0.2

    private var tokenBuffer: String = ""
    private var lastFlushDate = Date()
    private var flushTask: Task<Void, Never>? = nil

    // MARK: - Message History Truncation

    private let maxHistoryCount = 10
    private let truncatedSummaryText =
        "Previous context has been summarized to keep message size manageable."

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()

        self.appSettings = AppSettings()
        setupNotifications()
    }

    // MARK: - Lifecycle Setup

    func finalizeSetup() async {
        await loadSettings()
        await loadInitialData()
        initializeChatService(with: appSettings)
        initializeVoiceService(with: appSettings)
        print("[ChatViewModel] Setup complete: Provider = \(appSettings.selectedProvider), Model = \(appSettings.selectedModelId)")
    }

    // MARK: - Masking API Key in Logs

    private func maskAPIKey(_ key: String) -> String {
        guard key.count > 8 else { return "***" }
        return "\(key.prefix(4))...***...\(key.suffix(4))"
    }

    // MARK: - Main Entry for Sending Messages

    func sendMessage() {
        print("[Debug] Provider: \(appSettings.selectedProvider)")
        print("[Debug] Using API Key: \(maskAPIKey(appSettings.currentAPIKey))")

        // Ensure we have a non-empty user message and a valid API key
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !appSettings.currentAPIKey.isEmpty else {
            print("[ChatViewModel] No valid API key for provider \(appSettings.selectedProvider). Please enter a key in Settings.")
            handleError(ChatServiceError.invalidAPIKey)
            return
        }

        // 1) Always store the user's message in the chat, so it remains in history
        let userMessage = MutableMessage(text: inputText, isUser: true)
        messages.append(userMessage)

        // Save messages to persist them
        Task { await saveMessages() }

        // Extract the current text, then clear input
        let currentUserText = inputText
        inputText = ""

        // 2) Check if it's a memory command
        if let ackText = processMemoryCommand(currentUserText) {
            // Insert an assistant "ack" message to confirm memory action
            let ackMessage = MutableMessage(text: ackText, isUser: false)
            messages.append(ackMessage)
        }

        // 3) Even if it's a memory command, we still want an AI response
        //    so we do not return early here. We proceed with the normal AI flow.
        isLoading = true
        stopCurrentOperations()

        activeTask = Task {
            await performSendFlow()
        }
    }

    // MARK: - Memory Command Parsing

    /// If recognized as a memory command, returns a short ack string for the assistant.
    /// Otherwise returns `nil`.
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

        // If no memory command is recognized
        return nil
    }

    // MARK: - Managing Tasks

    func stopCurrentOperations() {
        stopCurrentSpeech()
        activeTask?.cancel()
        activeTask = nil
        isLoading = false
    }

    // MARK: - Clearing Messages

    func clearMessages() {
        stopCurrentOperations()
        messages.removeAll()
        Task {
            await saveMessages()
        }
        print("[ChatViewModel] Messages cleared.")
    }

    // MARK: - Settings

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

        // Re-initialize the chat service if the provider or key changed
        if oldProvider != newSettings.selectedProvider ||
            appSettings.currentAPIKey != newSettings.currentAPIKey {
            initializeChatService(with: newSettings)
        }

        // Re-initialize or update the voice service if TTS settings changed
        if oldVoiceProvider != newSettings.selectedVoiceProvider ||
            oldSystemVoiceId != newSettings.selectedSystemVoiceId ||
            oldOpenAIVoice != newSettings.selectedOpenAIVoice ||
            oldOpenAIKey != newSettings.openAIKey {
            updateVoiceService(with: newSettings, oldVoiceProvider: oldVoiceProvider)
        }

        Task {
            await saveSettings()
        }
        print("[ChatViewModel] App settings updated and saved.")
    }

    // MARK: - App Lifecycle Notifications

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.stopCurrentOperations()
            }
            .store(in: &subscriptions)
    }

    // MARK: - Chat Service Initialization

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
            let openAIService = OpenAITTSService(apiKey: settings.openAIKey, voiceId: settings.selectedOpenAIVoice)
            self.openAITTSService = openAIService
            self.voiceService = openAIService
            print("[ChatViewModel] Initialized OpenAI voice with ID: \(settings.selectedOpenAIVoice)")
        }
    }

    private func updateVoiceService(with settings: AppSettings, oldVoiceProvider: VoiceProvider) {
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

    private func loadSettings() async {
        if let savedSettings = userDefaults.data(forKey: "appSettingsData"),
           let decodedSettings = try? decoder.decode(AppSettings.self, from: savedSettings) {
            self.appSettings = decodedSettings
            print("[ChatViewModel] Loaded saved app settings.")
        } else {
            print("[ChatViewModel] Using default app settings.")
        }
    }

    func loadInitialData() async {
        if let savedMessages = userDefaults.data(forKey: "savedMessages"),
           let decodedMessages = try? decoder.decode([MessageDTO].self, from: savedMessages) {
            self.messages = decodedMessages.map { $0.toMessage() }
            print("[ChatViewModel] Loaded saved messages.")
        } else {
            print("[ChatViewModel] No saved messages found.")
        }
    }

    private func saveMessages() async {
        guard let encoded: Data = try? encoder.encode(messages.map { MessageDTO(from: $0) }) else { return }
        userDefaults.set(encoded, forKey: "savedMessages")
        print("[ChatViewModel] Messages saved.")
    }

    private func saveSettings() async {
        guard let encoded: Data = try? encoder.encode(appSettings) else { return }
        userDefaults.set(encoded, forKey: "appSettingsData")
        print("[ChatViewModel] App settings saved.")
    }

    // MARK: - Main Send Flow (Chat Completion)

    private func performSendFlow() async {
        print("[ChatViewModel] Sending message to API...")

        // Create a placeholder AI message to append tokens to
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

            // Build the chat payload (and optionally truncate older messages)
            var payload = prepareMessagesPayload()

            // Insert the system message for OpenAI or GitHub
            if (appSettings.selectedProvider == .openAI || appSettings.selectedProvider == .githubModel),
               !appSettings.systemMessage.isEmpty {
                payload.insert(["role": "system", "content": appSettings.systemMessage], at: 0)
            }

            // Anthropic uses `system` separately if desired
            let systemMessage: String?
            if appSettings.selectedProvider == .anthropic {
                systemMessage = appSettings.systemMessage.isEmpty ? nil : appSettings.systemMessage
            } else {
                systemMessage = nil
            }

            // Obtain a streaming response from the chat service
            let stream = try await service.streamCompletion(
                messages: payload,
                model: appSettings.selectedModelId,
                system: systemMessage
            )

            // Process tokens as they arrive
            let completeResponse = try await handleResponseStream(stream, aiMessage: aiMessage)
            print("[ChatViewModel] Received response: \(completeResponse)")

            // If the AI response is empty, remove the placeholder
            if completeResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let last = messages.last, !last.isUser {
                    messages.removeLast()
                }
            } else {
                speakMessage(completeResponse)
                await saveMessages()
            }
        } catch {
            print("[ChatViewModel] Error fetching response: \(error)")
            handleError(error)
            removeLastAIMessage()
        }

        isLoading = false
    }

    // MARK: - Incorporate Relevant Memories in Prepare Payload

    private func prepareMessagesPayload() -> [[String: String]] {
        var messagesPayload: [[String: String]] = []

        // 1) Find the last user message to see if relevant memories apply
        if let lastUserMsg = messages.last(where: { $0.isUser })?.text {
            let relevantMemories = memoryStore.retrieveRelevant(to: lastUserMsg)

            // If there are relevant memories, either bullet-list them or summarize them
            if !relevantMemories.isEmpty {
                if relevantMemories.count > 5 {
                    // Summarize if we have many relevant memories
                    let shortSummary = summarizeMemories(relevantMemories)
                    messagesPayload.append([
                        "role": "system",
                        "content": shortSummary
                    ])
                } else {
                    // Fewer memories -> bullet-style listing
                    let memoryFacts = relevantMemories.map { "- \($0.content)" }.joined(separator: "\n")
                    messagesPayload.append([
                        "role": "system",
                        "content": "Relevant facts:\n\(memoryFacts)"
                    ])
                }
            }
        }

        // 2) Build the truncated conversation from prior messages
        //    (exclude the newly appended AI placeholder)
        var truncatedMessages = Array(messages.dropLast())

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

        // Convert these truncated messages to the required payload format
        for message in truncatedMessages {
            let cleanedText = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanedText.isEmpty {
                messagesPayload.append([
                    "role": message.isUser ? "user" : "assistant",
                    "content": cleanedText
                ])
            }
        }

        return messagesPayload
    }

    /// Summarizes a large list of relevant memories into one short paragraph
    /// to reduce token usage and keep the prompt concise.
    private func summarizeMemories(_ memories: [Memory]) -> String {
        // A naive example: just mash them into a single paragraph.
        // In a production app, you might do something more sophisticated or call
        // an LLM-based summarization endpoint.
        let allContent = memories.map { $0.content }.joined(separator: ". ")
        return "Summary of user's known information: \(allContent)."
    }

    // MARK: - Stream Handling

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

        // Ensure any remaining tokens are flushed at the end
        await flushTokens(aiMessage: aiMessage, force: true)
        finalFeedbackGenerator.notificationOccurred(.success)
        return completeResponse
    }

    private func scheduleFlush(aiMessage: MutableMessage) {
        flushTask?.cancel()
        flushTask = Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.tokenFlushInterval * 1_000_000_000))
            await self.flushTokens(aiMessage: aiMessage)
        }
    }

    private func flushTokens(aiMessage: MutableMessage, force: Bool = false) async {
        guard force || !tokenBuffer.isEmpty else { return }

        let tokensToApply = tokenBuffer
        tokenBuffer = ""

        aiMessage.text.append(tokensToApply)
        objectWillChange.send()
        lastFlushDate = Date()
    }

    // MARK: - Error Handling

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

    private func removeLastAIMessage() {
        if let last = messages.last, !last.isUser {
            messages.removeLast()
        }
    }

    // MARK: - Speech Handling

    private func stopCurrentSpeech() {
        speechTask?.cancel()
        speechTask = nil
        voiceService?.stop()
    }

    private func speakMessage(_ text: String) {
        guard appSettings.autoplayVoice, !text.isEmpty else { return }

        speechTask?.cancel()
        speechTask = Task {
            do {
                try await voiceService?.speak(text)
                print("[ChatViewModel] Speech completed successfully.")
            } catch {
                print("[ChatViewModel] Speech error: \(error)")
                // Optionally add fallback logic if TTS fails.
            }
        }
    }

    private func updateLastAssistantMessage(with content: String) {
        if let lastMessage = messages.last, !lastMessage.isUser {
            lastMessage.text.append(content)
            objectWillChange.send()
        }
    }

    // MARK: - Exporting Conversation

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
