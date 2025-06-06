//
//  AppSettings.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//
//  Description:
//  This file defines the `AppSettings` class, which holds user preferences and configurations,
//  including dynamic model storage. It also defines supporting enums and structs like
//  `ThemeMode`, `ChatProvider`, and `ChatModel`.
//
//  Notable Changes for Dynamic Model Fetching:
//  - A new property `modelsForProvider` is introduced to store fetched models for each provider.
//  - This property is included in the `Codable` conformance, so any dynamically fetched models
//    can be persisted in user defaults (or other storage).
//

import Foundation
import AVFoundation
import SwiftUI
import Security

// MARK: - ThemeMode

/// Represents the user's preference for the app's appearance.
///
/// - system: Follows the device's Light/Dark setting
/// - light:  Forces Light Mode
/// - dark:   Forces Dark Mode
enum ThemeMode: String, Codable, CaseIterable {
    case system
    case light
    case dark
}

// MARK: - ChatProvider

/// An enum indicating which AI provider we're using.
/// Each case can supply a fallback list of `ChatModel` objects
/// in `availableModels`, though we can also store fetched models
/// in `AppSettings.modelsForProvider`.
enum ChatProvider: String, Codable, CaseIterable, Identifiable {
    case openAI      = "OpenAI"
    case anthropic   = "Anthropic"
    case githubModel = "GitHub Model"
    case ollama      = "Ollama"

    var id: String { rawValue }

