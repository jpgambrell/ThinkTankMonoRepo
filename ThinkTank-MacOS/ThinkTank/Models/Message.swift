//
//  Message.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import Foundation

enum MessageRole: String, Codable {
    case user
    case assistant
}

struct Message: Identifiable, Codable, Equatable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let modelId: String?
    
    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        modelId: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.modelId = modelId
    }
}
