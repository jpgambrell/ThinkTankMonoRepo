//
//  SubscriptionPaywallView.swift
//  ThinkTank
//
//  Created for RevenueCat integration.
//

import SwiftUI
import RevenueCat
import RevenueCatUI

/// A view that presents subscription options to the user
struct SubscriptionPaywallView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(SubscriptionService.self) private var subscriptionService
    
    @Binding var isPresented: Bool
    
    /// Callback when purchase completes successfully
    var onPurchaseCompleted: (() -> Void)?
    
    /// Whether to show the skip button (for optional paywall presentation)
    var showSkipButton: Bool = true
    
    @State private var selectedPackage: Package?
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
                    VStack(spacing: 24) {
                        // Hero section
                        heroSection
                        
                        // Features list
                        featuresSection
                        
                        // Pricing cards
                        pricingSection
                        
                        // Purchase button
                        purchaseButton
                        
                        // Restore purchases
                        restoreButton
                        
                        // Terms
                        termsSection
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 32)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 700)
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .task {
            // Fetch offerings if not already loaded
            if subscriptionService.offerings == nil {
                await subscriptionService.fetchOfferings()
            }
            
            // Default selection to yearly (better value)
            if selectedPackage == nil {
                selectedPackage = subscriptionService.yearlyPackage ?? subscriptionService.monthlyPackage
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
        VStack(spacing: 16) {
            // App icon or logo
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(Color.brandPrimary)
            
            Text("Upgrade to ThinkTank Pro")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(ThemeColors.primaryText(colorScheme))
            
            Text("Unlock unlimited AI conversations and premium features")
                .font(.system(size: 16))
                .foregroundStyle(ThemeColors.secondaryText(colorScheme))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FeatureRow(icon: "infinity", text: "Unlimited messages")
            FeatureRow(icon: "cpu", text: "Access to all AI models")
            FeatureRow(icon: "icloud", text: "Cloud sync across devices")
            FeatureRow(icon: "bolt.fill", text: "Priority response times")
            FeatureRow(icon: "sparkles", text: "Early access to new features")
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ThemeColors.cardBackground(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ThemeColors.border(colorScheme), lineWidth: 1)
        )
    }
    
    // MARK: - Pricing Section
    
    private var pricingSection: some View {
        HStack(spacing: 16) {
            if let monthly = subscriptionService.monthlyPackage {
                PricingCard(
                    package: monthly,
                    title: "Monthly",
                    isSelected: selectedPackage?.identifier == monthly.identifier,
                    colorScheme: colorScheme
                ) {
                    selectedPackage = monthly
                }
            }
            
            if let yearly = subscriptionService.yearlyPackage {
                PricingCard(
                    package: yearly,
                    title: "Yearly",
                    badge: calculateSavingsBadge(monthly: subscriptionService.monthlyPackage, yearly: yearly),
                    isSelected: selectedPackage?.identifier == yearly.identifier,
                    colorScheme: colorScheme
                ) {
                    selectedPackage = yearly
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
                    Text(purchaseButtonTitle)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brandPrimary)
        )
        .disabled(selectedPackage == nil || subscriptionService.purchaseInProgress)
        .opacity(selectedPackage == nil ? 0.5 : 1.0)
    }
    
    private var purchaseButtonTitle: String {
        guard let package = selectedPackage else {
            return "Select a plan"
        }
        return "Subscribe for \(package.storeProduct.localizedPriceString)"
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
        VStack(spacing: 8) {
            Text("Recurring billing. Cancel anytime.")
                .font(.system(size: 12))
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
            .font(.system(size: 12))
            .foregroundStyle(ThemeColors.secondaryText(colorScheme))
        }
        .padding(.top, 8)
    }
    
    // MARK: - Actions
    
    private func handlePurchase() {
        guard let package = selectedPackage else { return }
        
        Task {
            do {
                try await subscriptionService.purchase(package: package)
                // Give a moment for subscription state to update
                try? await Task.sleep(for: .milliseconds(500))
                onPurchaseCompleted?()
                isPresented = false
            } catch SubscriptionError.userCancelled {
                // User cancelled, do nothing
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
    private func calculateSavingsBadge(monthly: Package?, yearly: Package) -> String? {
        guard let monthly = monthly else { return nil }
        
        let monthlyPrice = monthly.storeProduct.price as Decimal
        let yearlyPrice = yearly.storeProduct.price as Decimal
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
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Pricing Card

private struct PricingCard: View {
    let package: Package
    let title: String
    var badge: String? = nil
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.brandPrimary)
                        .clipShape(.capsule)
                } else {
                    Color.clear
                        .frame(height: 20)
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ThemeColors.primaryText(colorScheme))
                
                Text(package.storeProduct.localizedPriceString)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(ThemeColors.primaryText(colorScheme))
                
                Text(priceDescription)
                    .font(.system(size: 12))
                    .foregroundStyle(ThemeColors.secondaryText(colorScheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.brandPrimaryLight.opacity(0.3) : ThemeColors.cardBackground(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.brandPrimary : ThemeColors.border(colorScheme), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var priceDescription: String {
        switch package.packageType {
        case .monthly:
            return "per month"
        case .annual:
            return "per year"
        default:
            return ""
        }
    }
}

// MARK: - Preview

#Preview {
    SubscriptionPaywallView(isPresented: .constant(true))
        .environment(SubscriptionService())
        .frame(width: 600, height: 800)
}
