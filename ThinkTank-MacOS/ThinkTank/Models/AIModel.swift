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
    
    /// The asset catalog image name for the provider logo
    var providerIcon: String {
        switch provider.lowercased() {
        case "anthropic":
            return "Anthropic"
        case "deepseek":
            return "DeepSeek"
        case "openai":
            return "OpenAI"
        case "meta":
            return "Meta"
        case "google":
            return "GoogleGemini"
        case "mistral":
            return "Mistral"
        case "cohere":
            return "Cohere"
        case "microsoft":
            return "Microsoft"
        case "perplexity":
            return "Perplexity"
        case "qwen":
            return "Qwen"
        default:
            return "AppReference"
        }
    }
    
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
            id: "anthropic/claude-opus-4.6",
            displayName: "Claude Opus 4.6",
            provider: "Anthropic",
            description: "Strongest for coding & agents",
            maxTokens: 1000000,
            supportsStreaming: true
        ),
        AIModel(
            id: "anthropic/claude-opus-4.5",
            displayName: "Claude Opus 4.5",
            provider: "Anthropic",
            description: "Frontier reasoning model",
            maxTokens: 200000,
            supportsStreaming: true
        ),
        AIModel(
            id: "anthropic/claude-sonnet-4.5",
            displayName: "Claude Sonnet 4.5",
            provider: "Anthropic",
            description: "Fast & intelligent",
            maxTokens: 200000,
            supportsStreaming: true
        ),
        // DeepSeek
        AIModel(
            id: "deepseek/deepseek-v3.2-speciale",
            displayName: "DeepSeek V3.2 Speciale",
            provider: "DeepSeek",
            description: "Max reasoning performance",
            maxTokens: 163840,
            supportsStreaming: true
        ),
        AIModel(
            id: "deepseek/deepseek-v3.2",
            displayName: "DeepSeek V3.2",
            provider: "DeepSeek",
            description: "High efficiency reasoning",
            maxTokens: 163840,
            supportsStreaming: true
        ),
        AIModel(
            id: "deepseek/deepseek-v3.2-exp",
            displayName: "DeepSeek V3.2 Exp",
            provider: "DeepSeek",
            description: "Experimental variant",
            maxTokens: 163840,
            supportsStreaming: true
        ),
        // Google Gemini Family
        AIModel(
            id: "google/gemini-3-flash-preview",
            displayName: "Gemini 3 Flash Preview",
            provider: "Google",
            description: "High speed agentic model",
            maxTokens: 1048576,
            supportsStreaming: true
        ),
        AIModel(
            id: "google/gemini-3-pro-preview",
            displayName: "Gemini 3 Pro Preview",
            provider: "Google",
            description: "Flagship frontier model",
            maxTokens: 1048576,
            supportsStreaming: true
        ),
        AIModel(
            id: "google/gemini-2.5-flash-lite",
            displayName: "Gemini 2.5 Flash Lite",
            provider: "Google",
            description: "Ultra-fast lightweight",
            maxTokens: 1048576,
            supportsStreaming: true
        ),
        AIModel(
            id: "google/gemini-2.5-flash",
            displayName: "Gemini 2.5 Flash",
            provider: "Google",
            description: "Fast multimodal",
            maxTokens: 1048576,
            supportsStreaming: true
        ),
        AIModel(
            id: "google/gemini-2.5-pro",
            displayName: "Gemini 2.5 Pro",
            provider: "Google",
            description: "Advanced reasoning",
            maxTokens: 1048576,
            supportsStreaming: true
        ),
        // OpenAI GPT Family
        AIModel(
            id: "openai/gpt-5.2-codex",
            displayName: "GPT-5.2 Codex",
            provider: "OpenAI",
            description: "Agentic coding model",
            maxTokens: 400000,
            supportsStreaming: true
        ),
        AIModel(
            id: "openai/gpt-5.2-chat",
            displayName: "GPT-5.2 Chat",
            provider: "OpenAI",
            description: "Low-latency chat",
            maxTokens: 128000,
            supportsStreaming: true
        ),
        AIModel(
            id: "openai/gpt-5.2-pro",
            displayName: "GPT-5.2 Pro",
            provider: "OpenAI",
            description: "Most advanced reasoning",
            maxTokens: 400000,
            supportsStreaming: true
        ),
        AIModel(
            id: "openai/gpt-5.2",
            displayName: "GPT-5.2",
            provider: "OpenAI",
            description: "Frontier-grade model",
            maxTokens: 400000,
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
        // Meta Llama Family
        AIModel(
            id: "meta-llama/llama-guard-4-12b",
            displayName: "Llama Guard 4 12B",
            provider: "Meta",
            description: "Safety & moderation",
            maxTokens: 131072,
            supportsStreaming: true
        ),
        AIModel(
            id: "meta-llama/llama-4-maverick",
            displayName: "Llama 4 Maverick",
            provider: "Meta",
            description: "Multimodal flagship",
            maxTokens: 1048576,
            supportsStreaming: true
        ),
        AIModel(
            id: "meta-llama/llama-4-scout",
            displayName: "Llama 4 Scout",
            provider: "Meta",
            description: "Efficient open source",
            maxTokens: 524288,
            supportsStreaming: true
        ),
    ]
    
    static var modelsByProvider: [String: [AIModel]] {
        Dictionary(grouping: availableModels, by: { $0.provider })
    }
    
    // MARK: - Default Model Persistence
    
    private static let defaultModelKey = "ThinkTank.DefaultModelId"
    
    /// The user's preferred default model (persisted to UserDefaults)
    static var defaultModel: AIModel {
        if let savedId = UserDefaults.standard.string(forKey: defaultModelKey),
           let savedModel = model(for: savedId) {
            print("📌 Using saved default model: \(savedId)")
            return savedModel
        }
        print("📌 No saved model, using first available: \(availableModels.first!.id)")
        return availableModels.first!
    }
    
    /// Set the default model for all new conversations
    static func setDefaultModel(_ model: AIModel) {
        UserDefaults.standard.set(model.id, forKey: defaultModelKey)
        UserDefaults.standard.synchronize()
        print("✅ Default model set to: \(model.id)")
    }
    
    /// Set the default model by ID
    static func setDefaultModelId(_ modelId: String) {
        UserDefaults.standard.set(modelId, forKey: defaultModelKey)
        UserDefaults.standard.synchronize()
    }
    
    static func model(for id: String) -> AIModel? {
        availableModels.first { $0.id == id }
    }
}
