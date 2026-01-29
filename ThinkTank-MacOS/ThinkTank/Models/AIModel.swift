//
//  AIModel.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import Foundation
import SwiftUI

struct AIModel: Identifiable, Equatable, Hashable {
    let id: String
    let displayName: String
    let provider: String
    let description: String
    let maxTokens: Int
    let supportsStreaming: Bool
    
    var providerColor: Color {
        switch provider.lowercased() {
        case "anthropic":
            return Color(hex: "059669")
        case "deepseek":
            return Color(hex: "4D6BFE")
        case "amazon":
            return Color(hex: "FF9900")
        case "meta":
            return Color(hex: "0668E1")
        case "mistral":
            return Color(hex: "F54E42")
        default:
            return Color.gray
        }
    }
    
    var iconLetter: String {
        String(displayName.prefix(1))
    }
}

// MARK: - Available Models
extension AIModel {
    static let availableModels: [AIModel] = [
        // Anthropic Claude 4.5 Family
        AIModel(
            id: "anthropic.claude-opus-4-5",
            displayName: "Claude Opus 4.5",
            provider: "Anthropic",
            description: "Most capable",
            maxTokens: 200000,
            supportsStreaming: true
        ),
        AIModel(
            id: "anthropic.claude-sonnet-4-5",
            displayName: "Claude Sonnet 4.5",
            provider: "Anthropic",
            description: "Fast & intelligent",
            maxTokens: 200000,
            supportsStreaming: true
        ),
        AIModel(
            id: "anthropic.claude-haiku-4-5",
            displayName: "Claude Haiku 4.5",
            provider: "Anthropic",
            description: "Fastest responses",
            maxTokens: 200000,
            supportsStreaming: true
        ),
        // DeepSeek
        AIModel(
            id: "deepseek.r1",
            displayName: "DeepSeek-R1",
            provider: "DeepSeek",
            description: "Advanced reasoning",
            maxTokens: 128000,
            supportsStreaming: true
        )
    ]
    
    static var modelsByProvider: [String: [AIModel]] {
        Dictionary(grouping: availableModels, by: { $0.provider })
    }
    
    static var defaultModel: AIModel {
        availableModels.first!
    }
    
    static func model(for id: String) -> AIModel? {
        availableModels.first { $0.id == id }
    }
}
