//
//  SettingsView.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import SwiftUI
import AVFoundation

/// A SwiftUI view that displays and edits application settings,
/// including AI provider, model, API keys, system message, TTS voice,
/// and a dedicated section for viewing user memories.
struct SettingsView: View {
    // MARK: - Observed Properties

    /// The view model that manages chat messages and settings (including memory storage).
    @ObservedObject var chatViewModel: ChatViewModel
    
    /// Persisted settings data; used to initialize and store `appSettings`.
    @AppStorage("appSettingsData") private var appSettingsData: Data?

    /// A local copy of the app settings, which gets persisted and pushed
    /// back into `chatViewModel` on changes.
    @State private var appSettings = AppSettings()
    
    /// For dismissing the settings view (if presented modally).
    @Environment(\.dismiss) var dismiss

    /// Capture the system's color scheme for `.system` logic
    @Environment(\.colorScheme) private var colorScheme

    // Cached system voices, etc.
    @State private var systemVoices: [AVSpeechSynthesisVoice] = []
    @State private var showClearHistoryAlert = false
    @State private var shareSheetItems: [Any] = []
    @State private var isShowingShareSheet = false

    var clearMessages: (() -> Void)? = nil

    private let openAIVoices = [
        ("alloy", "Alloy"), ("echo", "Echo"), ("fable", "Fable"),
        ("onyx", "Onyx"),   ("nova", "Nova"), ("shimmer", "Shimmer")
    ]

    // MARK: - Computed: Determine “isDarkMode” from `themeMode` & system
    private var isDarkMode: Bool {
        switch appSettings.themeMode {
        case .dark:
            return true
        case .light:
            return false
        case .system:
            // Fallback on the device setting
            return (colorScheme == .dark)
        }
    }

    // MARK: - Body
    var body: some View {
        Form {
            providerSection
            modelSection
            apiKeySection
            systemMessageSection
            voiceSection
            appearanceSection
            aboutSection
            exportSection
            clearHistorySection
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    // 1) Save local appSettings to UserDefaults
                    saveSettings()
                    // 2) Update the actual ChatViewModel with new settings
                    chatViewModel.updateAppSettings(appSettings)
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $isShowingShareSheet) {
            ActivityViewControllerWrapper(activityItems: shareSheetItems, applicationActivities: nil)
        }
        // Use a dynamic background that checks `isDarkMode`
        .background(
            Color.Theme.primaryGradient(isDarkMode: isDarkMode)
                .ignoresSafeArea()
        )
        .onAppear {
            loadSettings()
            systemVoices = VoiceHelper.getAvailableVoices()

            // Validate the currently selected system voice.
            if !VoiceHelper.isValidVoiceIdentifier(appSettings.selectedSystemVoiceId) {
                appSettings.selectedSystemVoiceId = VoiceHelper.getDefaultVoiceIdentifier()
                saveSettings()
            }
        }
        .onChange(of: appSettings) { _, _ in
            // Auto-persist changes whenever appSettings changes
            saveSettings()
        }
    }

    // MARK: - Section: Chat Provider
    private var providerSection: some View {
        Section {
            Picker("Provider", selection: $appSettings.selectedProvider) {
                ForEach(ChatProvider.allCases) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: appSettings.selectedProvider) { _, newProvider in
                let availableModels = newProvider.availableModels
                if !availableModels.contains(where: { $0.id == appSettings.selectedModelId }) {
                    appSettings.selectedModelId = newProvider.defaultModel.id
                }
            }
        } header: {
            Text("Chat Provider")
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: isDarkMode))
        } footer: {
            Text(appSettings.selectedProvider == .openAI
                 ? "Uses OpenAI's GPT models"
                 : appSettings.selectedProvider == .anthropic
                 ? "Uses Anthropic's Claude models"
                 : "Uses GitHub/Azure-based model endpoints.")
            .foregroundStyle(Color.Theme.textSecondary(isDarkMode: isDarkMode))
        }
    }

    // MARK: - Section: Model
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
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: isDarkMode))
        }
    }

    // MARK: - Section: API Key
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

    // MARK: - Section: System Message
    private var systemMessageSection: some View {
        Section {
            TextEditor(text: $appSettings.systemMessage)
                .frame(minHeight: 100)
                .padding(.vertical, 4)
        } header: {
            Text("System Message")
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: isDarkMode))
        } footer: {
            Text("Provide instructions that define how the AI assistant should behave.")
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: isDarkMode))
        }
    }

    // MARK: - Section: Voice Settings
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
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: isDarkMode))
        } footer: {
            Text(appSettings.selectedVoiceProvider == .system
                 ? "Uses the device's built-in text-to-speech voices."
                 : "Uses OpenAI's neural voices for a higher-quality reading.")
            .foregroundStyle(Color.Theme.textSecondary(isDarkMode: isDarkMode))
        }
    }

    // MARK: - Section: Appearance
    private var appearanceSection: some View {
        Section {
            // Replace old "Dark Mode" toggle with a segmented picker
            Picker("App Theme", selection: $appSettings.themeMode) {
                Text("System").tag(ThemeMode.system)
                Text("Light").tag(ThemeMode.light)
                Text("Dark").tag(ThemeMode.dark)
            }
            .pickerStyle(.segmented)

        } header: {
            Text("Appearance")
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: isDarkMode))
        }
    }

    // MARK: - Section: About
    private var aboutSection: some View {
        Section {
            NavigationLink(destination: AboutView()) {
                Text("About")
            }
        } header: {
            Text("About")
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: isDarkMode))
        } footer: {
            Text("Learn more about Ophelia, including version and credits.")
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: isDarkMode))
        }
    }

    // MARK: - Section: Export Discussion
    private var exportSection: some View {
        Section {
            Button("Export Discussion to JSON") {
                if let fileURL = chatViewModel.exportConversationAsJSONFile() {
                    shareSheetItems = [fileURL]
                    isShowingShareSheet = true
                } else {
                    print("Failed to export conversation as JSON.")
                }
            }
        } header: {
            Text("Export")
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: isDarkMode))
        } footer: {
            Text("Export your chat history as a JSON file.")
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: isDarkMode))
        }
    }

    // MARK: - Section: Clear Conversation History
    private var clearHistorySection: some View {
        Section {
            Button(role: .destructive) {
                showClearHistoryAlert = true
            } label: {
                Text("Clear Conversation History")
                    .foregroundColor(.red)
            }
            .alert("Clear Conversation History?", isPresented: $showClearHistoryAlert) {
                Button("Delete", role: .destructive) {
                    clearMessages?()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action will permanently delete all saved chat messages.")
            }
        } footer: {
            Text("Deleting the conversation history is irreversible. Make sure you want to remove all past messages.")
                .foregroundStyle(Color.Theme.textSecondary(isDarkMode: isDarkMode))
        }
    }

    // MARK: - Persistence Helpers
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
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
