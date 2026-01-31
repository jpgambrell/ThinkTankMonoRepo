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
        case "openai":
            return Color(hex: "10A37F")
        case "meta":
            return Color(hex: "0668E1")
        case "google":
            return Color(hex: "4285F4")
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

// MARK: - Available Models (OpenRouter)
extension AIModel {
    static let availableModels: [AIModel] = [
        // Anthropic Claude Family
        AIModel(
            id: "anthropic/claude-sonnet-4",
            displayName: "Claude Sonnet 4",
            provider: "Anthropic",
            description: "Fast & intelligent",
            maxTokens: 200000,
            supportsStreaming: true
        ),
        AIModel(
            id: "anthropic/claude-opus-4",
            displayName: "Claude Opus 4",
            provider: "Anthropic",
            description: "Most capable",
            maxTokens: 200000,
            supportsStreaming: true
        ),
        AIModel(
            id: "anthropic/claude-3.5-haiku",
            displayName: "Claude 3.5 Haiku",
            provider: "Anthropic",
            description: "Fastest responses",
            maxTokens: 200000,
            supportsStreaming: true
        ),
        // DeepSeek
        AIModel(
            id: "deepseek/deepseek-r1",
            displayName: "DeepSeek-R1",
            provider: "DeepSeek",
            description: "Advanced reasoning",
            maxTokens: 128000,
            supportsStreaming: true
        ),
        // OpenAI
        AIModel(
            id: "openai/gpt-4o",
            displayName: "GPT-4o",
            provider: "OpenAI",
            description: "Multimodal flagship",
            maxTokens: 128000,
            supportsStreaming: true
        ),
        AIModel(
            id: "openai/gpt-4o-mini",
            displayName: "GPT-4o Mini",
            provider: "OpenAI",
            description: "Fast & affordable",
            maxTokens: 128000,
            supportsStreaming: true
        ),
        // Meta Llama
        AIModel(
            id: "meta-llama/llama-3.3-70b-instruct",
            displayName: "Llama 3.3 70B",
            provider: "Meta",
            description: "Open source",
            maxTokens: 131072,
            supportsStreaming: true
        ),
        // Google
        AIModel(
            id: "google/gemini-2.0-flash-001",
            displayName: "Gemini 2.0 Flash",
            provider: "Google",
            description: "Ultra-fast multimodal",
            maxTokens: 1048576,
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
