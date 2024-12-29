//
//  SettingsView.swift
//  ophelia
//
//  Description:
//  A SwiftUI form for adjusting chat settings (provider, model, API key, etc.),
//  with dynamic fetching **only** for OpenAI. Anthropic/GitHub use fallback models.
//  Now includes an About link and a confirmation before clearing history.
//

import SwiftUI
import AVFoundation

// MARK: - ActivityViewControllerWrapper
struct ActivityViewControllerWrapper: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems,
                                 applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - SettingsView
struct SettingsView: View {
    // MARK: - Observed Properties
    @ObservedObject var chatViewModel: ChatViewModel

    /// A cache of available AVSpeechSynthesisVoices, if using system TTS.
    @State private var systemVoices: [AVSpeechSynthesisVoice] = []

    /// Data for sharing an exported JSON file.
    @State private var shareSheetItems: [Any] = []
    
    /// Toggles the share sheet for exporting chat history.
    @State private var isShowingShareSheet = false

    /// Toggles the confirmation alert before clearing history.
    @State private var isShowingClearConfirmation = false

    /// Optional callback to clear messages (e.g., “Clear Conversation History”).
    var clearMessages: (() -> Void)? = nil
    
    /// For iOS <15 style dismissal from a Navigation-based context.
    @Environment(\.presentationMode) private var presentationMode

    // MARK: - Body
    var body: some View {
        Form {
            providerSection()
            modelSection
            apiKeySection
            systemMessageSection
            voiceSection
            themeSection
            exportSection
            exportMemoriesSection
            aboutSection
            clearHistorySection
        }
        .navigationTitle("Settings")
        // Displays share sheet for JSON exports
        .sheet(isPresented: $isShowingShareSheet) {
            ActivityViewControllerWrapper(
                activityItems: shareSheetItems,
                applicationActivities: nil
            )
        }
        .alert(
            "Are you sure you want to clear all chat history?",
            isPresented: $isShowingClearConfirmation
        ) {
            Button("Clear", role: .destructive) {
                clearMessages?()
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            // Load system voices if needed
            systemVoices = VoiceHelper.getAvailableVoices()
        }
    }
}

// MARK: - Subviews
extension SettingsView {
    // MARK: Provider
    func providerSection() -> some View {
        Section(
            header: Text("Chat Provider"),
            footer: Text(providerFooter(chatViewModel.appSettings.selectedProvider))
        ) {
            Picker("Provider", selection: $chatViewModel.appSettings.selectedProvider) {
                ForEach(ChatProvider.allCases) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: chatViewModel.appSettings.selectedProvider) { oldProvider, newProvider in
                Task {
                    // 1) Fetch or apply fallback models
                    if newProvider == .openAI {
                        await fetchModels(for: newProvider)
                    } else {
                        applyFallbackModels(for: newProvider)
                    }
                    
                    // 2) If the user’s chosen model no longer exists for the new provider, reset it
                    let providerList = chatViewModel.appSettings.modelsForProvider[newProvider]
                                     ?? newProvider.availableModels
                    if !providerList.contains(where: { $0.id == chatViewModel.appSettings.selectedModelId }) {
                        chatViewModel.appSettings.selectedModelId = newProvider.defaultModel.id
                    }

                    // 3) Re-init chat service so the switch happens now
                    chatViewModel.initializeChatService(with: chatViewModel.appSettings)
                    
                    // 4) Persist
                    await chatViewModel.saveSettings()
                    print("[SettingsView] Switched provider: \(newProvider)")
                }
            }
        }
    }

    // MARK: Model
    private var modelSection: some View {
        Section(header: Text("Model")) {
            let provider = chatViewModel.appSettings.selectedProvider
            // Use either dynamic list or built-in provider models
            let dynamicList = chatViewModel.appSettings.modelsForProvider[provider]
                              ?? provider.availableModels

            NavigationLink(
                destination: ModelPickerView(
                    provider: provider,
                    selectedModelId: $chatViewModel.appSettings.selectedModelId,
                    dynamicModels: dynamicList
                )
            ) {
                HStack {
                    Text("Select Model")
                    Spacer()
                    Text(chatViewModel.appSettings.selectedModel.name)
                        .foregroundColor(.secondary)
                }
            }

            Button("Refresh Models") {
                Task {
                    if provider == .openAI {
                        await fetchModels(for: provider, force: true)
                    } else {
                        applyFallbackModels(for: provider)
                    }
                }
            }
            .buttonStyle(.borderless)
        }
    }

    // MARK: API Key
    private var apiKeySection: some View {
        Section(
            header: Text("API Key"),
            footer: Text(apiKeyFooter(chatViewModel.appSettings.selectedProvider))
        ) {
            switch chatViewModel.appSettings.selectedProvider {
            case .openAI:
                SecureField("OpenAI API Key", text: $chatViewModel.appSettings.openAIKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: chatViewModel.appSettings.openAIKey) { oldValue, newValue in
                        Task {
                            await chatViewModel.saveSettings()
                            print("[SettingsView] OpenAI key changed -> saved.")
                        }
                    }

            case .anthropic:
                SecureField("Anthropic API Key", text: $chatViewModel.appSettings.anthropicKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: chatViewModel.appSettings.anthropicKey) { oldValue, newValue in
                        Task {
                            await chatViewModel.saveSettings()
                            print("[SettingsView] Anthropic key changed -> saved.")
                        }
                    }

            case .githubModel:
                SecureField("GitHub Token", text: $chatViewModel.appSettings.githubToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: chatViewModel.appSettings.githubToken) { oldValue, newValue in
                        Task {
                            await chatViewModel.saveSettings()
                            print("[SettingsView] GitHub token changed -> saved.")
                        }
                    }
            }
        }
    }

