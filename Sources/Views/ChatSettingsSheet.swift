import SwiftUI

struct ChatSettingsSheet: View {
    @Binding var tempSettings: AppSettings
    @Binding var showingSettings: Bool
    
    @ObservedObject var chatViewModel: ChatViewModel
    var clearMessages: (() -> Void)?

    var body: some View {
        NavigationStack {
            SettingsView(chatViewModel: chatViewModel, clearMessages: clearMessages)
        }
    }
}
