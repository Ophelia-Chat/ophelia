//
//  SettingsView.swift
//  ophelia
//
//  Description:
//  A SwiftUI form for adjusting chat settings (provider, model, API key, etc.),
//  incorporating a local copy (`@State var localSettings`) that is synced to the
//  `ChatViewModel` in real-time. Also uses an ID-based force-refresh approach
//  (`reloadID`) to ensure immediate UI updates on provider/model changes.
//
//  Note:
//  - We remove any extra NavigationView here, since ChatSettingsSheet already
//    provides a NavigationStack for this content.
//  - The “Done” button calls `dismissManually()`, using `@Environment(\.presentationMode)`
//    for older iOS versions if you want a secondary approach to dismiss.
//  - The “Refresh Models” button and automatic fetch in `.onChange(of: selectedProvider)`
//    ensures new model lists are fetched immediately.
//
//  Usage:
//   - This view is typically presented by ChatSettingsSheet, which wraps it
//     in a NavigationStack and adds a “Done” button to dismiss the sheet.
//
//  Created by rob on 2024-11-27.
//

import SwiftUI
import AVFoundation

/// A simple UIActivityViewController (share sheet) wrapper for SwiftUI
struct ActivityViewControllerWrapper: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// The main settings form. Uses a local copy of AppSettings (`localSettings`) that
/// syncs changes back to `chatViewModel` on each modification. Also offers a refresh
/// mechanism (`reloadID`) so the UI re-initializes subviews immediately.
struct SettingsView: View {
    // MARK: - Observed Properties
    
    /// The main ChatViewModel controlling app settings and logic.
    @ObservedObject var chatViewModel: ChatViewModel
    
    // MARK: - Local State
    
    /// A local copy of the settings we display and edit in the form.
    @State private var localSettings = AppSettings()
    
    /// A unique ID to force SwiftUI to rebuild the form (e.g. after provider/model changes).
    @State private var reloadID = UUID()
    
    /// A cache of available AVSpeechSynthesisVoices, if using system TTS.
    @State private var systemVoices: [AVSpeechSynthesisVoice] = []
    
    /// Data for sharing an exported JSON file.
    @State private var shareSheetItems: [Any] = []
    
    /// Toggles the share sheet for exporting chat history.
    @State private var isShowingShareSheet = false
    
    /// Optional callback to clear messages (e.g. “Clear Conversation History”).
    var clearMessages: (() -> Void)? = nil
    
    /// For iOS <15 style dismissal from a Navigation-based context.
    @Environment(\.presentationMode) private var presentationMode
    
    // MARK: - Body
    
    var body: some View {
        // We rely on the parent to provide a NavigationStack or NavigationView context.
        Form {
            providerSection
            modelSection
            apiKeySection
            systemMessageSection
            voiceSection
            themeSection
            exportSection
            clearHistorySection
        }
        .id(reloadID)  // Forces a rebuild when we set `reloadID = UUID()`
        .navigationTitle("Settings")
        // For exporting JSON, displayed as a share sheet
        .sheet(isPresented: $isShowingShareSheet) {
            ActivityViewControllerWrapper(activityItems: shareSheetItems, applicationActivities: nil)
        }
        // Initialize localSettings from ChatViewModel on appear
        .onAppear {
            localSettings = chatViewModel.appSettings
            systemVoices = VoiceHelper.getAvailableVoices()
        }
        // Each time localSettings changes, push to chatViewModel
        .onChange(of: localSettings) { _, newValue in
            chatViewModel.updateAppSettings(newValue)
        }
        // If the user changes the model ID, we might refresh the form so the label updates
        .onChange(of: localSettings.selectedModelId) { _, _ in
            reloadID = UUID()
        }
    }
    
    // MARK: - Provider Section
    
    private var providerSection: some View {
        Section(
            header: Text("Chat Provider"),
            footer: Text(providerFooter(localSettings.selectedProvider))
        ) {
            Picker("Provider", selection: $localSettings.selectedProvider) {
                ForEach(ChatProvider.allCases) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: localSettings.selectedProvider) { _, newProvider in
                Task {
                    // Fetch the dynamic model list for the newly selected provider
                    await fetchModels(for: newProvider)
                }
                // If the old model ID isn't valid for the new provider, default to the provider's first model
                if !newProvider.availableModels.contains(where: { $0.id == localSettings.selectedModelId }) {
                    localSettings.selectedModelId = newProvider.defaultModel.id
                }
                // Force immediate UI refresh
                reloadID = UUID()
            }
        }
    }
    
    // MARK: - Model Section
    
