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
                    
                    // Login to RevenueCat with user ID
                    if let user = authService.currentUser {
                        await subscriptionService.login(userId: user.id.uuidString)
                    }
                }
            } else if !newValue && oldValue {
                // User logged out - clear local data and logout from RevenueCat
                conversationStore.conversations = []
                conversationStore.selectedConversationId = nil
                
                Task {
                    await subscriptionService.logout()
                }
            }
        }
        .task {
            // Also check on app launch if already authenticated
            if authService.isAuthenticated {
                await conversationStore.loadConversationsFromCloud()
                
                // Sync subscription state
                if let user = authService.currentUser {
                    await subscriptionService.login(userId: user.id.uuidString)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
