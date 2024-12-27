//
//  ChatSettingsSheet.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//  Updated to remove tempSettings and rely on a direct reference to the ChatViewModel.
//

import SwiftUI

/// A sheet that presents the `SettingsView` wrapped in a `NavigationStack`.
/// The user can dismiss by tapping "Done", and any changes within `SettingsView`
/// are applied immediately to `chatViewModel.appSettings`.
struct ChatSettingsSheet: View {
    /// Controls whether the sheet is showing
    @Binding var showingSettings: Bool

    /// The main ChatViewModel, providing access to appSettings and other logic
    @ObservedObject var chatViewModel: ChatViewModel

    /// Optional callback to clear messages
    var clearMessages: (() -> Void)?

    var body: some View {
        NavigationStack {
            // Reuse SettingsView, passing the same ChatViewModel
            SettingsView(chatViewModel: chatViewModel, clearMessages: clearMessages)
                .navigationBarTitle("Settings", displayMode: .inline)
                .toolbar {
                    // A 'Done' button to dismiss the sheet
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showingSettings = false
                        }
                    }
                }
        }
    }
}
