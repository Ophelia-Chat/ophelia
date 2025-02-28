//
//  AboutView.swift
//  ophelia
//
//  Created by rob on 2024-12-22.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let isDarkMode = (colorScheme == .dark)
        
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                // Introduction
                Text("""
                     Ophelia is a minimalist, SwiftUI-based chatbot interface designed for smooth and \
                     engaging conversations. It supports multiple AI providers—OpenAI, Anthropic, \
                     GitHub/Azure-based models, and Ollama for local inference—and offers features such as speech synthesis and \
                     a customizable system message. Stay productive, creative, and connected with Ophelia!
                     """)
                .font(.body)
                
                // Key Features
                Text("Key Features")
                    .font(.headline)
                
                Text("""
                     • **Multiple AI Providers**: Effortlessly switch between OpenAI, Anthropic, GitHub/Azure models, and Ollama for local inference.
                     • **Speech Integration**: Autoplay responses with system voices or OpenAI-based TTS.
                     • **Customizable System Message**: Personalize the AI's behavior and style.
                     • **Active Development**: Experience early features via the TestFlight beta, helping refine Ophelia.
                     """)
                .font(.subheadline)
                .padding(.bottom)
                
                // Link to Source Code
                Text("Source Code")
                    .font(.headline)
                
                Text("""
                     Ophelia is fully open source. You can view and contribute to the project on GitHub:
                     """)
                .font(.body)
                
                Link("View on GitHub",
                     destination: URL(string: "https://github.com/kroonen/ophelia")!)
                .foregroundColor(.blue)
                
                // License Information
                Text("License")
                    .font(.headline)
                
                Text("""
                     Ophelia is distributed under the GNU Affero General Public License v3.0 (AGPL). \
                     Any use of this software over a network must provide access to its source code. \
                     For more information, please visit the AGPL v3.0 website:
                     """)
                .font(.body)
                
                Link("AGPL v3.0 License",
                     destination: URL(string: "https://www.gnu.org/licenses/agpl-3.0.html")!)
                .foregroundColor(.blue)
                
                // Divider
                Divider()
                
                // Additional Info (Version & Developer)
                HStack {
                    Text("Version:")
                        .bold()
                    Text("1.0.0")
                }
                HStack {
                    Text("Developer:")
                        .bold()
                    Text("Robin Kroonen")
                }
                
                Link("Visit KROONEN.AI",
                     destination: URL(string: "https://kroonen.ai")!)
                .foregroundColor(.blue)
                .padding(.top, 8)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("About Ophelia")
        // Apply your theme's gradient background, keyed off `isDarkMode`
        .background(
            Color.Theme.primaryGradient(isDarkMode: isDarkMode)
        )
    }
}
