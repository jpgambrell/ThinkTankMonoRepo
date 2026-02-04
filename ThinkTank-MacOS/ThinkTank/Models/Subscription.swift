//
//  Subscription.swift
//  ThinkTank
//
//  Subscription models for StoreKit 2 integration.
//

import Foundation

/// Represents the user's subscription tier
enum SubscriptionTier: String, Codable, Sendable {
    case free
    case pro
    
    var displayName: String {
        switch self {
        case .free:
            return "Free"
        case .pro:
            return "Pro"
        }
    }
}

/// Represents the current status of a subscription
enum SubscriptionStatus: String, Codable, Sendable {
    case active
    case expired
    case cancelled
    case none
    
    var displayName: String {
        switch self {
        case .active:
            return "Active"
        case .expired:
            return "Expired"
        case .cancelled:
            return "Cancelled"
        case .none:
            return "None"
        }
    }
}

/// StoreKit configuration constants
enum StoreKitConfig {
    /// Product identifiers matching your App Store Connect / StoreKit configuration
    enum ProductIdentifiers {
        static let monthly = "Monthly"
        static let yearly = "yearly"
        
        /// All subscription product IDs
        static let allSubscriptions: [String] = [monthly, yearly]
    }
    
    /// Subscription group identifier
    static let subscriptionGroupID = "973D1FB6"
}
