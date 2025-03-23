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
                     destination: URL(string: "https://github.com/Ophelia-Chat/ophelia")!)
                .foregroundColor(.blue)

                // License Information
                Text("License")
                    .font(.headline)

                Text("""
                     Ophelia is distributed under the MIT License. You are free to use, modify, and distribute this software with minimal restrictions. For details, please visit:
                     """)
                .font(.body)

                Link("MIT License",
                     destination: URL(string: "https://opensource.org/licenses/MIT")!)
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
                    Text("KROONEN AI, Inc.")
                }

                Link("Visit KROONEN.AI",
                     destination: URL(string: "https://www.kroonen.ai")!)
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
