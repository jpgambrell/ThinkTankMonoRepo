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
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainView()
                    .environment(conversationStore)
                    .environment(themeManager)
                    .environment(authService)
            } else {
                LoginView()
                    .environment(authService)
            }
        }
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
    }
}

#Preview {
    ContentView()
}
