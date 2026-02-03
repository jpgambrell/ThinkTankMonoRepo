//
//  SubscriptionService.swift
//  ThinkTank
//
//  Created for RevenueCat integration.
//

import Foundation
import RevenueCat
import Observation

/// Error types for subscription operations
enum SubscriptionError: LocalizedError {
    case purchaseFailed(String)
    case restoreFailed(String)
    case offeringsNotAvailable
    case userCancelled
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        case .restoreFailed(let message):
            return "Restore failed: \(message)"
        case .offeringsNotAvailable:
            return "Subscription plans are not available at this time"
        case .userCancelled:
            return "Purchase was cancelled"
        case .networkError:
            return "Network error. Please check your connection and try again."
        }
    }
}

/// Service to manage RevenueCat subscriptions
@Observable
@MainActor
final class SubscriptionService {
    // MARK: - Published State
    
    /// Whether the user has an active "ThinkTank Pro" entitlement
    var isProUser: Bool = false
    
    /// Current subscription tier
    var subscriptionTier: SubscriptionTier = .free
    
    /// Current subscription status
    var subscriptionStatus: SubscriptionStatus = .none
    
    /// Customer info from RevenueCat
    var customerInfo: CustomerInfo?
    
    /// Available offerings from RevenueCat
    var offerings: Offerings?
    
    /// Current offering (default)
    var currentOffering: Offering? {
        offerings?.current
    }
    
    /// Monthly package from current offering
    var monthlyPackage: Package? {
        currentOffering?.package(identifier: RevenueCatConfig.ProductIdentifiers.monthly)
            ?? currentOffering?.monthly
    }
    
    /// Yearly package from current offering
    var yearlyPackage: Package? {
        currentOffering?.package(identifier: RevenueCatConfig.ProductIdentifiers.yearly)
            ?? currentOffering?.annual
    }
    
    /// Whether a purchase is currently in progress
    var purchaseInProgress: Bool = false
    
    /// Whether offerings are being loaded
    var isLoadingOfferings: Bool = false
    
    /// Last error that occurred
    var errorMessage: String?
    
    // MARK: - Private State
    
    /// Track previous Pro status to detect when user first becomes Pro
    @ObservationIgnored private var wasProUser: Bool = false
    
    /// Subscription expiration date (if subscribed)
    var expirationDate: Date? {
        customerInfo?.entitlements[RevenueCatConfig.proEntitlementIdentifier]?.expirationDate
    }
    
    /// Whether subscription will renew
    var willRenew: Bool {
        customerInfo?.entitlements[RevenueCatConfig.proEntitlementIdentifier]?.willRenew ?? false
    }
    
    // MARK: - Private Properties
    
    /// Task for listening to customer info updates - stored to keep the stream alive
    /// Uses weak self, so no explicit cancellation needed in deinit
    private var customerInfoTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init() {
        // RevenueCat is configured in ThinkTankApp
        // Listen for customer info updates
        setupCustomerInfoListener()
    }
    
    // MARK: - Configuration
    
    /// Configure RevenueCat SDK (call from App init)
    static func configure() {
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif
        
        Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
        print("✅ RevenueCat configured with API key")
    }
    
    // MARK: - User Management
    
    /// Login user to RevenueCat (call after Cognito auth)
    func login(userId: String) async {
        do {
            let (customerInfo, _) = try await Purchases.shared.logIn(userId)
            self.customerInfo = customerInfo
            updateSubscriptionState(from: customerInfo)
            print("✅ RevenueCat user logged in: \(userId)")
            
            // Fetch offerings after login
            await fetchOfferings()
        } catch {
            print("❌ RevenueCat login failed: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    /// Logout user from RevenueCat (call on sign out)
    func logout() async {
        do {
            let customerInfo = try await Purchases.shared.logOut()
            self.customerInfo = customerInfo
            updateSubscriptionState(from: customerInfo)
            print("✅ RevenueCat user logged out")
        } catch {
            print("❌ RevenueCat logout failed: \(error)")
            // Reset state anyway
            resetState()
        }
    }
    
    // MARK: - Offerings
    
    /// Fetch available offerings from RevenueCat
    func fetchOfferings() async {
        guard !isLoadingOfferings else { return }
        
        isLoadingOfferings = true
        errorMessage = nil
        
        do {
            let offerings = try await Purchases.shared.offerings()
            self.offerings = offerings
            
            if let current = offerings.current {
                print("✅ Loaded offerings: \(current.identifier)")
                print("   Monthly: \(monthlyPackage?.storeProduct.localizedPriceString ?? "N/A")")
                print("   Yearly: \(yearlyPackage?.storeProduct.localizedPriceString ?? "N/A")")
            } else {
                print("⚠️ No current offering available")
            }
        } catch {
            print("❌ Failed to fetch offerings: \(error)")
            errorMessage = error.localizedDescription
        }
        
        isLoadingOfferings = false
    }
    
    // MARK: - Purchases
    
    /// Purchase a package
    func purchase(package: Package) async throws {
        guard !purchaseInProgress else { return }
        
        purchaseInProgress = true
        errorMessage = nil
        
        defer {
            purchaseInProgress = false
        }
        
        do {
            let result = try await Purchases.shared.purchase(package: package)
            
            if !result.userCancelled {
                customerInfo = result.customerInfo
                updateSubscriptionState(from: result.customerInfo)
                print("✅ Purchase successful: \(package.identifier)")
            } else {
                throw SubscriptionError.userCancelled
            }
        } catch let error as SubscriptionError {
            throw error
        } catch {
            let nsError = error as NSError
            
            // Check for user cancellation
            if nsError.domain == "RevenueCat.ErrorCode" && nsError.code == 1 {
                throw SubscriptionError.userCancelled
            }
            
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
            let customerInfo = try await Purchases.shared.restorePurchases()
            self.customerInfo = customerInfo
            updateSubscriptionState(from: customerInfo)
            print("✅ Purchases restored")
            
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
    
    // MARK: - Entitlement Checking
    
    /// Check if user has Pro entitlement
    func checkProEntitlement() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            self.customerInfo = customerInfo
            updateSubscriptionState(from: customerInfo)
        } catch {
            print("❌ Failed to check entitlement: \(error)")
        }
    }
    
    /// Refresh customer info
    func refreshCustomerInfo() async {
        await checkProEntitlement()
    }
    
    // MARK: - Private Methods
    
    private func setupCustomerInfoListener() {
        // Create a detached task to listen for customer info updates
        customerInfoTask = Task.detached { [weak self] in
            for await customerInfo in Purchases.shared.customerInfoStream {
                await self?.handleCustomerInfoUpdate(customerInfo)
            }
        }
    }
    
    private func handleCustomerInfoUpdate(_ customerInfo: CustomerInfo) {
        self.customerInfo = customerInfo
        updateSubscriptionState(from: customerInfo)
        print("📥 Customer info updated")
    }
    
    private func updateSubscriptionState(from customerInfo: CustomerInfo) {
        let proEntitlement = customerInfo.entitlements[RevenueCatConfig.proEntitlementIdentifier]
        
        let newIsProUser = proEntitlement?.isActive ?? false
        
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
            
            if let entitlement = proEntitlement {
                if entitlement.willRenew {
                    subscriptionStatus = .active
                } else if entitlement.isActive {
                    // Active but won't renew (cancelled but still within period)
                    subscriptionStatus = .cancelled
                } else {
                    subscriptionStatus = .expired
                }
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
        customerInfo = nil
        offerings = nil
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
