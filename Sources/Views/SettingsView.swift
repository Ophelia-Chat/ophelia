//
//  SettingsView.swift
//  ophelia
//
//  Originally created by rob on 2024-11-27.
//  Updated to preserve selected model across provider changes and settings navigation.
//

import SwiftUI
import AVFoundation

struct SettingsView: View {
    @ObservedObject var chatViewModel: ChatViewModel
    @AppStorage("appSettingsData") private var appSettingsData: Data?
    @State private var appSettings = AppSettings()
    @Environment(\.dismiss) var dismiss
    @State private var systemVoices: [AVSpeechSynthesisVoice] = []
    @State private var showClearHistoryAlert = false
    
    @State private var shareSheetItems: [Any] = []
    @State private var isShowingShareSheet = false

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
            aboutSection
            

            // MARK: - Export Discussion Section
            Section {
                Button("Export Discussion to JSON") {
                    // Attempt to create a temporary .json file of the conversation
                    if let fileURL = chatViewModel.exportConversationAsJSONFile() {
                        shareSheetItems = [fileURL]
                        isShowingShareSheet = true
                    } else {
                        print("Failed to export conversation as JSON.")
                        // Optionally, show an alert or user-facing error message here.
                    }
                }
            } header: {
                Text("Export")
                    .foregroundStyle(Color.Theme.textSecondary(isDarkMode: appSettings.isDarkMode))
            } footer: {
                Text("Export your chat history as a JSON file.")
                    .foregroundStyle(Color.Theme.textSecondary(isDarkMode: appSettings.isDarkMode))
            }
            // MARK: - Clear Conversation History
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
        .sheet(isPresented: $isShowingShareSheet) {
           ActivityViewControllerWrapper(activityItems: shareSheetItems, applicationActivities: nil)
        }
        .background(
            Color.Theme.primaryGradient(isDarkMode: appSettings.isDarkMode)
        )
        .onAppear {
            loadSettings()
            systemVoices = VoiceHelper.getAvailableVoices()
            if !VoiceHelper.isValidVoiceIdentifier(appSettings.selectedSystemVoiceId) {
                appSettings.selectedSystemVoiceId = VoiceHelper.getDefaultVoiceIdentifier()
                saveSettings()
            }
        }
        // Save settings whenever appSettings change, ensuring persistence of the selected model.
        .onChange(of: appSettings) { oldSettings, newSettings in
            saveSettings()
        }
    }

    // MARK: - Provider Section
    private var providerSection: some View {
        Section {
            Picker("Provider", selection: $appSettings.selectedProvider) {
                ForEach(ChatProvider.allCases) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            // Refined onChange logic:
            // Only reset the model if the currently selected model is not valid for the new provider.
            .onChange(of: appSettings.selectedProvider) { oldProvider, newProvider in
                let availableModels = newProvider.availableModels
                // Check if current model is still valid under the new provider
                if !availableModels.contains(where: { $0.id == appSettings.selectedModelId }) {
                    // If not valid, revert to the provider’s default model
                    appSettings.selectedModelId = newProvider.defaultModel.id
                }
            }
        } header: {
            Text("Chat Provider")
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: appSettings.isDarkMode))
        } footer: {
            Text(appSettings.selectedProvider == .openAI ?
                 "Uses OpenAI's GPT models" :
                 appSettings.selectedProvider == .anthropic ?
                 "Uses Anthropic's Claude models" :
                 "Uses GitHub/Azure-based model endpoints.")
            .foregroundStyle(Color.Theme.textSecondary(isDarkMode: appSettings.isDarkMode))
        }
    }

    // MARK: - Model Section
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

    // MARK: - API Key Section
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
                Text("Enter your GitHub token for Azure-based model access.")
            }
        }
    }

    // MARK: - System Message Section
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

    // MARK: - Voice Section
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

    // MARK: - Appearance Section
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
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - About Section
    private var aboutSection: some View {
        Section {
            NavigationLink(destination: AboutView()) {
                Text("About")
            }
        } header: {
            Text("About")
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: appSettings.isDarkMode))
        } footer: {
            Text("Learn more about Ophelia, including version and credits.")
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: appSettings.isDarkMode))
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

// MARK: - Share Sheet Wrapper
struct ActivityViewControllerWrapper: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates necessary
    }
}