    /// A fallback array of ChatModels, if dynamic fetching is unavailable or fails.
    var availableModels: [ChatModel] {
        switch self {
        case .openAI:
            return [
                ChatModel(id: "gpt-4o-mini",    name: "GPT-4o Mini",    provider: self),
                ChatModel(id: "gpt-3.5-turbo", name: "GPT-3.5 Turbo",  provider: self)
            ]

        case .anthropic:
            return [
                ChatModel(id: "claude-3-5-haiku-20241022",  name: "Claude 3.5 Haiku",  provider: self),
                ChatModel(id: "claude-3-5-sonnet-20241022", name: "Claude 3.5 Sonnet", provider: self),
                ChatModel(id: "claude-3-opus-20240229",     name: "Claude 3 Opus",    provider: self)
            ]

        case .githubModel:
            return [
                ChatModel(id: "AI21-Jamba-1.5-Large",         name: "AI21 Jamba 1.5 Large",       provider: self),
                ChatModel(id: "AI21-Jamba-1.5-Mini",          name: "AI21 Jamba 1.5 Mini",        provider: self),
                ChatModel(id: "Codestral-2501",               name: "Codestral 25.01",            provider: self),
                ChatModel(id: "Cohere-command-r",             name: "Cohere Command R",           provider: self),
                ChatModel(id: "Cohere-command-r-08-2024",     name: "Cohere Command R 08-2024",   provider: self),
                ChatModel(id: "Cohere-command-r-plus",        name: "Cohere Command R+",          provider: self),
                ChatModel(id: "Cohere-command-r-plus-08-2024",name: "Cohere Command R+ 08-2024",  provider: self),
                ChatModel(id: "jais-30b-chat",                name: "JAIS 30b Chat",              provider: self),
                ChatModel(id: "Llama-3.2-11B-Vision-Instruct",name: "Llama-3.2-11B-Vision-Instruct",  provider: self),
                ChatModel(id: "Llama-3.2-90B-Vision-Instruct",name: "Llama-3.2-90B-Vision-Instruct",  provider: self),
                ChatModel(id: "Llama-3.3-70B-Instruct",       name: "Llama-3.3-70B-Instruct",     provider: self),
                ChatModel(id: "Meta-Llama-3-70B-Instruct",    name: "Meta-Llama-3-70B-Instruct",  provider: self),
                ChatModel(id: "Meta-Llama-3-8B-Instruct",     name: "Meta-Llama-3-8B-Instruct",   provider: self),
                ChatModel(id: "Meta-Llama-3.1-405B-Instruct", name: "Meta-Llama-3.1-405B-Instruct",  provider: self),
                ChatModel(id: "Meta-Llama-3.1-70B-Instruct",  name: "Meta-Llama-3.1-70B-Instruct",  provider: self),
                ChatModel(id: "Meta-Llama-3.1-8B-Instruct",   name: "Meta-Llama-3.1-8B-Instruct",  provider: self),
                ChatModel(id: "Ministral-3B",                 name: "Ministral 3B",               provider: self),
                ChatModel(id: "Mistral-large",                name: "Mistral Large",              provider: self),
                ChatModel(id: "Mistral-large-2407",           name: "Mistral Large (2407)",       provider: self),
                ChatModel(id: "Mistral-Large-2411",           name: "Mistral Large 24.11",        provider: self),
                ChatModel(id: "Mistral-Nemo",                 name: "Mistral Nemo",               provider: self),
                ChatModel(id: "Mistral-small",                name: "Mistral Small",              provider: self),
                ChatModel(id: "gpt-4o",                       name: "OpenAI GPT-4o",              provider: self),
                ChatModel(id: "gpt-4o-mini",                  name: "OpenAI GPT-4o mini",         provider: self),
                ChatModel(id: "o1",                           name: "OpenAI o1",                  provider: self),
                ChatModel(id: "o1-mini",                      name: "OpenAI o1-mini",             provider: self),
                ChatModel(id: "o1-preview",                   name: "OpenAI o1-preview",          provider: self),
                ChatModel(id: "Phi-3-medium-128k-instruct",   name: "Phi-3-medium instruct (128k)",   provider: self),
                ChatModel(id: "Phi-3-medium-4k-instruct",     name: "Phi-3-medium instruct (4k)",     provider: self),
                ChatModel(id: "Phi-3-mini-128k-instruct",     name: "Phi-3-mini instruct (128k)",     provider: self),
                ChatModel(id: "Phi-3-mini-4k-instruct",       name: "Phi-3-mini instruct (4k)",       provider: self),
                ChatModel(id: "Phi-3-small-128k-instruct",    name: "Phi-3-small instruct (128k)",    provider: self),
                ChatModel(id: "Phi-3-small-8k-instruct",      name: "Phi-3-small instruct (8k)",      provider: self),
                ChatModel(id: "Phi-3.5-mini-instruct",        name: "Phi-3.5-mini instruct (128k)",   provider: self),
                ChatModel(id: "Phi-3.5-MoE-instruct",         name: "Phi-3.5-MoE instruct (128k)",    provider: self),
                ChatModel(id: "Phi-3.5-vision-instruct",      name: "Phi-3.5-vision instruct (128k)",  provider: self)
            ]
        case .ollama:
            /**
             We return an empty list by default. We will fetch the real local
             models from the /api/tags endpoint using the ModelListService
             at runtime. We'll store them in `modelsForProvider[.ollama]`.
             The user can refresh or see them in the UI.
             */
            return []
        }
    }

    /// Returns the first model in the list as a fallback default.
    var defaultModel: ChatModel {
        switch self {
        case .openAI: return availableModels[0]
        case .anthropic: return availableModels[0]
        case .githubModel: return availableModels[0]
        case .ollama:
            return ChatModel(id: "llama3.2", name: "llama3.2", provider: self)
        }
    }
}

// MARK: - ChatModel

/// A small struct representing a single AI model (e.g. "GPT-3.5 Turbo"),
/// along with its associated provider (OpenAI, Anthropic, etc.).
struct ChatModel: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let provider: ChatProvider
}

// MARK: - AppSettings

/// The main app settings class. Stores user-configurable properties such as:
/// - API keys and tokens
/// - Which provider/model is selected
/// - TTS (voice) settings
/// - UI theme mode
///
/// Also includes a `modelsForProvider` dictionary for storing
/// dynamically fetched model lists.
final class AppSettings: ObservableObject, Codable, Equatable {

    // MARK: - Published Properties

    @Published var openAIKey: String = "" {
        didSet { 
            if oldValue != openAIKey {
                KeychainService.save(openAIKey, forKey: "openAIKey") 
            }
        }
    }
    @Published var anthropicKey: String = "" {
        didSet { 
            if oldValue != anthropicKey {
                KeychainService.save(anthropicKey, forKey: "anthropicKey") 
            }
        }
    }
    @Published var githubToken: String = "" {
        didSet { 
            if oldValue != githubToken {
                KeychainService.save(githubToken, forKey: "githubToken") 
            }
        }
    }
    @Published var ollamaServerURL: String = "http://localhost:11434"