    // MARK: System Message
    private var systemMessageSection: some View {
        Section(
            header: Text("System Message"),
            footer: Text("Provide instructions that define how the AI assistant should behave.")
        ) {
            TextEditor(text: $chatViewModel.appSettings.systemMessage)
                .frame(minHeight: 120)
                .padding(.vertical, 4)
        }
    }

    // MARK: Voice
    private var voiceSection: some View {
        Section(header: Text("Voice Settings")) {
            Picker("Voice Provider", selection: $chatViewModel.appSettings.selectedVoiceProvider) {
                ForEach(VoiceProvider.allCases) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .pickerStyle(.segmented)

            if chatViewModel.appSettings.selectedVoiceProvider == .system {
                Picker("System Voice", selection: $chatViewModel.appSettings.selectedSystemVoiceId) {
                    ForEach(systemVoices, id: \.identifier) { voice in
                        Text(VoiceHelper.voiceDisplayName(for: voice))
                            .tag(voice.identifier)
                    }
                }
            } else {
                Picker("OpenAI Voice", selection: $chatViewModel.appSettings.selectedOpenAIVoice) {
                    ForEach(openAIVoiceAliases, id: \.0) { (value, label) in
                        Text(label).tag(value)
                    }
                }
            }

            Toggle("Autoplay AI Responses", isOn: $chatViewModel.appSettings.autoplayVoice)
        }
    }

    // MARK: Theme
    private var themeSection: some View {
        Section(header: Text("Appearance")) {
            Picker("App Theme", selection: $chatViewModel.appSettings.themeMode) {
                Text("System").tag(ThemeMode.system)
                Text("Light").tag(ThemeMode.light)
                Text("Dark").tag(ThemeMode.dark)
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: Export
    private var exportSection: some View {
        Section(
            header: Text("Export"),
            footer: Text("Export your chat history as a JSON file.")
        ) {
            Button("Export Discussion to JSON") {
                if let fileURL = chatViewModel.exportConversationAsJSONFile() {
                    shareSheetItems = [fileURL]
                    isShowingShareSheet = true
                } else {
                    print("Failed to export conversation as JSON.")
                }
            }
        }
    }

    private var exportMemoriesSection: some View {
        Section(header: Text("Export Memories"),
                footer: Text("Exports your Memories.json content as a separate JSON file.")) {
            Button("Export Memories to JSON") {
                if let fileURL = chatViewModel.memoryStore.exportMemoriesAsJSONFile() {
                    shareSheetItems = [fileURL]
                    isShowingShareSheet = true
                } else {
                    print("Failed to export memories as JSON.")
                }
            }
        }
    }

    // MARK: About
    private var aboutSection: some View {
        Section(header: Text("About")) {
            NavigationLink("About Ophelia") {
                // Ensure you have an AboutView (or rename to your custom view):
                AboutView()
            }
        }
    }

    // MARK: Clear History
    private var clearHistorySection: some View {
        Section {
            // Tapping this triggers an alert confirmation
            Button(role: .destructive) {
                isShowingClearConfirmation = true
            } label: {
                Text("Clear Conversation History")
            }
        } footer: {
            Text("This action will permanently delete all saved chat messages.")
        }
    }
}

// MARK: - Helpers
extension SettingsView {
    /// Attempts to fetch new models if provider == .openAI; otherwise uses fallback.
    private func fetchModels(for provider: ChatProvider, force: Bool = false) async {
        guard provider == .openAI else {
            applyFallbackModels(for: provider)
            return
        }
        
        do {
            let fetched = try await ModelListService().fetchModels(
                for: provider,
                apiKey: chatViewModel.appSettings.currentAPIKey
            )
            chatViewModel.appSettings.modelsForProvider[provider] = fetched
            
            // If selected model no longer valid, pick the first fetched as default
            if !fetched.contains(where: { $0.id == chatViewModel.appSettings.selectedModelId }),
               let first = fetched.first {
                chatViewModel.appSettings.selectedModelId = first.id
            }
        } catch {
            print("Failed to fetch models for \(provider): \(error)")
            applyFallbackModels(for: provider)
        }
    }

    /// Reverts to built-in models if fetch fails or provider != .openAI
    private func applyFallbackModels(for provider: ChatProvider) {
        let fallback = provider.availableModels
        chatViewModel.appSettings.modelsForProvider[provider] = fallback
        
        if !fallback.contains(where: { $0.id == chatViewModel.appSettings.selectedModelId }),
           let first = fallback.first {
            chatViewModel.appSettings.selectedModelId = first.id
        }
    }

    private func providerFooter(_ provider: ChatProvider) -> String {
        switch provider {
        case .openAI:
            return "Uses OpenAI's GPT models"
        case .anthropic:
            return "Uses Anthropic's Claude models"
        case .githubModel:
            return "Uses GitHub/Azure-based model endpoints."
        }
    }

    private func apiKeyFooter(_ provider: ChatProvider) -> String {
        switch provider {
        case .openAI:
            return "Enter your OpenAI API key from platform.openai.com"
        case .anthropic:
            return "Enter your Anthropic API key from console.anthropic.com"
        case .githubModel:
            return "Enter your GitHub token for Azure-based model access."
        }
    }

    /// A small set of OpenAI TTS voices with friendlier display names
    private var openAIVoiceAliases: [(String, String)] {
        [
            ("alloy",   "Alloy"),
            ("echo",    "Echo"),
            ("fable",   "Fable"),
            ("onyx",    "Onyx"),
            ("nova",    "Nova"),
            ("shimmer", "Shimmer")
        ]
    }

    /// For older iOS dismissal. If using `.dismiss` on iOS 15+, you can remove this.
    private func dismissManually() {
        presentationMode.wrappedValue.dismiss()
    }
}
