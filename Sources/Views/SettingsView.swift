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
    
    // Add these new state properties
    @State private var errorMessage: String?
    @State private var showError = false

    /// A cache of available AVSpeechSynthesisVoices, if using system TTS.
    @State private var systemVoices: [AVSpeechSynthesisVoice] = []

    /// Data for sharing an exported JSON file.
    @State private var shareSheetItems: [Any] = []
    
    /// Toggles the share sheet for exporting chat history.
    @State private var isShowingShareSheet = false

    /// Toggles the confirmation alert before clearing history.
    @State private var isShowingClearConfirmation = false

    /// Optional callback to clear messages (e.g., "Clear Conversation History").
    var clearMessages: (() -> Void)? = nil
    
    /// For iOS <15 style dismissal from a Navigation-based context.
    @Environment(\.presentationMode) private var presentationMode

    // MARK: - Body
    var body: some View {
        Form {
            providerSection()
            modelSection
            apiKeySection
            ollamaSection
            systemMessageSection
            voiceSection
            themeSection
            exportSection
            exportMemoriesSection
            aboutSection
            clearHistorySection
        }
        .navigationTitle("Settings")
        // Add the error alert
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
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
                    // 1) For OpenAI, only fetch models if we have a valid API key
                    if newProvider == .openAI {
                        if !chatViewModel.appSettings.openAIKey.isEmpty {
                            await fetchModels(for: newProvider)
                        } else {
                            // Just use fallback models if no key is provided
                            applyFallbackModels(for: newProvider)
                            print("[SettingsView] Using fallback models for OpenAI (no API key)")
                        }
                    } else {
                        // For other providers, use fallback models
                        applyFallbackModels(for: newProvider)
                    }
                    
                    // 2) If the user's chosen model no longer exists for the new provider, reset it
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
                    if provider == .openAI || provider == .ollama {
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
            
            case .ollama:
                // For Ollama, we show a placeholder but the full settings are in ollamaSection
                Text("No API key needed for Ollama. Configure server in Ollama Settings below.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: Ollama Settings
    @ViewBuilder
    private var ollamaSection: some View {
        if chatViewModel.appSettings.selectedProvider == .ollama {
            Section(
                header: Text("Ollama Settings"),
                footer: Text("Configure your Ollama server URL (default: http://localhost:11434). Make sure to include http:// or https://")
            ) {
                TextField("Ollama Server URL", text: $chatViewModel.appSettings.ollamaServerURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: chatViewModel.appSettings.ollamaServerURL) { _, newURL in
                        // Process URL when it changes
                        Task {
                            // 1. Clean up the URL by trimming whitespace
                            let trimmedURL = newURL.trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            // 2. Check for and fix common URL issues
                            var processedURL = trimmedURL
                            
                            // Remove any duplicate http:// prefixes (like http://http://)
                            if processedURL.contains("://") {
                                // Split by :// and take at most the scheme + the rest
                                let components = processedURL.components(separatedBy: "://")
                                if components.count > 1 {
                                    // Keep only the first scheme and the last component
                                    let scheme = components[0].lowercased()
                                    let host = components.last ?? ""
                                    
                                    // Only accept http or https schemes
                                    if scheme == "http" || scheme == "https" {
                                        processedURL = "\(scheme)://\(host)"
                                    } else {
                                        // If scheme is invalid, default to http
                                        processedURL = "http://\(host)"
                                    }
                                }
                            } else {
                                // No scheme found, add http://
                                processedURL = "http://" + processedURL
                            }
                            
                            // 3. Remove trailing slashes
                            while processedURL.hasSuffix("/") {
                                processedURL.removeLast()
                            }
                            
                            // 4. Update if different from the original
                            if processedURL != newURL {
                                DispatchQueue.main.async {
                                    chatViewModel.appSettings.ollamaServerURL = processedURL
                                }
                            }
                            
                            // 5. Save settings and reinitialize service
                            await chatViewModel.saveSettings()
                            chatViewModel.initializeChatService(with: chatViewModel.appSettings)
                            
                            print("[SettingsView] Updated Ollama URL: \(processedURL)")
                        }
                    }
                
                // Add a Test Connection button
                Button("Test Connection") {
                    Task {
                        let connectionResult = await testOllamaConnection(url: chatViewModel.appSettings.ollamaServerURL)
                        if connectionResult.success {
                            errorMessage = "Successfully connected to Ollama server!"
                            showError = true
                        } else {
                            errorMessage = "Connection failed: \(connectionResult.message)"
                            showError = true
                        }
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
    /// Attempts to fetch new models if provider == .openAI or .ollama; otherwise uses fallback.
    private func fetchModels(for provider: ChatProvider, force: Bool = false) async {
        // If not OpenAI or Ollama, just use fallback models
        guard provider == .openAI || provider == .ollama else {
            applyFallbackModels(for: provider)
            return
        }
        
        // For OpenAI, make sure we have an API key
        if provider == .openAI {
            guard !chatViewModel.appSettings.openAIKey.isEmpty else {
                print("[SettingsView] No OpenAI API key provided, using fallback models")
                applyFallbackModels(for: provider)
                
                // Only show error if user explicitly requested refresh
                if force {
                    errorMessage = "Please enter a valid OpenAI API key first."
                    showError = true
                }
                return
            }
            
            // Continue with fetching if we have a key
            do {
                let fetched = try await ModelListService().fetchModels(
                    for: provider,
                    apiKey: chatViewModel.appSettings.openAIKey
                )
                
                if !fetched.isEmpty {
                    chatViewModel.appSettings.modelsForProvider[provider] = fetched
                    
                    if !fetched.contains(where: { $0.id == chatViewModel.appSettings.selectedModelId }),
                       let first = fetched.first {
                        chatViewModel.appSettings.selectedModelId = first.id
                    }
                    
                    await chatViewModel.saveSettings()
                } else {
                    print("[SettingsView] Warning: Received empty model list from \(provider)")
                }
            } catch {
                print("[SettingsView] Failed to fetch models for \(provider): \(error)")
                applyFallbackModels(for: provider)
                
                // Show error alert for network issues only if force refresh or explicit request
                if force {
                    errorMessage = "Failed to fetch models: \(error.localizedDescription)"
                    showError = true
                }
            }
            return
        }
        
        // For Ollama, continue with existing handling
        if provider == .ollama {
            do {
                var serverURL = chatViewModel.appSettings.ollamaServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Add http:// scheme if missing
                if !serverURL.hasPrefix("http://") && !serverURL.hasPrefix("https://") {
                    serverURL = "http://" + serverURL
                    // Update the UI value with the corrected URL
                    DispatchQueue.main.async {
                        chatViewModel.appSettings.ollamaServerURL = serverURL
                    }
                }
                
                print("[SettingsView] Fetching Ollama models from: \(serverURL)")
                
                let fetched = try await ModelListService().fetchModels(
                    for: provider,
                    apiKey: serverURL
                )
                
                if !fetched.isEmpty {
                    chatViewModel.appSettings.modelsForProvider[provider] = fetched
                    
                    if !fetched.contains(where: { $0.id == chatViewModel.appSettings.selectedModelId }),
                       let first = fetched.first {
                        chatViewModel.appSettings.selectedModelId = first.id
                    }
                    
                    await chatViewModel.saveSettings()
                } else {
                    print("[SettingsView] Warning: Received empty model list from Ollama")
                    // Apply fallback if empty
                    applyFallbackModels(for: provider)
                }
            } catch {
                print("[SettingsView] Failed to fetch Ollama models: \(error)")
                
                // Apply fallback models but DON'T show error alert for Ollama connection issues
                applyFallbackModels(for: provider)
                
                // Only show a more helpful error message if the user explicitly requested a refresh
                if force {
                    errorMessage = "Cannot connect to Ollama server at \(chatViewModel.appSettings.ollamaServerURL). Please check that Ollama is running and the URL is correct."
                    showError = true
                }
            }
        }
    }

    /// Tests the connection to an Ollama server
    private func testOllamaConnection(url: String) async -> (success: Bool, message: String) {
        // 1. Validate URL format
        guard var components = URLComponents(string: url) else {
            return (false, "Invalid URL format")
        }
        
        // 2. Add scheme if missing
        if components.scheme == nil {
            components.scheme = "http"
        }
        
        // 3. Only accept http/https
        if components.scheme != "http" && components.scheme != "https" {
            return (false, "URL must use http:// or https://")
        }
        
        // 4. Get final URL
        guard let finalURL = components.url else {
            return (false, "Could not create URL from components")
        }
        
        // 5. Build the test URL (api/tags is a lightweight endpoint)
        let testURL = finalURL.appendingPathComponent("api/tags")
        
        // 6. Create request with short timeout
        var request = URLRequest(url: testURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, "Invalid response type")
            }
            
            if httpResponse.statusCode == 200 {
                return (true, "Connection successful")
            } else {
                return (false, "Server returned status code: \(httpResponse.statusCode)")
            }
        } catch let error as URLError {
            switch error.code {
            case .cannotFindHost:
                return (false, "Cannot find host. Check the server address.")
            case .cannotConnectToHost:
                return (false, "Cannot connect to server. Is Ollama running?")
            case .timedOut:
                return (false, "Connection timed out. Server may be unreachable.")
            case .networkConnectionLost:
                return (false, "Network connection lost during request.")
            default:
                return (false, "URL error: \(error.localizedDescription)")
            }
        } catch {
            return (false, "Error: \(error.localizedDescription)")
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
        case .ollama:
            return "Uses Ollama local LLM. Make sure Ollama is running at http://localhost:11434. No API key required."
        }
    }

    private func apiKeyFooter(_ provider: ChatProvider) -> String {
        switch provider {
        case .openAI:
            return "Enter your OpenAI API key from platform.openai.com"
        case .anthropic:
            return "Enter your Anthropic API key from console.anthropic.com"
        case .ollama:
            return "No API key required. See Ollama Settings section below."
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
