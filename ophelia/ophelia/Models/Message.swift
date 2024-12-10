//
//  Message.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import Foundation
import Combine

class MutableMessage: ObservableObject, Identifiable {
    let id: UUID
    @Published var text: String
    @Published var isUser: Bool
    let timestamp: Date

    init(id: UUID = UUID(), text: String, isUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
    }
}
