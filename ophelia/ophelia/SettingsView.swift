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
                Color.Theme.primaryGradient.ignoresSafeArea()
                
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
            .onChange(of: appSettings.selectedProvider) { _, newValue in
                appSettings.selectedModelId = newValue.defaultModel.id
                onSettingsChange?()
            }
        } header: {
            Text("Chat Provider")
                .foregroundStyle(Color.Theme.textSecondary)
        } footer: {
            Text(appSettings.selectedProvider == .openAI ?
                "Uses OpenAI's GPT models" : "Uses Anthropic's Claude models")
                .foregroundStyle(Color.Theme.textSecondary)
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
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Model")
                .foregroundStyle(Color.Theme.textSecondary)
        }
    }
    
    private var apiKeySection: some View {
        Section {
            if appSettings.selectedProvider == .openAI {
                SecureField("OpenAI API Key", text: $appSettings.openAIKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                SecureField("Anthropic API Key", text: $appSettings.anthropicKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        } header: {
            Text("API Key")
                .foregroundStyle(Color.Theme.textSecondary)
        } footer: {
            Text(appSettings.selectedProvider == .openAI ?
                "Enter your OpenAI API key. Get it from platform.openai.com" :
                "Enter your Anthropic API key. Get it from console.anthropic.com")
                .foregroundStyle(Color.Theme.textSecondary)
        }
    }
    
    private var systemMessageSection: some View {
        Section {
            TextField("Enter system message...", text: $appSettings.systemMessage, axis: .vertical)
                .lineLimit(3...6)
        } header: {
            Text("System Message")
                .foregroundStyle(Color.Theme.textSecondary)
        } footer: {
            Text("Instructions that set the behavior of the AI assistant")
                .foregroundStyle(Color.Theme.textSecondary)
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
                .foregroundStyle(Color.Theme.textSecondary)
        } footer: {
            Text(appSettings.selectedVoiceProvider == .system ?
                "Uses system text-to-speech voices" :
                "Uses OpenAI's high-quality voices")
                .foregroundStyle(Color.Theme.textSecondary)
        }
    }
    
    private var appearanceSection: some View {
        Section {
            Toggle("Dark Mode", isOn: $isDarkMode)
                .onChange(of: isDarkMode) { oldValue, newValue in
                    onSettingsChange?()
                }
        } header: {
            Text("Appearance")
                .foregroundStyle(Color.Theme.textSecondary)
        }
    }
}
