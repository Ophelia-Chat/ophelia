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

    // Strong references to voice services
    private var openAITTSService: OpenAITTSService?
    private var systemVoiceService: SystemVoiceService?

    private let userDefaults: UserDefaults
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()

        // Load settings synchronously as they're needed immediately
        if let savedSettings = userDefaults.data(forKey: "appSettings"),
           let decodedSettings = try? decoder.decode(AppSettings.self, from: savedSettings) {
            self.appSettings = decodedSettings
        } else {
            self.appSettings = AppSettings()
        }

        // Initialize services
        initializeChatService(with: appSettings)
        initializeVoiceService(with: appSettings)
        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.stopCurrentOperations()
            }
            .store(in: &subscriptions)
    }

    deinit {
        subscriptions.forEach { $0.cancel() }
        subscriptions.removeAll()
    }

    private func initializeChatService(with settings: AppSettings) {
        guard !settings.currentAPIKey.isEmpty else {
            chatService = nil
            return
        }

        switch settings.selectedProvider {
        case .openAI:
            chatService = OpenAIChatService(apiKey: settings.openAIKey)
        case .anthropic:
            chatService = AnthropicService(apiKey: settings.anthropicKey)
        }
    }

    private func initializeVoiceService(with settings: AppSettings) {
        stopCurrentSpeech()

        switch settings.selectedVoiceProvider {
        case .system:
            let systemService = SystemVoiceService(voiceIdentifier: settings.selectedSystemVoiceId)
            self.systemVoiceService = systemService
            self.voiceService = systemService
            print("Initialized system voice with ID: \(settings.selectedSystemVoiceId)")

        case .openAI:
            guard !settings.openAIKey.isEmpty else {
                voiceService = nil
                openAITTSService = nil
                print("No OpenAI API key provided")
                return
            }
            let openAIService = OpenAITTSService(apiKey: settings.openAIKey, voiceId: settings.selectedOpenAIVoice)
            self.openAITTSService = openAIService
            self.voiceService = openAIService
            print("Initialized OpenAI voice with ID: \(settings.selectedOpenAIVoice)")
        }
    }

    func loadInitialData() async {
        if let savedMessages = userDefaults.data(forKey: "savedMessages"),
           let decodedMessages = try? decoder.decode([MessageDTO].self, from: savedMessages) {
            self.messages = decodedMessages.map { $0.toMessage() }
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
                print("Updated system voice to: \(settings.selectedSystemVoiceId)")

            case .openAI:
                if let service = openAITTSService {
                    service.updateVoice(settings.selectedOpenAIVoice)
                    print("Updated OpenAI voice to: \(settings.selectedOpenAIVoice)")
                } else {
                    initializeVoiceService(with: settings)
                }
            }
        } else {
            initializeVoiceService(with: settings)
        }
    }

    func updateAppSettings(_ newSettings: AppSettings) {
        stopCurrentOperations()

        let oldProvider = appSettings.selectedProvider
        let oldVoiceProvider = appSettings.selectedVoiceProvider
        let oldSystemVoiceId = appSettings.selectedSystemVoiceId
        let oldOpenAIVoice = appSettings.selectedOpenAIVoice
        let oldOpenAIKey = appSettings.openAIKey

        appSettings = newSettings

        if oldProvider != newSettings.selectedProvider ||
            appSettings.currentAPIKey != newSettings.currentAPIKey {
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
    }

    func stopCurrentOperations() {
        stopCurrentSpeech()
        activeTask?.cancel()
        activeTask = nil
        isLoading = false
    }

    private func stopCurrentSpeech() {
        speechTask?.cancel()
        speechTask = nil
        voiceService?.stop()
    }

    private func speakMessage(_ text: String) {
        guard appSettings.autoplayVoice, !text.isEmpty else { return }

        speechTask?.cancel()
        speechTask = nil

        speechTask = Task {
            do {
                print("Starting speech for message")
                try await voiceService?.speak(text)
                print("Speech completed successfully")
            } catch {
                print("Error speaking text: \(error.localizedDescription)")
                if error is CancellationError {
                    print("Speech was cancelled")
                }
            }
        }
    }

    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !appSettings.currentAPIKey.isEmpty else {
            errorMessage = "Please enter a valid API key in settings"
            showError = true
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
            await sendMessageToAPI()
        }
    }

    private func sendMessageToAPI() async {
        let aiMessage = MutableMessage(text: "", isUser: false)
        messages.append(aiMessage)

        do {
            guard let service = chatService else {
                throw ChatServiceError.invalidAPIKey
            }

            var messagesPayload = messages.dropLast().map { msg in
                ["role": msg.isUser ? "user" : "assistant", "content": msg.text]
            }

            if !appSettings.systemMessage.isEmpty {
                messagesPayload.insert(["role": "system", "content": appSettings.systemMessage], at: 0)
            }

            var completeResponse = ""

            let stream = try await service.streamCompletion(
                messages: Array(messagesPayload),
                model: appSettings.selectedModelId
            )

            for try await content in stream {
                if Task.isCancelled { break }
                aiMessage.text.append(content)
                completeResponse += content
            }

            await MainActor.run {
                objectWillChange.send()
            }

            if !Task.isCancelled {
                speakMessage(completeResponse)
            }

            Task {
                await saveMessages()
            }

        } catch let error as ChatServiceError {
            if !Task.isCancelled {
                messages.removeLast()
                errorMessage = error.errorDescription
                showError = true
            }
        } catch is CancellationError {
            messages.removeLast()
        } catch {
            if !Task.isCancelled {
                messages.removeLast()
                errorMessage = "An unexpected error occurred"
                showError = true
            }
        }

        isLoading = false
    }

    func clearMessages() {
        stopCurrentOperations()
        messages.removeAll()
        Task {
            await saveMessages()
        }
    }

    private func saveMessages() async {
        guard let encoded = try? encoder.encode(messages.map { MessageDTO(from: $0) }) else { return }
        userDefaults.set(encoded, forKey: "savedMessages")
    }

    private func saveSettings() async {
        guard let encoded = try? encoder.encode(appSettings) else { return }
        userDefaults.set(encoded, forKey: "appSettings")
    }
}

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
