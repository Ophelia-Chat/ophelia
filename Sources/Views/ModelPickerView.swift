//
//  ModelPickerView.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import SwiftUI

struct ModelPickerView: View {
    let provider: ChatProvider
    @Binding var selectedModelId: String
    
    var body: some View {
        List {
            ForEach(provider.availableModels) { model in
                Button {
                    selectedModelId = model.id
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(model.name)
                                .foregroundStyle(.primary)
                            Text(model.id)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if selectedModelId == model.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Select Model")
    }
}

#Preview {
    NavigationView {
        ModelPickerView(
            provider: .openAI,
            selectedModelId: .constant("gpt-4")
        )
    }
}
