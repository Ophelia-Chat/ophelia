//
//  ModelPickerView.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//  Updated to support dynamic model lists and incorporate best practices.
//
//  Description:
//  A SwiftUI view that displays a list of `ChatModel` objects (e.g., GPT-3.5, GPT-4, Claude, etc.).
//  Once the user taps a model, the `selectedModelId` binding is updated accordingly.
//
//  Dependencies:
//  - ChatProvider: An enum representing which AI provider is selected (OpenAI, Anthropic, etc.).
//  - ChatModel:    A struct conforming to Identifiable and Codable, containing at least `id`, `name`, and `provider`.
//  - If you plan to pass a dynamic/fetched model list, store it in `dynamicModels`.
//    Otherwise, you can fall back on `provider.availableModels`.
//
//  Context Integration Notes:
//  - The `selectedModelId` binding should be tied to a property in AppSettings or your ViewModel.
//  - If you are fetching models at runtime and storing them (e.g., in AppSettings.modelsForProvider),
//    you can pass that array here via `dynamicModels`.
//

import SwiftUI

/// A SwiftUI view that displays a list of `ChatModel` objects.
/// On tap, updates the `selectedModelId` binding.
struct ModelPickerView: View {
    // MARK: - Properties
    
    /// The current provider (OpenAI, Anthropic, etc.).
    /// This is optional context if you need to display or log provider info.
    let provider: ChatProvider
    
    /// The user’s currently selected model ID. We update this when they pick a new model.
    @Binding var selectedModelId: String
    
    /// An array of `ChatModel` items to display in the list.
    /// This can be a fetched dynamic list or a fallback from `provider.availableModels`.
    let dynamicModels: [ChatModel]
    
    // MARK: - Body
    
    var body: some View {
        List {
            // Show each model in `dynamicModels`.
            ForEach(dynamicModels) { model in
                Button {
                    // Update the binding with the chosen model ID.
                    selectedModelId = model.id
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(model.name)       // user-friendly display name
                                .foregroundStyle(.primary)
                            
                            Text(model.id)         // underlying model ID in smaller font
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        // Show a checkmark if this model is currently selected.
                        if selectedModelId == model.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                // Avoids default button styles to keep a custom look.
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Select Model")
    }
}

// MARK: - Preview

#Preview {
    // A quick SwiftUI preview to see how ModelPickerView renders.
    // Assume you have a ChatModel array for testing:
    let sampleModels = [
        ChatModel(id: "gpt-4", name: "GPT-4", provider: .openAI),
        ChatModel(id: "gpt-3.5-turbo", name: "GPT-3.5 Turbo", provider: .openAI)
    ]
    
    return NavigationView {
        ModelPickerView(
            provider: .openAI,
            selectedModelId: .constant("gpt-4"),
            dynamicModels: sampleModels
        )
    }
}
