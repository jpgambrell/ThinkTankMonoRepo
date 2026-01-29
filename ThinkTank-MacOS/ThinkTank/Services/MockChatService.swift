//
//  MockChatService.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import Foundation

actor MockChatService {
    static let shared = MockChatService()
    
    private init() {}
    
    // Mock responses that echo and add some flavor
    private let responseTemplates = [
        "Interesting question about \"%@\"! Let me think about that...\n\nHere are my thoughts:\n\n• First, I'd consider the core aspects of your query\n• Then, we could explore the underlying concepts\n• Finally, let's look at practical applications\n\nWould you like me to elaborate on any of these points?",
        
        "Great topic! You mentioned \"%@\" which is fascinating.\n\nLet me break this down:\n\n1. **Key Concept**: The fundamental idea here relates to...\n2. **Implementation**: In practice, you would want to...\n3. **Best Practices**: Always remember to...\n\nIs there a specific aspect you'd like to dive deeper into?",
        
        "I'd be happy to help with \"%@\"!\n\n```swift\n// Here's a code example\nfunc example() {\n    print(\"Hello, ThinkTank!\")\n}\n```\n\nThis demonstrates the basic approach. The key things to note are:\n\n- Clean, readable syntax\n- Proper error handling\n- Following Swift conventions",
        
        "Ah, \"%@\" - excellent choice of topic!\n\n**Summary**\nThis is a common challenge that many developers face. The solution involves understanding a few core principles.\n\n**Recommendations**\n• Start with a solid foundation\n• Build incrementally\n• Test thoroughly\n• Iterate based on feedback\n\nLet me know if you need more specific guidance!",
        
        "Thanks for asking about \"%@\"!\n\nHere's what I think:\n\n> The best approach is often the simplest one that solves the problem effectively.\n\nIn your case, I'd suggest:\n\n1. Define the requirements clearly\n2. Prototype quickly\n3. Refine based on testing\n4. Document your decisions\n\nWhat's your current progress on this?"
    ]
    
    func sendMessage(_ content: String, modelId: String) async throws -> Message {
        // Simulate network delay (1-3 seconds)
        let delay = Double.random(in: 1.0...3.0)
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        // Generate a response based on the input
        let responseContent = generateResponse(for: content)
        
        return Message(
            role: .assistant,
            content: responseContent,
            timestamp: Date(),
            modelId: modelId
        )
    }
    
    private func generateResponse(for input: String) -> String {
        // Extract key words from input for echo effect
        let words = input.split(separator: " ")
        let keyPhrase: String
        
        if words.count > 5 {
            keyPhrase = words.prefix(5).joined(separator: " ") + "..."
        } else {
            keyPhrase = input
        }
        
        // Pick a random template
        let template = responseTemplates.randomElement() ?? responseTemplates[0]
        
        return String(format: template, keyPhrase)
    }
}

// MARK: - Error Types
enum ChatServiceError: LocalizedError {
    case networkError
    case invalidResponse
    case modelUnavailable
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Unable to connect to the server. Please check your internet connection."
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .modelUnavailable:
            return "The selected model is currently unavailable. Please try another model."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        }
    }
}