    @Published var selectedProvider: ChatProvider = .openAI
    @Published var selectedModelId: String
    @Published var systemMessage: String = ""

    @Published var selectedVoiceProvider: VoiceProvider = .system
    @Published var selectedSystemVoiceId: String
    @Published var selectedOpenAIVoice: String = "alloy"
    @Published var autoplayVoice: Bool = false

    /// The user's chosen theme mode—system, light, or dark.
    @Published var themeMode: ThemeMode = .system

    /// A dictionary of dynamically fetched models, keyed by provider.
    /// If you fetch an updated list of models from a remote API, store it here.
    @Published var modelsForProvider: [ChatProvider: [ChatModel]] = [:]

    // MARK: - Computed Properties

    /// Returns the appropriate API key based on the selected provider.
    var currentAPIKey: String {
        switch selectedProvider {
        case .openAI:
            return openAIKey
        case .anthropic:
            return anthropicKey
        case .githubModel:
            return githubToken
        case .ollama:
            return ""  // Team no keys!
        }
    }

    /// Tries to find the chosen model in the dynamically fetched list first,
    /// then falls back to the provider's hardcoded `availableModels` if not found.
    var selectedModel: ChatModel {
        // 1) If we have a dynamic list, see if the selectedModelId is there.
        if let dynamicList = modelsForProvider[selectedProvider],
           let dynamicHit = dynamicList.first(where: { $0.id == selectedModelId }) {
            return dynamicHit
        }

        // 2) If dynamic list doesn't exist or doesn't have that model, check the fallback list.
        return selectedProvider.availableModels.first { $0.id == selectedModelId }
            ?? selectedProvider.defaultModel
    }

    /// A helper for SwiftUI usage if you want `.preferredColorScheme(...)`.
    var colorScheme: ColorScheme? {
        switch themeMode {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    // MARK: - Initializer

    /// Initializes the AppSettings with sensible defaults.
    init() {
        // Start with the default model from the .openAI provider.
        self.selectedModelId = ChatProvider.openAI.defaultModel.id

        // Use a helper to get a fallback system voice ID, if available.
        self.selectedSystemVoiceId = VoiceHelper.getDefaultVoiceIdentifier()
        
        // Load API keys from keychain
        self.openAIKey = KeychainService.read(forKey: "openAIKey") ?? ""
        self.anthropicKey = KeychainService.read(forKey: "anthropicKey") ?? ""
        self.githubToken = KeychainService.read(forKey: "githubToken") ?? ""
    }

    // MARK: - Codable Conformance

    private enum CodingKeys: String, CodingKey {
        case openAIKey
        case anthropicKey
        case githubToken
        case selectedProvider
        case selectedModelId
        case systemMessage
        case selectedVoiceProvider
        case selectedSystemVoiceId
        case selectedOpenAIVoice
        case autoplayVoice
        case themeMode
        case modelsForProvider
        case ollamaServerURL
    }

    /// Decodes `AppSettings` from the given decoder (for instance, loading from UserDefaults).
    convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Load API keys from keychain first, then check for legacy stored values
        var openAIFromKeychain = KeychainService.read(forKey: "openAIKey") ?? ""
        var anthropicFromKeychain = KeychainService.read(forKey: "anthropicKey") ?? ""
        var githubFromKeychain = KeychainService.read(forKey: "githubToken") ?? ""
        
        // If keychain is empty, try to migrate from legacy storage
        if openAIFromKeychain.isEmpty, let legacy = try? container.decode(String.self, forKey: .openAIKey), !legacy.isEmpty {
            openAIFromKeychain = legacy
            KeychainService.save(legacy, forKey: "openAIKey")
        }
        
        if anthropicFromKeychain.isEmpty, let legacy = try? container.decode(String.self, forKey: .anthropicKey), !legacy.isEmpty {
            anthropicFromKeychain = legacy
            KeychainService.save(legacy, forKey: "anthropicKey")
        }
        
        if githubFromKeychain.isEmpty, let legacy = try? container.decode(String.self, forKey: .githubToken), !legacy.isEmpty {
            githubFromKeychain = legacy
            KeychainService.save(legacy, forKey: "githubToken")
        }
        
        // Set the values (this will trigger the didSet observers)
        self.openAIKey = openAIFromKeychain
        self.anthropicKey = anthropicFromKeychain
        self.githubToken = githubFromKeychain

        selectedProvider    = try container.decode(ChatProvider.self, forKey: .selectedProvider)
        selectedModelId     = try container.decode(String.self, forKey: .selectedModelId)
        systemMessage       = try container.decode(String.self, forKey: .systemMessage)
        selectedVoiceProvider = try container.decode(VoiceProvider.self, forKey: .selectedVoiceProvider)
        selectedSystemVoiceId  = try container.decode(String.self, forKey: .selectedVoiceProvider)
        selectedOpenAIVoice    = try container.decode(String.self, forKey: .selectedOpenAIVoice)
        autoplayVoice          = try container.decode(Bool.self,  forKey: .autoplayVoice)

        // Attempt to decode themeMode. If it fails, fallback to .system
        themeMode = (try? container.decode(ThemeMode.self, forKey: .themeMode)) ?? .system

        // Attempt to decode the dictionary of modelsForProvider
        if let decodedModels = try? container.decode(
            [ChatProvider: [ChatModel]].self,
            forKey: .modelsForProvider
        ) {
            modelsForProvider = decodedModels
        }

        ollamaServerURL = try container.decode(String.self, forKey: .ollamaServerURL)
    }

    /// Encodes `AppSettings` to the given encoder (for instance, saving to UserDefaults).
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)


