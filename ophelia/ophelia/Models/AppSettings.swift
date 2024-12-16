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
    case githubModel = "GitHub Model"

    var id: String { rawValue }

    var availableModels: [ChatModel] {
        switch self {
        case .openAI:
            return [
                ChatModel(id: "gpt-3.5-turbo", name: "GPT-3.5 Turbo", provider: self),
                ChatModel(id: "gpt-4o-mini", name: "GPT-4o Mini", provider: self)
            ]
        case .anthropic:
            return [
                ChatModel(id: "claude-3-5-sonnet-20241022", name: "Claude 3.5 Sonnet", provider: self),
                ChatModel(id: "claude-3-5-haiku-20241022", name: "Claude 3.5 Haiku", provider: self),
                ChatModel(id: "claude-3-opus-20240229", name: "Claude 3 Opus", provider: self)
            ]
        case .githubModel:
            // Adjust model name/ID to your actual model as needed.
            return [
                ChatModel(id: "Meta-Llama-3.1-405B-Instruct", name: "Meta Llama 3.1 405B Instruct", provider: self)
            ]
        }
    }

    var defaultModel: ChatModel {
        availableModels[0]
    }
}

/// Holds user-configurable settings for the application, including API keys, models, and voice settings.
struct AppSettings: Codable, Equatable {
    var openAIKey: String = ""
    var anthropicKey: String = ""
    var githubToken: String = "" // GitHub token

    var selectedProvider: ChatProvider = .openAI
    var selectedModelId: String
    var systemMessage: String = ""

    var selectedVoiceProvider: VoiceProvider = .system
    var selectedSystemVoiceId: String
    var selectedOpenAIVoice: String = "alloy"
    var autoplayVoice: Bool = false
    var isDarkMode: Bool = false

    var currentAPIKey: String {
        switch selectedProvider {
        case .openAI:
            return openAIKey
        case .anthropic:
            return anthropicKey
        case .githubModel:
            return githubToken
        }
    }

    var selectedModel: ChatModel {
        selectedProvider.availableModels.first { $0.id == selectedModelId } ?? selectedProvider.defaultModel
    }

    init() {
        self.selectedModelId = ChatProvider.openAI.defaultModel.id
        self.selectedSystemVoiceId = VoiceHelper.getDefaultVoiceIdentifier()
    }
}
