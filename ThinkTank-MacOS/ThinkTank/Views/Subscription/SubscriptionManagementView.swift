//
//  SubscriptionManagementView.swift
//  ThinkTank
//
//  Created for RevenueCat integration.
//

import SwiftUI
import RevenueCat
import RevenueCatUI

/// A view for managing the user's subscription (Customer Center)
struct SubscriptionManagementView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(SubscriptionService.self) private var subscriptionService
    
    @Binding var isPresented: Bool
    
    @State private var showingCancelConfirmation: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false
    
    var body: some View {
        ZStack {
            ThemeColors.windowBackground(colorScheme)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                
                Divider()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Current subscription status
                        subscriptionStatusSection
                        
                        // Subscription details
                        if subscriptionService.isProUser {
                            subscriptionDetailsSection
                        }
                        
                        // Actions
                        actionsSection
                        
                        // Help section
                        helpSection
                    }
                    .padding(32)
                }
            }
        }
        .frame(minWidth: 450, minHeight: 500)
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .confirmationDialog(
            "Cancel Subscription",
            isPresented: $showingCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("Cancel Subscription", role: .destructive) {
                openSubscriptionManagement()
            }
            Button("Keep Subscription", role: .cancel) { }
        } message: {
            Text("You'll still have access until your current billing period ends. To cancel, you'll be taken to the App Store subscription settings.")
        }
        .task {
            await subscriptionService.refreshCustomerInfo()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Button(action: { isPresented = false }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                    Text("Back")
                        .font(.system(size: 14))
                }
                .foregroundStyle(ThemeColors.secondaryText(colorScheme))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text("Manage Subscription")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ThemeColors.primaryText(colorScheme))
            
            Spacer()
            
            // Balance the back button
            Color.clear
                .frame(width: 60)
        }
        .padding(.horizontal, 24)
        .frame(height: 56)
        .background(ThemeColors.cardBackground(colorScheme))
    }
    
    // MARK: - Subscription Status Section
    
    private var subscriptionStatusSection: some View {
        VStack(spacing: 16) {
            // Status badge
            HStack(spacing: 12) {
                Image(systemName: subscriptionService.isProUser ? "checkmark.seal.fill" : "person.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(subscriptionService.isProUser ? Color.brandPrimary : ThemeColors.secondaryText(colorScheme))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(subscriptionService.subscriptionTier.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(ThemeColors.primaryText(colorScheme))
                    
                    Text(subscriptionService.subscriptionStatusText)
                        .font(.system(size: 14))
                        .foregroundStyle(statusColor)
                }
                
                Spacer()
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
    }
    
    private var statusColor: Color {
        switch subscriptionService.subscriptionStatus {
        case .active:
            return Color.brandPrimary
        case .cancelled:
            return .orange
        case .expired:
            return .red
        case .none:
            return ThemeColors.secondaryText(colorScheme)
        }
    }
    
    // MARK: - Subscription Details Section
    
    private var subscriptionDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SUBSCRIPTION DETAILS")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ThemeColors.tertiaryText(colorScheme))
                .tracking(0.5)
            
            VStack(spacing: 0) {
                if let expirationDate = subscriptionService.formattedExpirationDate {
                    DetailRow(
                        title: subscriptionService.willRenew ? "Next billing date" : "Expires",
                        value: expirationDate
                    )
                    
                    Divider()
                        .padding(.horizontal, 16)
                }
                
                DetailRow(
                    title: "Status",
                    value: subscriptionService.subscriptionStatus.displayName
                )
                
                if subscriptionService.willRenew {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    DetailRow(
                        title: "Auto-renew",
                        value: "Enabled"
                    )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ThemeColors.inputBackground(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ThemeColors.border(colorScheme), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            if subscriptionService.isProUser {
                // Manage subscription button
                Button(action: openSubscriptionManagement) {
                    HStack {
                        Text("Manage in App Store")
                            .font(.system(size: 14, weight: .medium))
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Color.brandPrimary)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.brandPrimary, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                // Cancel subscription
                if subscriptionService.willRenew {
                    Button(action: { showingCancelConfirmation = true }) {
                        Text("Cancel Subscription")
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            } else {
                // Restore purchases
                Button(action: handleRestore) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .controlSize(.small)
                        } else {
                            Text("Restore Purchases")
                                .font(.system(size: 14, weight: .medium))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Color.brandPrimary)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.brandPrimary, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }
        }
    }
    
    // MARK: - Help Section
    
    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HELP")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ThemeColors.tertiaryText(colorScheme))
                .tracking(0.5)
            
            VStack(spacing: 0) {
                HelpRow(title: "Contact Support", icon: "envelope")
                
                Divider()
                    .padding(.horizontal, 16)
                
                HelpRow(title: "FAQ", icon: "questionmark.circle")
                
                Divider()
                    .padding(.horizontal, 16)
                
                HelpRow(title: "Terms of Service", icon: "doc.text")
                
                Divider()
                    .padding(.horizontal, 16)
                
                HelpRow(title: "Privacy Policy", icon: "hand.raised")
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ThemeColors.inputBackground(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ThemeColors.border(colorScheme), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Actions
    
    private func openSubscriptionManagement() {
        // Open App Store subscription management
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func handleRestore() {
        isLoading = true
        
        Task {
            do {
                try await subscriptionService.restorePurchases()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(ThemeColors.secondaryText(colorScheme))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(ThemeColors.primaryText(colorScheme))
        }
        .padding(16)
    }
}

// MARK: - Help Row

private struct HelpRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered: Bool = false
    
    let title: String
    let icon: String
    
    var body: some View {
        Button(action: {}) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(ThemeColors.secondaryText(colorScheme))
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(ThemeColors.primaryText(colorScheme))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(ThemeColors.tertiaryText(colorScheme))
            }
            .padding(16)
            .background(isHovered ? ThemeColors.hoverBackground(colorScheme) : .clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Preview

#Preview {
    SubscriptionManagementView(isPresented: .constant(true))
        .environment(SubscriptionService())
        .frame(width: 500, height: 600)
}
