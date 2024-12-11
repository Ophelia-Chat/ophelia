//
//  ChatView.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showingSettings = false
    @State private var tempSettings = AppSettings()
    @FocusState private var fieldIsFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.Theme.primaryGradient(isDarkMode: isDarkMode)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header with logo
                    HStack {
                        FlowerLogoView()
                            .frame(width: 32, height: 32)
                        Text("Ophelia")
                            .font(.title2)
                            .fontWeight(.light)
                        Spacer()
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gear")
                                .font(.system(size: 20))
                                .foregroundColor(Color.Theme.textSecondary(isDarkMode: isDarkMode))
                        }
                    }
                    .padding()
                    .background(
                        Color.white.opacity(0.5)
                            .background(.ultraThinMaterial)
                    )

                    // Messages
                    ChatMessagesContainer(
                        messages: viewModel.messages,
                        isLoading: viewModel.isLoading
                    )

                    // Input
                    ChatInputContainer(
                        inputText: $viewModel.inputText,
                        isDisabled: viewModel.appSettings.currentAPIKey.isEmpty,
                        onSend: {
                            Task { @MainActor in
                                viewModel.sendMessage()
                                fieldIsFocused = false
                            }
                        }
                    )
                }
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .sheet(isPresented: $showingSettings) {
                ChatSettingsSheet(
                    tempSettings: $tempSettings,
                    showingSettings: $showingSettings,
                    onSettingsChange: {
                        viewModel.updateAppSettings(tempSettings)
                    }
                )
            }
            .onAppear {
                Task {
                    await viewModel.finalizeSetup()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(role: .destructive, action: {
                            viewModel.clearMessages()
                        }) {
                            Label("Clear Chat", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
}
