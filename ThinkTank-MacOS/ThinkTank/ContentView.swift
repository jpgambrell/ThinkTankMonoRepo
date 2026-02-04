//
//  ContentView.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import SwiftUI

struct ContentView: View {
    @State private var authService = CognitoAuthService.shared
    @State private var conversationStore = ConversationStore()
    @State private var themeManager = ThemeManager()
    @State private var subscriptionService = SubscriptionService()
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainView()
                    .environment(conversationStore)
                    .environment(themeManager)
                    .environment(authService)
                    .environment(subscriptionService)
            } else {
                LoginView()
                    .environment(authService)
                    .environment(subscriptionService)
            }
        }
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
        .onChange(of: authService.isAuthenticated) { oldValue, newValue in
            if newValue && !oldValue {
                // User just logged in - load conversations and sync subscription
                Task {
                    await conversationStore.loadConversationsFromCloud()
                    
                    // Sync subscription state based on account type
                    if authService.isGuestAccount {
                        // Guest accounts don't have subscriptions
                        subscriptionService.setGuestMode()
                    } else if let user = authService.currentUser {
                        // Check device subscription entitlements for authenticated users
                        await subscriptionService.login(userId: user.id.uuidString)
                    }
                }
            } else if !newValue && oldValue {
                // User logged out - clear local data and reset subscription state
                conversationStore.conversations = []
                conversationStore.selectedConversationId = nil
                
                Task {
                    await subscriptionService.logout()
                }
            }
        }
        .onChange(of: authService.isGuestAccount) { oldValue, newValue in
            // Handle guest account upgrade - when user upgrades from guest to full account
            if !newValue && oldValue && authService.isAuthenticated {
                // User just upgraded from guest - now check their subscription entitlements
                Task {
                    if let user = authService.currentUser {
                        await subscriptionService.login(userId: user.id.uuidString)
                    }
                }
            }
        }
        .task {
            // Also check on app launch if already authenticated
            if authService.isAuthenticated {
                await conversationStore.loadConversationsFromCloud()
                
                // Sync subscription state based on account type
                if authService.isGuestAccount {
                    subscriptionService.setGuestMode()
                } else if let user = authService.currentUser {
                    await subscriptionService.login(userId: user.id.uuidString)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
