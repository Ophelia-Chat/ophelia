import SwiftUI

struct ChatSettingsSheet: View {
    @Binding var tempSettings: AppSettings
    @Binding var showingSettings: Bool
    
    var body: some View {
        NavigationStack {
            SettingsView()
        }
    }
}
