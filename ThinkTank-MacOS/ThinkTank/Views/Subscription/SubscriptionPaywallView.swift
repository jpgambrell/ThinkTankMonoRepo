//
//  SubscriptionPaywallView.swift
//  ThinkTank
//
//  Subscription paywall using native StoreKit 2.
//

import SwiftUI
import StoreKit

/// A view that presents subscription options to the user
struct SubscriptionPaywallView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(SubscriptionService.self) private var subscriptionService
    
    @Binding var isPresented: Bool
    
    /// Whether the current user is a guest account
    var isGuestAccount: Bool = false
    
    /// Callback when purchase completes successfully
    var onPurchaseCompleted: (() -> Void)?
    
    /// Callback when guest needs to create account first
    var onCreateAccountRequired: (() -> Void)?
    
    /// Whether to show the skip button (for optional paywall presentation)
    var showSkipButton: Bool = true
    
    @State private var selectedProduct: Product?
    @State private var errorMessage: String?
    @State private var showError: Bool = false
    
    var body: some View {
        ZStack {
            // Background
            ThemeColors.windowBackground(colorScheme)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Hero section
                        heroSection
                        
                        // Account Required Banner (for guests)
                        if isGuestAccount {
                            accountRequiredBanner
                        }
                        
                        // Features list
                        featuresSection
                        
                        // Pricing cards
                        pricingSection
                        
                        // Purchase button
                        purchaseButton
                        
                        // Restore purchases (only for non-guests)
                        if !isGuestAccount {
                            restoreButton
                        }
                        
                        // Terms
                        termsSection
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .task {
            // Load products if not already loaded
            if subscriptionService.products.isEmpty {
                await subscriptionService.loadProducts()
            }
            
            // Default selection to yearly (better value)
            if selectedProduct == nil {
                selectedProduct = subscriptionService.yearlyProduct ?? subscriptionService.monthlyProduct
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            if showSkipButton {
                Button(action: { isPresented = false }) {
                    Text("Skip")
                        .font(.system(size: 14))
                        .foregroundStyle(ThemeColors.secondaryText(colorScheme))
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ThemeColors.secondaryText(colorScheme))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        VStack(spacing: 8) {
            // App icon or logo
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(Color.brandPrimary)
            
            Text("Upgrade to ThinkTank Pro")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(ThemeColors.primaryText(colorScheme))
            
            Text("Unlock unlimited AI conversations and premium features")
                .font(.system(size: 14))
                .foregroundStyle(ThemeColors.secondaryText(colorScheme))
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Account Required Banner
    
    private var accountRequiredBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 1) {
                Text("Account Required")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ThemeColors.primaryText(colorScheme))
                
                Text("Create an account to subscribe. This ensures you can always access your subscription.")
                    .font(.system(size: 11))
                    .foregroundStyle(ThemeColors.secondaryText(colorScheme))
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FeatureRow(icon: "infinity", text: "Unlimited messages")
            FeatureRow(icon: "cpu", text: "Access to all AI models")
            FeatureRow(icon: "icloud", text: "Cloud sync across devices")
            FeatureRow(icon: "bolt.fill", text: "Priority response times")
            FeatureRow(icon: "sparkles", text: "Early access to new features")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ThemeColors.cardBackground(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ThemeColors.border(colorScheme), lineWidth: 1)
        )
    }
    
    // MARK: - Pricing Section
    
    private var pricingSection: some View {
        HStack(spacing: 16) {
            if let monthly = subscriptionService.monthlyProduct {
                PricingCard(
                    product: monthly,
                    title: "Monthly",
                    isSelected: selectedProduct?.id == monthly.id,
                    colorScheme: colorScheme
                ) {
                    selectedProduct = monthly
                }
            }
            
            if let yearly = subscriptionService.yearlyProduct {
                PricingCard(
                    product: yearly,
                    title: "Yearly",
                    badge: calculateSavingsBadge(monthly: subscriptionService.monthlyProduct, yearly: yearly),
                    isSelected: selectedProduct?.id == yearly.id,
                    colorScheme: colorScheme
                ) {
                    selectedProduct = yearly
                }
            }
        }
    }
    
    // MARK: - Purchase Button
    
    private var purchaseButton: some View {
        Button(action: handlePurchase) {
            Group {
                if subscriptionService.purchaseInProgress {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    HStack(spacing: 8) {
                        if isGuestAccount {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 14))
                        }
                        Text(purchaseButtonTitle)
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.brandPrimary)
        )
        .disabled(selectedProduct == nil || subscriptionService.purchaseInProgress)
        .opacity(selectedProduct == nil ? 0.5 : 1.0)
    }
    
    private var purchaseButtonTitle: String {
        guard selectedProduct != nil else {
            return "Select a plan"
        }
        
        if isGuestAccount {
            return "Create Account & Subscribe"
        }
        
        guard let product = selectedProduct else {
            return "Select a plan"
        }
        return "Subscribe for \(product.displayPrice)"
    }
    
    // MARK: - Restore Button
    
    private var restoreButton: some View {
        Button(action: handleRestore) {
            Text("Restore Purchases")
                .font(.system(size: 14))
                .foregroundStyle(Color.brandPrimary)
        }
        .buttonStyle(.plain)
        .disabled(subscriptionService.purchaseInProgress)
    }
    
    // MARK: - Terms Section
    
    private var termsSection: some View {
        VStack(spacing: 4) {
            Text("Recurring billing. Cancel anytime.")
                .font(.system(size: 11))
                .foregroundStyle(ThemeColors.tertiaryText(colorScheme))
            
            HStack(spacing: 16) {
                Button("Terms of Service") {
                    // Open terms URL
                }
                .buttonStyle(.plain)
                
                Button("Privacy Policy") {
                    // Open privacy URL
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 11))
            .foregroundStyle(ThemeColors.secondaryText(colorScheme))
        }
    }
    
    // MARK: - Actions
    
    private func handlePurchase() {
        // If guest, need to create account first
        if isGuestAccount {
            isPresented = false
            onCreateAccountRequired?()
            return
        }
        
        guard let product = selectedProduct else { return }
        
        Task {
            do {
                try await subscriptionService.purchase(product: product)
                // Give a moment for subscription state to update
                try? await Task.sleep(for: .milliseconds(500))
                onPurchaseCompleted?()
                isPresented = false
            } catch SubscriptionError.userCancelled {
                // User cancelled, do nothing
            } catch SubscriptionError.pending {
                // Purchase is pending approval
                errorMessage = "Your purchase is pending approval."
                showError = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func handleRestore() {
        Task {
            do {
                try await subscriptionService.restorePurchases()
                if subscriptionService.isProUser {
                    onPurchaseCompleted?()
                    isPresented = false
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    /// Calculate savings badge for yearly vs monthly
    private func calculateSavingsBadge(monthly: Product?, yearly: Product) -> String? {
        guard let monthly = monthly else { return nil }
        
        let monthlyPrice = monthly.price
        let yearlyPrice = yearly.price
        let annualMonthlyPrice = monthlyPrice * 12
        
        guard annualMonthlyPrice > yearlyPrice else { return nil }
        
        let savings = ((annualMonthlyPrice - yearlyPrice) / annualMonthlyPrice) * 100
        let savingsDouble = NSDecimalNumber(decimal: savings).doubleValue
        let savingsInt = Int(savingsDouble.rounded())
        
        return "Save \(savingsInt)%"
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Pricing Card

private struct PricingCard: View {
    let product: Product
    let title: String
    var badge: String? = nil
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.brandPrimary)
                        .clipShape(.capsule)
                } else {
                    Color.clear
                        .frame(height: 16)
                }
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ThemeColors.primaryText(colorScheme))
                
                Text(product.displayPrice)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(ThemeColors.primaryText(colorScheme))
                
                Text(priceDescription)
                    .font(.system(size: 11))
                    .foregroundStyle(ThemeColors.secondaryText(colorScheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.brandPrimaryLight.opacity(0.3) : ThemeColors.cardBackground(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.brandPrimary : ThemeColors.border(colorScheme), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var priceDescription: String {
        guard let subscription = product.subscription else { return "" }
        
        switch subscription.subscriptionPeriod.unit {
        case .month:
            return "per month"
        case .year:
            return "per year"
        case .week:
            return "per week"
        case .day:
            return "per day"
        @unknown default:
            return ""
        }
    }
}

// MARK: - Preview

#Preview {
    SubscriptionPaywallView(isPresented: .constant(true), isGuestAccount: true)
        .environment(SubscriptionService())
        .frame(width: 600, height: 800)
}
