//
//  Message.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import Foundation
import Combine

// MARK: - Message Protocol
protocol Message {
    var id: UUID { get }
    var text: String { get }
    var isUser: Bool { get }
    var timestamp: Date { get }
}

// MARK: - MutableMessage Class
class MutableMessage: ObservableObject, Message, Identifiable, Equatable {
    let id: UUID
    @Published var text: String
    let isUser: Bool
    let timestamp: Date

    var originProvider: String?
    var originModel: String?

    init(id: UUID = UUID(), text: String = "", isUser: Bool, timestamp: Date = Date(),
         originProvider: String? = nil, originModel: String? = nil) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
        self.originProvider = originProvider
        self.originModel = originModel
    }

    // MARK: - Equatable Conformance
    static func == (lhs: MutableMessage, rhs: MutableMessage) -> Bool {
        return lhs.id == rhs.id &&
               lhs.text == rhs.text &&
               lhs.isUser == rhs.isUser &&
               lhs.timestamp == rhs.timestamp &&
               lhs.originProvider == rhs.originProvider &&
               lhs.originModel == rhs.originModel
    }
}
