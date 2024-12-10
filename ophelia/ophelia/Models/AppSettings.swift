//
//  AppSettings.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import Foundation
import AVFoundation

// MARK: - Chat Model
struct ChatModel: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let provider: ChatProvider
    
    static func == (lhs: ChatModel, rhs: ChatModel) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Chat Provider
enum ChatProvider: String, Codable, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    
    var id: String { rawValue }
    
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
    
    var defaultModel: ChatModel {
        availableModels[0]
    }
}

// MARK: - App Settings
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
    
    // Computed Properties
    var currentAPIKey: String {
        switch selectedProvider {
        case .openAI:
            return openAIKey
        case .anthropic:
            return anthropicKey
        }
    }
    
    var selectedModel: ChatModel {
        selectedProvider.availableModels.first { $0.id == selectedModelId } ?? selectedProvider.defaultModel
    }
    
    // Initialize with default values
    init() {
        self.selectedModelId = ChatProvider.openAI.defaultModel.id
        self.selectedSystemVoiceId = VoiceHelper.getDefaultVoiceIdentifier()
    }
}
