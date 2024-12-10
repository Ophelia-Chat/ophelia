//
//  ChatHeaderView.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import SwiftUI

struct ChatHeaderView: View {
    @Binding var showingSettings: Bool
    @Binding var tempSettings: AppSettings
    let appSettings: AppSettings
    let clearMessages: () -> Void
    
    var body: some View {
        HStack {
            Menu {
                Button(role: .destructive, action: clearMessages) {
                    Label("Clear Chat", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            
            Spacer()
            
            Text(appSettings.selectedModel.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Button {
                tempSettings = appSettings
                showingSettings = true
            } label: {
                Image(systemName: "gear")
            }
        }
        .padding(.horizontal)
    }
}
