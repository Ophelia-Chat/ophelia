//
//  ChatViewModel.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import SwiftUI
import AVFoundation
import Combine

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

    // Services strongly referenced
    private var openAITTSService: OpenAITTSService?
    private var systemVoiceService: SystemVoiceService?

    private let userDefaults: UserDefaults
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()

        // Start with default settings; finalizeSetup() will load real values from "appSettingsData"
        self.appSettings = AppSettings()
        setupNotifications()
    }

    // MARK: - Public Methods

    /// Called when the view appears or after settings change. Loads settings and messages, then initializes services.
    func finalizeSetup() async {
        loadAppSettingsFromStorage()
        await loadInitialData()
        initializeChatService(with: appSettings)
        initializeVoiceService(with: appSettings)
        print("[ChatViewModel] Setup complete: Provider = \(appSettings.selectedProvider), Model = \(appSettings.selectedModelId)")
    }

    /// Sends a user message to the AI and handles the response flow.
    func sendMessage() {
        // Debug prints to trace issues with keys and provider
        print("[Debug] Provider: \(appSettings.selectedProvider), currentAPIKey: \(appSettings.currentAPIKey)")
        print("[Debug] openAIKey: \(appSettings.openAIKey), anthropicKey: \(appSettings.anthropicKey)")

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

    /// Stops any current operations (e.g., streaming responses or speech).
    func stopCurrentOperations() {
        stopCurrentSpeech()
        activeTask?.cancel()
        activeTask = nil
        isLoading = false
    }

    /// Clears all messages from the conversation and saves the empty state.
    func clearMessages() {
        stopCurrentOperations()
        messages.removeAll()
        Task {
            await saveMessages()
        }
        print("[ChatViewModel] Messages cleared.")
    }

    // MARK: - Private Methods (Initialization)

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
            print("[ChatViewModel] No valid API key, chat service not initialized.")
            return
        }

        switch settings.selectedProvider {
        case .openAI:
            chatService = OpenAIChatService(apiKey: settings.openAIKey)
            print("[ChatViewModel] Initialized OpenAI Chat Service.")
        case .anthropic:
            chatService = AnthropicService(apiKey: settings.anthropicKey)
            print("[ChatViewModel] Initialized Anthropic Chat Service.")
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

    // MARK: - Private Methods (Loading and Saving Settings)

    /// Loads `appSettings` from "appSettingsData" in `UserDefaults`, which is written by `SettingsView`.
    private func loadAppSettingsFromStorage() {
        if let data = userDefaults.data(forKey: "appSettingsData"),
           let decodedSettings = try? decoder.decode(AppSettings.self, from: data) {
            self.appSettings = decodedSettings
            print("[ChatViewModel] Loaded app settings from storage.")
        } else {
            print("[ChatViewModel] Using default app settings.")
        }
    }

    // MARK: - Private Methods (Messages)

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
        guard let encoded = try? encoder.encode(messages.map { MessageDTO(from: $0) }) else { return }
        userDefaults.set(encoded, forKey: "savedMessages")
        print("[ChatViewModel] Messages saved.")
    }

    // MARK: - Private Methods (Message Sending Flow)

    private func performSendFlow() async {
        print("[ChatViewModel] Sending message to API...")

        let aiMessage = MutableMessage(text: "", isUser: false)
        messages.append(aiMessage)

        do {
            guard let service = chatService else {
                throw ChatServiceError.invalidAPIKey
            }

            let payload = prepareMessagesPayload()
            let stream = try await service.streamCompletion(messages: payload, model: appSettings.selectedModelId)
            let completeResponse = try await handleResponseStream(stream, aiMessage: aiMessage)

            print("[ChatViewModel] Received response: \(completeResponse)")
            speakMessage(completeResponse)
            await saveMessages()
        } catch {
            print("[ChatViewModel] Error fetching response: \(error)")
            handleError(error)
            removeLastAIMessage()
        }

        isLoading = false
    }

    private func prepareMessagesPayload() -> [[String: String]] {
        var messagesPayload = messages.dropLast().map { msg in
            ["role": msg.isUser ? "user" : "assistant", "content": msg.text]
        }

        if !appSettings.systemMessage.isEmpty {
            messagesPayload.insert(["role": "system", "content": appSettings.systemMessage], at: 0)
        }

        return Array(messagesPayload)
    }

    private func handleResponseStream(
        _ stream: AsyncThrowingStream<String, Error>,
        aiMessage: MutableMessage
    ) async throws -> String {
        var completeResponse = ""
        for try await content in stream {
            if Task.isCancelled { break }
            aiMessage.text.append(content)
            completeResponse += content
            objectWillChange.send() // Update UI incrementally
        }
        return completeResponse
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

    // MARK: - Speech Methods

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
                // If OpenAI TTS fails, fallback to system voice
                if voiceService is OpenAITTSService {
                    print("[ChatViewModel] OpenAI TTS failed, falling back to system voice.")
                    let fallbackService = SystemVoiceService(voiceIdentifier: VoiceHelper.getDefaultVoiceIdentifier())
                    voiceService = fallbackService
                    try? await fallbackService.speak(text)
                }
            }
        }
    }

    deinit {
        subscriptions.forEach { $0.cancel() }
        subscriptions.removeAll()
        print("[ChatViewModel] Deinitialized.")
    }
}

// MARK: - MessageDTO for saving/loading messages
private struct MessageDTO: Codable {
    let id: UUID
    let text: String
    let isUser: Bool
    let timestamp: Date

    init(from message: MutableMessage) {
        self.id = message.id
        self.text = message.text
        self.isUser = message.isUser
        self.timestamp = message.timestamp
    }

    func toMessage() -> MutableMessage {
        MutableMessage(id: id, text: text, isUser: isUser, timestamp: timestamp)
    }
}