        try container.encode(selectedProvider,     forKey: .selectedProvider)
        try container.encode(selectedModelId,      forKey: .selectedModelId)
        try container.encode(systemMessage,        forKey: .systemMessage)
        try container.encode(selectedVoiceProvider,forKey: .selectedVoiceProvider)
        try container.encode(selectedSystemVoiceId, forKey: .selectedSystemVoiceId)
        try container.encode(selectedOpenAIVoice,   forKey: .selectedOpenAIVoice)
        try container.encode(autoplayVoice,         forKey: .autoplayVoice)
        try container.encode(themeMode,             forKey: .themeMode)

        // Encode any dynamically fetched models
        try container.encode(modelsForProvider, forKey: .modelsForProvider)

        try container.encode(ollamaServerURL, forKey: .ollamaServerURL)
    }

    // MARK: - Equatable

    /// Allows comparing two `AppSettings` objects for equality.
    static func == (lhs: AppSettings, rhs: AppSettings) -> Bool {
        lhs.openAIKey == rhs.openAIKey &&
        lhs.anthropicKey == rhs.anthropicKey &&
        lhs.githubToken == rhs.githubToken &&
        lhs.selectedProvider == rhs.selectedProvider &&
        lhs.selectedModelId == rhs.selectedModelId &&
        lhs.systemMessage == rhs.systemMessage &&
        lhs.selectedVoiceProvider == rhs.selectedVoiceProvider &&
        lhs.selectedSystemVoiceId == rhs.selectedSystemVoiceId &&
        lhs.selectedOpenAIVoice == rhs.selectedOpenAIVoice &&
        lhs.autoplayVoice == rhs.autoplayVoice &&
        lhs.themeMode == rhs.themeMode &&
        lhs.modelsForProvider == rhs.modelsForProvider &&
        lhs.ollamaServerURL == rhs.ollamaServerURL
    }
}

/// A lightweight helper for reading and writing strings to the Keychain.
/// Values are stored under the app's generic password class using the
/// provided key as the account name.
enum KeychainService {
    /// Saves the given string to the Keychain.
    /// If an item already exists for this key, it will be replaced.
    @discardableResult
    static func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Delete any existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Reads a string value for the given key from the Keychain.
    static func read(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        return string
    }

    /// Deletes the Keychain item for the given key, if it exists.
    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
}
