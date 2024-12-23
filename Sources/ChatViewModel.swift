//
//  ChatViewModel.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//  Updated to include efficient token streaming with batching and optional throttling.
//  *** Modified to truncate older messages in `prepareMessagesPayload()`. ***
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
        MutableMessage(id: id, text: text, isUser: isUser, timestamp: timestamp,
                       originProvider: originProvider, originModel: originModel)
    }
}

@MainActor
class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [MutableMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published private(set) var appSettings: AppSettings
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    private var chatService: ChatServiceProtocol?
    private var voiceService: VoiceServiceProtocol?
    private var activeTask: Task<Void, Never>?
    private var speechTask: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()

    private var openAITTSService: OpenAITTSService?
    private var systemVoiceService: SystemVoiceService?

    private let userDefaults: UserDefaults
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    // MARK: - Token Batching Configuration
    private let tokenBatchSize = 5
    private let tokenFlushInterval: TimeInterval = 0.2

    private var tokenBuffer: String = ""
    private var lastFlushDate = Date()
    private var flushTask: Task<Void, Never>? = nil

    // MARK: - Example Truncation Configuration
    // We'll keep up to 10 recent messages, plus the current user message.
    // If your entire conversation is short, no messages are truncated at all.
    private let maxHistoryCount = 10

    // Optional: use a short summary for older messages if you like
    private let truncatedSummaryText =
        "Previous context has been summarized to keep message size manageable."

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()

        self.appSettings = AppSettings()
        setupNotifications()
    }

    func finalizeSetup() async {
        await loadSettings()
        await loadInitialData()
        initializeChatService(with: appSettings)
        initializeVoiceService(with: appSettings)
        print("[ChatViewModel] Setup complete: Provider = \(appSettings.selectedProvider), Model = \(appSettings.selectedModelId)")
    }

    private func maskAPIKey(_ key: String) -> String {
        guard key.count > 8 else { return "***" }
        return "\(key.prefix(4))...***...\(key.suffix(4))"
    }

    func sendMessage() {
        print("[Debug] Provider: \(appSettings.selectedProvider)")
        print("[Debug] Using API Key: \(maskAPIKey(appSettings.currentAPIKey))")

        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !appSettings.currentAPIKey.isEmpty else {
            print("[ChatViewModel] No valid API key for provider \(appSettings.selectedProvider). Please enter a key in Settings.")
            handleError(ChatServiceError.invalidAPIKey)
            return
        }

        let userMessage = MutableMessage(text: inputText, isUser: true)
        messages.append(userMessage)

        Task {
            await saveMessages()
        }

        inputText = ""
        isLoading = true

        stopCurrentOperations()

        activeTask = Task {
            await performSendFlow()
        }
    }

    func stopCurrentOperations() {
        stopCurrentSpeech()
        activeTask?.cancel()
        activeTask = nil
        isLoading = false
    }

    func clearMessages() {
        stopCurrentOperations()
        messages.removeAll()
        Task {
            await saveMessages()
        }
        print("[ChatViewModel] Messages cleared.")
    }

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

        if oldProvider != newSettings.selectedProvider || appSettings.currentAPIKey != newSettings.currentAPIKey {
            initializeChatService(with: newSettings)
        }

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

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.stopCurrentOperations()
            }
            .store(in: &subscriptions)
    }

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
        case .githubModel :
            chatService = GitHubModelChatService(apiKey: settings.githubToken)
            print("[ChatViewModel] Initialized GitHub Model Chat Service with key: \(maskAPIKey(settings.githubToken))")
        }
    }

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

    private func performSendFlow() async {
        print("[ChatViewModel] Sending message to API...")

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

            // Collect messages & possibly truncate older ones
            var payload = prepareMessagesPayload()

            // Insert the system message if the provider is OpenAI **or** GitHub
            if (appSettings.selectedProvider == .openAI || appSettings.selectedProvider == .githubModel),
               !appSettings.systemMessage.isEmpty
            {
                payload.insert(["role": "system", "content": appSettings.systemMessage], at: 0)
            }

            let systemMessage: String?
            if appSettings.selectedProvider == .anthropic {
                systemMessage = appSettings.systemMessage.isEmpty ? nil : appSettings.systemMessage
            } else {
                systemMessage = nil
            }

            let stream = try await service.streamCompletion(
                messages: payload,
                model: appSettings.selectedModelId,
                system: systemMessage
            )

            let completeResponse = try await handleResponseStream(stream, aiMessage: aiMessage)
            print("[ChatViewModel] Received response: \(completeResponse)")

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

    // MARK: - Truncate or Summarize older messages here.
    private func prepareMessagesPayload() -> [[String: String]] {
        // We want to form a payload that excludes older messages beyond our maxHistoryCount.

        // messages.dropLast() excludes the *currently typed* message from user (which we handle separately),
        // but we also appended the AI message to messages, so let's consider all but the last AI message too.
        // If you prefer a different approach, adjust as needed.
        var truncatedMessages = Array(messages.dropLast())

        // If we've accumulated a lot of messages, let's cut the older ones.
        if truncatedMessages.count > maxHistoryCount {
            // Option A: Just remove them outright
            let olderCount = truncatedMessages.count - maxHistoryCount
            truncatedMessages.removeFirst(olderCount)

            // Optionally, we could insert a short "summary" system message if you want to preserve context:
            // (In practice, you'd have an actual summarization step. For now, just a placeholder.)
            let summaryMessage = [
                "role": "assistant",
                "content": truncatedSummaryText
            ]
            // Insert at the front if you want it to appear before the truncated set
            truncatedMessages.insert(.init(
                id: UUID(),
                text: truncatedSummaryText,
                isUser: false
            ), at: 0)
        }

        var messagesPayload: [[String: String]] = []
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

            if tokenCount % tokenBatchSize == 0 {
                await flushTokens(aiMessage: aiMessage)
            } else {
                scheduleFlush(aiMessage: aiMessage)
            }

            if tokenCount % 5 == 0 {
                feedbackGenerator.impactOccurred()
            }
        }

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

    private func handleError(_ error: Error) {
        if let chatError = error as? ChatServiceError {
            switch chatError {
            case .invalidAPIKey:
                errorMessage = "No valid API key found for \(appSettings.selectedProvider.rawValue). Please open Settings and enter a valid API key."
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
                // Remove or comment out the fallback code if you don’t want to revert to system voice:
                // if voiceService is OpenAITTSService {
                //    let fallbackService = SystemVoiceService(voiceIdentifier: VoiceHelper.getDefaultVoiceIdentifier())
                //    voiceService = fallbackService
                //    try? await fallbackService.speak(text)
                // }
            }
        }
    }

    private func updateLastAssistantMessage(with content: String) {
        if let lastMessage = messages.last, !lastMessage.isUser {
            lastMessage.text.append(content)
            objectWillChange.send()
        }
    }

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

    deinit {
        print("[ChatViewModel] Deinitialized.")
    }
}
