//
//  Conversation.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import Foundation

struct Conversation: Identifiable, Equatable {
    let id: UUID
    var title: String
    var messages: [Message]
    var modelId: String
    let createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        title: String = "New Chat",
        messages: [Message] = [],
        modelId: String = "anthropic.claude-3-5-sonnet",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.modelId = modelId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var lastMessagePreview: String {
        messages.last?.content ?? "No messages yet"
    }
    
    var messageCount: Int {
        messages.count
    }
}
