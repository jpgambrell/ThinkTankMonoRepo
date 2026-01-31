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
    let errorMessage: String?
    let isError: Bool
    
    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        modelId: String? = nil,
        errorMessage: String? = nil,
        isError: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.modelId = modelId
        self.errorMessage = errorMessage
        self.isError = isError
    }
    
    /// Create an error message for display
    static func errorMessage(for error: Error, originalContent: String = "") -> Message {
        let errorText: String
        if let localizedError = error as? LocalizedError {
            errorText = localizedError.localizedDescription
        } else {
            errorText = error.localizedDescription
        }
        
        return Message(
            role: .assistant,
            content: "Failed to get response",
            errorMessage: errorText,
            isError: true
        )
    }
}
