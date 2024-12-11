//
//  SettingsView.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import SwiftUI
import AVFoundation

struct SettingsView: View {
    @Binding var appSettings: AppSettings
    @Environment(\.dismiss) var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var systemVoices: [AVSpeechSynthesisVoice] = []
    var onSettingsChange: (() -> Void)?

    private let openAIVoices = [
        ("alloy", "Alloy"), ("echo", "Echo"),
        ("fable", "Fable"), ("onyx", "Onyx"),
        ("nova", "Nova"), ("shimmer", "Shimmer")
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Color.Theme.primaryGradient(isDarkMode: isDarkMode)
                    .ignoresSafeArea()

                Form {
                    providerSection
                    modelSection
                    apiKeySection
                    systemMessageSection
                    voiceSection
                    appearanceSection
                }
                .scrollContentBackground(.hidden)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // Ensure final state is saved when user finishes editing
                        onSettingsChange?()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            systemVoices = VoiceHelper.getAvailableVoices()
            if !VoiceHelper.isValidVoiceIdentifier(appSettings.selectedSystemVoiceId) {
                appSettings.selectedSystemVoiceId = VoiceHelper.getDefaultVoiceIdentifier()
                onSettingsChange?()
            }
        }
    }

    private var providerSection: some View {
        Section {
            Picker("Provider", selection: $appSettings.selectedProvider) {
                ForEach(ChatProvider.allCases) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            // When provider changes, also reset the model to the provider's default and save changes
            .onChange(of: appSettings.selectedProvider) { _, newValue in
                appSettings.selectedModelId = newValue.defaultModel.id
                onSettingsChange?()
            }
        } header: {
            Text("Chat Provider")
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: isDarkMode))
        } footer: {
            Text(appSettings.selectedProvider == .openAI ?
                 "Uses OpenAI's GPT models" : "Uses Anthropic's Claude models")
            .foregroundStyle(Color.Theme.textSecondary(isDarkMode: isDarkMode))
        }
    }

    private var modelSection: some View {
        Section {
            NavigationLink {
                ModelPickerView(
                    provider: appSettings.selectedProvider,
                    selectedModelId: $appSettings.selectedModelId.onChange(onSettingsChange)
                )
            } label: {
                HStack {
                    Text("Model")
                    Spacer()
                    Text(appSettings.selectedModel.name)
                        .foregroundStyle(Color.secondary)
                }
            }
        } header: {
            Text("Model")
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: isDarkMode))
        }
    }

    private var apiKeySection: some View {
        Section {
            if appSettings.selectedProvider == .openAI {
                SecureField("OpenAI API Key", text: $appSettings.openAIKey.onChange(onSettingsChange))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                SecureField("Anthropic API Key", text: $appSettings.anthropicKey.onChange(onSettingsChange))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        } header: {
            Text("API Key")
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: isDarkMode))
        } footer: {
            Text(appSettings.selectedProvider == .openAI ?
                 "Enter your OpenAI API key. Get it from platform.openai.com" :
                 "Enter your Anthropic API key. Get it from console.anthropic.com")
            .foregroundStyle(Color.Theme.textSecondary(isDarkMode: isDarkMode))
        }
    }

    private var systemMessageSection: some View {
        Section {
            TextField("Enter system message...", text: $appSettings.systemMessage.onChange(onSettingsChange), axis: .vertical)
                .lineLimit(3...6)
        } header: {
            Text("System Message")
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: isDarkMode))
        } footer: {
            Text("Instructions that set the behavior of the AI assistant")
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: isDarkMode))
        }
    }

    private var voiceSection: some View {
        Section {
            Picker("Voice Provider", selection: $appSettings.selectedVoiceProvider.onChange(onSettingsChange)) {
                ForEach(VoiceProvider.allCases) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .pickerStyle(.segmented)

            if appSettings.selectedVoiceProvider == .system {
                Picker("System Voice", selection: $appSettings.selectedSystemVoiceId.onChange(onSettingsChange)) {
                    ForEach(systemVoices, id: \.identifier) { voice in
                        Text(VoiceHelper.voiceDisplayName(for: voice))
                            .tag(voice.identifier)
                    }
                }
            } else {
                Picker("OpenAI Voice", selection: $appSettings.selectedOpenAIVoice.onChange(onSettingsChange)) {
                    ForEach(openAIVoices, id: \.0) { voice in
                        Text(voice.1).tag(voice.0)
                    }
                }
            }

            Toggle("Autoplay AI Responses", isOn: $appSettings.autoplayVoice.onChange(onSettingsChange))
        } header: {
            Text("Voice Settings")
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: isDarkMode))
        } footer: {
            Text(appSettings.selectedVoiceProvider == .system ?
                 "Uses system text-to-speech voices" :
                 "Uses OpenAI's high-quality voices")
            .foregroundStyle(Color.Theme.textSecondary(isDarkMode: isDarkMode))
        }
    }

    private var appearanceSection: some View {
        Section {
            Toggle("Dark Mode", isOn: $isDarkMode)
                .onChange(of: isDarkMode) { _, _ in
                    onSettingsChange?()
                }
        } header: {
            Text("Appearance")
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: isDarkMode))
        }
    }
}

// MARK: - Binding Extension
extension Binding {
    /// A helper that calls `handler` whenever the binding’s value changes.
    func onChange(_ handler: (() -> Void)?) -> Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { newVal in
                self.wrappedValue = newVal
                handler?()
            }
        )
    }
}
