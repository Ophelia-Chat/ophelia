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
                ChatModel(id: "gpt-4o-mini", name: "GPT-4o Mini", provider: self),
                ChatModel(id: "gpt-3.5-turbo", name: "GPT-3.5 Turbo", provider: self)
            ]
        case .anthropic:
            return [
                ChatModel(id: "claude-3-5-haiku-20241022", name: "Claude 3.5 Haiku", provider: self),
                ChatModel(id: "claude-3-5-sonnet-20241022", name: "Claude 3.5 Sonnet", provider: self),
                ChatModel(id: "claude-3-opus-20240229", name: "Claude 3 Opus", provider: self)
            ]
        case .githubModel:
            return [
                ChatModel(id: "AI21-Jamba-1.5-Large", name: "AI21 Jamba 1.5 Large", provider: self),
                ChatModel(id: "AI21-Jamba-1.5-Mini", name: "AI21 Jamba 1.5 Mini", provider: self),
                ChatModel(id: "Cohere-command-r", name: "Cohere Command R", provider: self),
                ChatModel(id: "Cohere-command-r-08-2024", name: "Cohere Command R 08-2024", provider: self),
                ChatModel(id: "Cohere-command-r-plus", name: "Cohere Command R+", provider: self),
                ChatModel(id: "Cohere-command-r-plus-08-2024", name: "Cohere Command R+ 08-2024", provider: self),
                ChatModel(id: "jais-30b-chat", name: "JAIS 30b Chat", provider: self),
                ChatModel(id: "Llama-3.2-11B-Vision-Instruct", name: "Llama-3.2-11B-Vision-Instruct", provider: self),
                ChatModel(id: "Llama-3.2-90B-Vision-Instruct", name: "Llama-3.2-90B-Vision-Instruct", provider: self),
                ChatModel(id: "Llama-3.3-70B-Instruct", name: "Llama-3.3-70B-Instruct", provider: self),
                ChatModel(id: "Meta-Llama-3-70B-Instruct", name: "Meta-Llama-3-70B-Instruct", provider: self),
                ChatModel(id: "Meta-Llama-3-8B-Instruct", name: "Meta-Llama-3-8B-Instruct", provider: self),
                ChatModel(id: "Meta-Llama-3.1-405B-Instruct", name: "Meta-Llama-3.1-405B-Instruct", provider: self),
                ChatModel(id: "Meta-Llama-3.1-70B-Instruct", name: "Meta-Llama-3.1-70B-Instruct", provider: self),
                ChatModel(id: "Meta-Llama-3.1-8B-Instruct", name: "Meta-Llama-3.1-8B-Instruct", provider: self),
                ChatModel(id: "Ministral-3B", name: "Ministral 3B", provider: self),
                ChatModel(id: "Mistral-large", name: "Mistral Large", provider: self),
                ChatModel(id: "Mistral-large-2407", name: "Mistral Large (2407)", provider: self),
                ChatModel(id: "Mistral-Large-2411", name: "Mistral Large 24.11", provider: self),
                ChatModel(id: "Mistral-Nemo", name: "Mistral Nemo", provider: self),
                ChatModel(id: "Mistral-small", name: "Mistral Small", provider: self),
                ChatModel(id: "gpt-4o", name: "OpenAI GPT-4o", provider: self),
                ChatModel(id: "gpt-4o-mini", name: "OpenAI GPT-4o mini", provider: self),
                ChatModel(id: "o1-mini", name: "OpenAI o1-mini", provider: self),
                ChatModel(id: "o1-preview", name: "OpenAI o1-preview", provider: self),
                ChatModel(id: "Phi-3-medium-128k-instruct", name: "Phi-3-medium instruct (128k)", provider: self),
                ChatModel(id: "Phi-3-medium-4k-instruct", name: "Phi-3-medium instruct (4k)", provider: self),
                ChatModel(id: "Phi-3-mini-128k-instruct", name: "Phi-3-mini instruct (128k)", provider: self),
                ChatModel(id: "Phi-3-mini-4k-instruct", name: "Phi-3-mini instruct (4k)", provider: self),
                ChatModel(id: "Phi-3-small-128k-instruct", name: "Phi-3-small instruct (128k)", provider: self),
                ChatModel(id: "Phi-3-small-8k-instruct", name: "Phi-3-small instruct (8k)", provider: self),
                ChatModel(id: "Phi-3.5-mini-instruct", name: "Phi-3.5-mini instruct (128k)", provider: self),
                ChatModel(id: "Phi-3.5-MoE-instruct", name: "Phi-3.5-MoE instruct (128k)", provider: self),
                ChatModel(id: "Phi-3.5-vision-instruct", name: "Phi-3.5-vision instruct (128k)", provider: self)
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
    var githubToken: String = ""

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
