//
//  ChatMainView.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import SwiftUI

struct ChatMainView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var showingSettings: Bool
    @Binding var tempSettings: AppSettings
    @FocusState private var fieldIsFocused: Bool
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ChatMessagesContainer(
                    messages: viewModel.messages,
                    isLoading: viewModel.isLoading
                )
                
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
    }
}
