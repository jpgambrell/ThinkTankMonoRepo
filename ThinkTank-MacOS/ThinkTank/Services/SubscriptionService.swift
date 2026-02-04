//
//  SubscriptionService.swift
//  ThinkTank
//
//  StoreKit 2 subscription management service.
//

import Foundation
import StoreKit
import Observation

/// Error types for subscription operations
enum SubscriptionError: LocalizedError {
    case purchaseFailed(String)
    case restoreFailed(String)
    case productsNotAvailable
    case userCancelled
    case networkError
    case verificationFailed
    case pending
    
    var errorDescription: String? {
        switch self {
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        case .restoreFailed(let message):
            return "Restore failed: \(message)"
        case .productsNotAvailable:
            return "Subscription plans are not available at this time"
        case .userCancelled:
            return "Purchase was cancelled"
        case .networkError:
            return "Network error. Please check your connection and try again."
        case .verificationFailed:
            return "Transaction verification failed"
        case .pending:
            return "Purchase is pending approval"
        }
    }
}

/// Service to manage StoreKit 2 subscriptions
@Observable
@MainActor
final class SubscriptionService {
    // MARK: - Published State
    
    /// Whether the user has an active subscription
    var isProUser: Bool = false
    
    /// Current subscription tier
    var subscriptionTier: SubscriptionTier = .free
    
    /// Current subscription status
    var subscriptionStatus: SubscriptionStatus = .none
    
    /// Available subscription products from StoreKit
    var products: [Product] = []
    
    /// Monthly subscription product
    var monthlyProduct: Product? {
        products.first { $0.id == StoreKitConfig.ProductIdentifiers.monthly }
    }
    
    /// Yearly subscription product
    var yearlyProduct: Product? {
        products.first { $0.id == StoreKitConfig.ProductIdentifiers.yearly }
    }
    
    /// Whether a purchase is currently in progress
    var purchaseInProgress: Bool = false
    
    /// Whether products are being loaded
    var isLoadingProducts: Bool = false
    
    /// Last error that occurred
    var errorMessage: String?
    
    // MARK: - Private State
    
    /// Track previous Pro status to detect when user first becomes Pro
    @ObservationIgnored private var wasProUser: Bool = false
    
    /// Current subscription info
    private var currentSubscription: Product.SubscriptionInfo.Status?
    
    /// Subscription expiration date (if subscribed)
    var expirationDate: Date? {
        guard let transaction = currentSubscription?.transaction,
              case .verified(let tx) = transaction else {
            return nil
        }
        return tx.expirationDate
    }
    
    /// Whether subscription will renew
    var willRenew: Bool {
        guard let renewalInfo = currentSubscription?.renewalInfo,
              case .verified(let info) = renewalInfo else {
            return false
        }
        return info.willAutoRenew
    }
    
    // MARK: - Private Properties
    
    /// Task for listening to transaction updates - stored to keep alive, uses weak self so no cancel needed
    @ObservationIgnored private var transactionListenerTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init() {
        // Start listening for transactions
        setupTransactionListener()
        
        // Load products and check entitlements on init
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }
    
    // MARK: - Product Loading
    
    /// Load available subscription products from the App Store
    func loadProducts() async {
        guard !isLoadingProducts else { return }
        
        isLoadingProducts = true
        errorMessage = nil
        
        do {
            let productIDs = StoreKitConfig.ProductIdentifiers.allSubscriptions
            let storeProducts = try await Product.products(for: productIDs)
            
            // Sort products: monthly first, then yearly
            products = storeProducts.sorted { p1, p2 in
                if p1.id == StoreKitConfig.ProductIdentifiers.monthly { return true }
                if p2.id == StoreKitConfig.ProductIdentifiers.monthly { return false }
                return p1.id < p2.id
            }
            
            print("✅ Loaded \(products.count) products:")
            for product in products {
                print("   - \(product.id): \(product.displayPrice)")
            }
        } catch {
            print("❌ Failed to load products: \(error)")
            errorMessage = error.localizedDescription
        }
        
        isLoadingProducts = false
    }
    
    // MARK: - Purchases
    