    private var modelSection: some View {
        Section(header: Text("Model")) {
            let provider = localSettings.selectedProvider
            // Use a dynamic list if we have fetched data; else fallback to static
            let dynamicList = localSettings.modelsForProvider[provider]
                ?? provider.availableModels
            
            // Navigates to a model picker list
            NavigationLink(
                destination: ModelPickerView(
                    provider: provider,
                    selectedModelId: $localSettings.selectedModelId,
                    dynamicModels: dynamicList
                )
            ) {
                HStack {
                    Text("Select Model")
                    Spacer()
                    // The selected model name might not refresh automatically,
                    // so we rely on .onChange(of: selectedModelId) -> reloadID
                    Text(localSettings.selectedModel.name)
                        .foregroundColor(.secondary)
                }
            }
            
            // A manual refresh button to forcibly fetch new models
            Button("Refresh Models") {
                Task {
                    await fetchModels(for: provider, force: true)
                }
            }
            .buttonStyle(.borderless)
        }
    }
    
    // MARK: - API Key Section
    
    private var apiKeySection: some View {
        Section(
            header: Text("API Key"),
            footer: Text(apiKeyFooter(localSettings.selectedProvider))
        ) {
            switch localSettings.selectedProvider {
            case .openAI:
                SecureField("OpenAI API Key", text: $localSettings.openAIKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            case .anthropic:
                SecureField("Anthropic API Key", text: $localSettings.anthropicKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            case .githubModel:
                SecureField("GitHub Token", text: $localSettings.githubToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
    }
    
    // MARK: - System Message Section
    
    private var systemMessageSection: some View {
        Section(
            header: Text("System Message"),
            footer: Text("Provide instructions that define how the AI assistant should behave.")
        ) {
            TextEditor(text: $localSettings.systemMessage)
                .frame(minHeight: 120)
                .padding(.vertical, 4)
        }
    }
    
    // MARK: - Voice Section
    
    private var voiceSection: some View {
        Section(header: Text("Voice Settings")) {
            Picker("Voice Provider", selection: $localSettings.selectedVoiceProvider) {
                ForEach(VoiceProvider.allCases) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            
            if localSettings.selectedVoiceProvider == .system {
                // A system TTS voice
                Picker("System Voice", selection: $localSettings.selectedSystemVoiceId) {
                    ForEach(systemVoices, id: \.identifier) { voice in
                        Text(VoiceHelper.voiceDisplayName(for: voice))
                            .tag(voice.identifier)
                    }
                }
            } else {
                // An OpenAI TTS voice
                Picker("OpenAI Voice", selection: $localSettings.selectedOpenAIVoice) {
                    ForEach(openAIVoiceAliases, id: \.0) { (value, label) in
                        Text(label).tag(value)
                    }
                }
            }
            
            Toggle("Autoplay AI Responses", isOn: $localSettings.autoplayVoice)
        }
    }
    
    // MARK: - Theme Section
    
    private var themeSection: some View {
        Section(header: Text("Appearance")) {
            Picker("App Theme", selection: $localSettings.themeMode) {
                Text("System").tag(ThemeMode.system)
                Text("Light").tag(ThemeMode.light)
                Text("Dark").tag(ThemeMode.dark)
            }
            .pickerStyle(.segmented)
        }
    }
    
    // MARK: - Export Section
    
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
    
    // MARK: - Clear History
    
    private var clearHistorySection: some View {
        Section {
            Button(role: .destructive) {
                clearMessages?()
            } label: {
                Text("Clear Conversation History")
            }
        } footer: {
            Text("This action will permanently delete all saved chat messages.")
        }
    }
    
    // MARK: - Fetch Logic
    
    private func fetchModels(for provider: ChatProvider, force: Bool = false) async {
        do {
            let fetched = try await ModelListService().fetchModels(
                for: provider,
                apiKey: localSettings.currentAPIKey
            )
            localSettings.modelsForProvider[provider] = fetched
            
            // If the current ID isn't in the new list, pick the first
            if !fetched.contains(where: { $0.id == localSettings.selectedModelId }),
               let first = fetched.first {
                localSettings.selectedModelId = first.id
            }
            
            // Force immediate UI refresh so "Select Model" label updates
            reloadID = UUID()
        } catch {
            print("Failed to fetch models for \(provider): \(error)")
            let fallback = provider.availableModels
            if !fallback.contains(where: { $0.id == localSettings.selectedModelId }),
               let first = fallback.first {
                localSettings.selectedModelId = first.id
            }
            reloadID = UUID()
        }
    }
    
    // MARK: - Utility
    
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
            ("alloy", "Alloy"), ("echo", "Echo"), ("fable", "Fable"),
            ("onyx", "Onyx"),   ("nova", "Nova"), ("shimmer", "Shimmer")
        ]
    }
    
    /// For older iOS dismissal (if needed). If using iOS 15+ .dismiss, you can remove this method.
    private func dismissManually() {
        presentationMode.wrappedValue.dismiss()
    }
}
