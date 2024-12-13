//
//  Message.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import Foundation
import Combine

protocol Message {
    var id: UUID { get }
    var text: String { get }
    var isUser: Bool { get }
    var timestamp: Date { get }
}

class MutableMessage: ObservableObject, Message {
    let id: UUID
    @Published var text: String
    let isUser: Bool
    let timestamp: Date
    
    init(id: UUID = UUID(), text: String = "", isUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
    }
}
