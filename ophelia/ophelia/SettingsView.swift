//
//  SettingsView.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import SwiftUI
import AVFoundation

struct SettingsView: View {
    @AppStorage("appSettingsData") private var appSettingsData: Data?
    @State private var appSettings = AppSettings()
    @Environment(\.dismiss) var dismiss
    @State private var systemVoices: [AVSpeechSynthesisVoice] = []
    @State private var showClearHistoryAlert = false

    // Closure provided by the parent view to actually clear the messages
    var clearMessages: (() -> Void)? = nil

    private let openAIVoices = [
        ("alloy", "Alloy"), ("echo", "Echo"),
        ("fable", "Fable"), ("onyx", "Onyx"),
        ("nova", "Nova"), ("shimmer", "Shimmer")
    ]

    var body: some View {
        Form {
            providerSection
            modelSection
            apiKeySection
            systemMessageSection
            voiceSection
            appearanceSection

            Section {
                Button(role: .destructive) {
                    showClearHistoryAlert = true
                } label: {
                    Text("Clear Conversation History")
                        .foregroundColor(.red)
                }
                .alert("Clear Conversation History?", isPresented: $showClearHistoryAlert) {
                    Button("Delete", role: .destructive) {
                        // Call the provided closure from parent to actually clear messages
                        clearMessages?()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This action will permanently delete all saved chat messages.")
                }
            } footer: {
                Text("Deleting the conversation history is irreversible. Make sure you want to remove all past messages.")
                    .foregroundStyle(Color.Theme.textSecondary(isDarkMode: appSettings.isDarkMode))
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    saveSettings()
                    dismiss()
                }
            }
        }
        .background(
            Color.Theme.primaryGradient(isDarkMode: appSettings.isDarkMode)
                .ignoresSafeArea()
        )
        .onAppear {
            loadSettings()
            systemVoices = VoiceHelper.getAvailableVoices()
            if !VoiceHelper.isValidVoiceIdentifier(appSettings.selectedSystemVoiceId) {
                appSettings.selectedSystemVoiceId = VoiceHelper.getDefaultVoiceIdentifier()
                saveSettings()
            }
        }
        .onChange(of: appSettings) {
            saveSettings()
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
            .onChange(of: appSettings.selectedProvider) { _, newValue in
                appSettings.selectedModelId = newValue.defaultModel.id
            }
        } header: {
            Text("Chat Provider")
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: appSettings.isDarkMode))
        } footer: {
            Text(appSettings.selectedProvider == .openAI ?
                 "Uses OpenAI's GPT models" :
                 "Uses Anthropic's Claude models")
            .foregroundStyle(Color.Theme.textSecondary(isDarkMode: appSettings.isDarkMode))
        }
    }

    private var modelSection: some View {
        Section {
            NavigationLink {
                ModelPickerView(
                    provider: appSettings.selectedProvider,
                    selectedModelId: $appSettings.selectedModelId
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
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: appSettings.isDarkMode))
        }
    }

    private var apiKeySection: some View {
        Section {
            switch appSettings.selectedProvider {
            case .openAI:
                SecureField("OpenAI API Key", text: $appSettings.openAIKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            case .anthropic:
                SecureField("Anthropic API Key", text: $appSettings.anthropicKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            case .githubModel:
                SecureField("GitHub Token", text: $appSettings.githubToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        } header: {
            Text("API Key")
        } footer: {
            switch appSettings.selectedProvider {
            case .openAI:
                Text("Enter your OpenAI API key from platform.openai.com")
            case .anthropic:
                Text("Enter your Anthropic API key from console.anthropic.com")
            case .githubModel:
                Text("Enter your GitHub token. This token gives access to Azure-based models on your dev plan.")
            }
        }
    }

    private var systemMessageSection: some View {
        Section {
            TextEditor(text: $appSettings.systemMessage)
                .frame(minHeight: 100)
                .padding(.vertical, 4)
        } header: {
            Text("System Message")
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: appSettings.isDarkMode))
        } footer: {
            Text("Provide instructions that define how the AI assistant should behave.")
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: appSettings.isDarkMode))
        }
    }

    private var voiceSection: some View {
        Section {
            Picker("Voice Provider", selection: $appSettings.selectedVoiceProvider) {
                ForEach(VoiceProvider.allCases) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .pickerStyle(.segmented)

            if appSettings.selectedVoiceProvider == .system {
                Picker("System Voice", selection: $appSettings.selectedSystemVoiceId) {
                    ForEach(systemVoices, id: \.identifier) { voice in
                        Text(VoiceHelper.voiceDisplayName(for: voice))
                            .tag(voice.identifier)
                    }
                }
            } else {
                Picker("OpenAI Voice", selection: $appSettings.selectedOpenAIVoice) {
                    ForEach(openAIVoices, id: \.0) { voice in
                        Text(voice.1).tag(voice.0)
                    }
                }
            }

            Toggle("Autoplay AI Responses", isOn: $appSettings.autoplayVoice)
        } header: {
            Text("Voice Settings")
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: appSettings.isDarkMode))
        } footer: {
            Text(appSettings.selectedVoiceProvider == .system ?
                 "Uses the device's built-in text-to-speech voices." :
                 "Uses OpenAI's neural voices for a higher-quality reading.")
            .foregroundStyle(Color.Theme.textSecondary(isDarkMode: appSettings.isDarkMode))
        }
    }

    private var appearanceSection: some View {
        Section {
            Toggle("Dark Mode", isOn: $appSettings.isDarkMode)
                .disabled(true)
                .foregroundColor(.secondary)
        } header: {
            Text("Appearance")
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: appSettings.isDarkMode))
        } footer: {
            Text("Dark Mode is currently locked.")
                .foregroundColor(.secondary) // To do
        }
    }

    // MARK: - Persistence
    private func loadSettings() {
        guard let data = appSettingsData else { return }
        if let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            appSettings = decoded
        }
    }

    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(appSettings) {
            appSettingsData = encoded
        }
    }
}