    /// Purchase a product
    func purchase(product: Product) async throws {
        guard !purchaseInProgress else { return }
        
        purchaseInProgress = true
        errorMessage = nil
        
        defer {
            purchaseInProgress = false
        }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Check verification
                switch verification {
                case .verified(let transaction):
                    // Transaction is verified, finish it
                    await transaction.finish()
                    await checkSubscriptionStatus()
                    print("✅ Purchase successful: \(product.id)")
                    
                case .unverified(_, let error):
                    print("❌ Transaction verification failed: \(error)")
                    throw SubscriptionError.verificationFailed
                }
                
            case .userCancelled:
                throw SubscriptionError.userCancelled
                
            case .pending:
                // Transaction is pending (e.g., parental approval)
                print("⏳ Purchase pending approval")
                throw SubscriptionError.pending
                
            @unknown default:
                throw SubscriptionError.purchaseFailed("Unknown result")
            }
        } catch let error as SubscriptionError {
            throw error
        } catch {
            print("❌ Purchase failed: \(error)")
            errorMessage = error.localizedDescription
            throw SubscriptionError.purchaseFailed(error.localizedDescription)
        }
    }
    
    /// Restore previous purchases
    func restorePurchases() async throws {
        guard !purchaseInProgress else { return }
        
        purchaseInProgress = true
        errorMessage = nil
        
        defer {
            purchaseInProgress = false
        }
        
        do {
            // Sync with App Store
            try await AppStore.sync()
            
            // Check subscription status after sync
            await checkSubscriptionStatus()
            
            print("✅ Purchases synced")
            
            if !isProUser {
                throw SubscriptionError.restoreFailed("No active subscriptions found")
            }
        } catch let error as SubscriptionError {
            throw error
        } catch {
            print("❌ Restore failed: \(error)")
            errorMessage = error.localizedDescription
            throw SubscriptionError.restoreFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Subscription Status
    
    /// Check current subscription status
    func checkSubscriptionStatus() async {
        // Check for active subscription entitlements
        var hasActiveSubscription = false
        var latestStatus: Product.SubscriptionInfo.Status?
        
        // Iterate through all subscription statuses
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                // Check if this is one of our subscription products
                if StoreKitConfig.ProductIdentifiers.allSubscriptions.contains(transaction.productID) {
                    hasActiveSubscription = true
                    
                    // Get the subscription status for more details
                    if let product = products.first(where: { $0.id == transaction.productID }),
                       let subscription = product.subscription {
                        do {
                            let statuses = try await subscription.status
                            for status in statuses {
                                if case .verified(_) = status.transaction {
                                    latestStatus = status
                                    break
                                }
                            }
                        } catch {
                            print("⚠️ Could not get subscription status: \(error)")
                        }
                    }
                    break
                }
            }
        }
        
        currentSubscription = latestStatus
        updateSubscriptionState(isActive: hasActiveSubscription, status: latestStatus)
    }
    
    /// Refresh subscription status
    func refreshCustomerInfo() async {
        await checkSubscriptionStatus()
    }
    
    // MARK: - User Management (for Cognito integration)
    
    /// Called after user logs in - refresh subscription status
    func login(userId: String) async {
        print("✅ StoreKit user context set for: \(userId)")
        await loadProducts()
        await checkSubscriptionStatus()
    }
    
    /// Called when user logs out - resets subscription state
    /// Subscriptions are tied to user accounts, not devices
    func logout() async {
        print("✅ StoreKit user logged out - resetting subscription state")
        resetState()
    }
    
    /// Called when a guest account is created - ensures free tier
    func setGuestMode() {
        print("✅ Guest mode - setting free tier")
        resetState()
    }
    
    // MARK: - Private Methods
    
    private func setupTransactionListener() {
        transactionListenerTask = Task.detached { [weak self] in
            // Listen for transaction updates
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.checkSubscriptionStatus()
                    print("📥 Transaction updated: \(transaction.productID)")
                }
            }
        }
    }
    
    private func updateSubscriptionState(isActive: Bool, status: Product.SubscriptionInfo.Status?) {
        let newIsProUser = isActive
        
        // Check if user just became Pro (transition from free to pro)
        if newIsProUser && !wasProUser {
            // User just subscribed to Pro - reset their message count
            CognitoAuthService.shared.resetMessageCount()
            print("✅ User became Pro - message count reset")
        }
        
        isProUser = newIsProUser
        wasProUser = newIsProUser
        
        if isProUser {
            subscriptionTier = .pro
            
            if let status = status {
                // Check renewal info - it's a VerificationResult, not Optional
                switch status.renewalInfo {
                case .verified(let info):
                    if info.willAutoRenew {
                        subscriptionStatus = .active
                    } else {
                        // Active but won't renew (cancelled but still within period)
                        subscriptionStatus = .cancelled
                    }
                case .unverified(_, _):
                    subscriptionStatus = .active
                }
            } else {
                subscriptionStatus = .active
            }
        } else {
            subscriptionTier = .free
            subscriptionStatus = .none
        }
        
        print("📊 Subscription state: tier=\(subscriptionTier), status=\(subscriptionStatus), isPro=\(isProUser)")
    }
    
    private func resetState() {
        isProUser = false
        subscriptionTier = .free
        subscriptionStatus = .none
        currentSubscription = nil
        errorMessage = nil
    }
}

// MARK: - Formatting Helpers

extension SubscriptionService {
    /// Format expiration date for display
    var formattedExpirationDate: String? {
        guard let date = expirationDate else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        return formatter.string(from: date)
    }
    
    /// Get renewal/expiration status text
    var subscriptionStatusText: String {
        switch subscriptionStatus {
        case .active:
            if let date = formattedExpirationDate {
                return willRenew ? "Renews \(date)" : "Expires \(date)"
            }
            return "Active"
        case .expired:
            return "Expired"
        case .cancelled:
            if let date = formattedExpirationDate {
                return "Cancelled - expires \(date)"
            }
            return "Cancelled"
        case .none:
            return "Not subscribed"
        }
    }
}
