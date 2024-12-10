import SwiftUI

struct ChatSettingsSheet: View {
    @Binding var tempSettings: AppSettings
    @Binding var showingSettings: Bool
    let onSettingsChange: () -> Void
    
    var body: some View {
        NavigationStack {
            SettingsView(
                appSettings: $tempSettings,
                onSettingsChange: onSettingsChange
            )
        }
    }
}
