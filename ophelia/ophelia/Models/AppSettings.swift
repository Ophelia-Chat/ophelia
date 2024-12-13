//
//  AppSettings.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import Foundation
import AVFoundation

/// Represents a chat model from a given provider.
struct ChatModel: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let provider: ChatProvider
}

/// Indicates which AI provider to use: OpenAI or Anthropic.
enum ChatProvider: String, Codable, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"

    var id: String { rawValue }

    /// Available models for this provider.
    var availableModels: [ChatModel] {
        switch self {
        case .openAI:
            return [
                ChatModel(id: "gpt-3.5-turbo", name: "GPT-3.5 Turbo", provider: self),
                ChatModel(id: "gpt-4", name: "GPT-4", provider: self)
            ]
        case .anthropic:
            return [
                ChatModel(id: "claude-3-opus-20240229", name: "Claude 3 Opus", provider: self),
                ChatModel(id: "claude-3-sonnet-20240229", name: "Claude 3 Sonnet", provider: self),
                ChatModel(id: "claude-3-haiku-20240229", name: "Claude 3 Haiku", provider: self)
            ]
        }
    }

    /// Default model if none is selected.
    var defaultModel: ChatModel {
        availableModels[0]
    }
}

/// Holds user-configurable settings for the application, including API keys, models, and voice settings.
struct AppSettings: Codable, Equatable {
    // API Settings
    var openAIKey: String = ""
    var anthropicKey: String = ""
    var selectedProvider: ChatProvider = .openAI
    var selectedModelId: String
    var systemMessage: String = ""

    // Voice Settings
    var selectedVoiceProvider: VoiceProvider = .system
    var selectedSystemVoiceId: String
    var selectedOpenAIVoice: String = "alloy"
    var autoplayVoice: Bool = false

    /// Current API key based on selected provider.
    var currentAPIKey: String {
        switch selectedProvider {
        case .openAI:
            return openAIKey
        case .anthropic:
            return anthropicKey
        }
    }

    /// The currently selected model object.
    var selectedModel: ChatModel {
        selectedProvider.availableModels.first { $0.id == selectedModelId } ?? selectedProvider.defaultModel
    }
    
    var isDarkMode: Bool = false

    /// Initializes the settings with default model and system voice.
    init() {
        self.selectedModelId = ChatProvider.openAI.defaultModel.id
        self.selectedSystemVoiceId = VoiceHelper.getDefaultVoiceIdentifier()
    }
}
