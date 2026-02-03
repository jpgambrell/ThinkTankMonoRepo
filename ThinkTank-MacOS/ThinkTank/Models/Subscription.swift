//
//  Subscription.swift
//  ThinkTank
//
//  Created for RevenueCat integration.
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

/// RevenueCat configuration constants
enum RevenueCatConfig {
    static let apiKey = "test_RqquTkEvbTbmkhGVQcOjEboPxoH"
    static let proEntitlementIdentifier = "ThinkTank Pro"
    
    /// Product identifiers configured in RevenueCat
    enum ProductIdentifiers {
        static let monthly = "monthly"
        static let yearly = "yearly"
    }
}
