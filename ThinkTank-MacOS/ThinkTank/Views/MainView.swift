//
//  MainView.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import SwiftUI

struct MainView: View {
    @Environment(ConversationStore.self) private var conversationStore
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showSettings: Bool = false
    
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                // Left Sidebar
                SidebarView(showSettings: $showSettings)
                
                // Divider
                Rectangle()
                    .fill(ThemeColors.divider(colorScheme))
                    .frame(width: 1)
                
                // Main Chat Area
                ChatView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .opacity(showSettings ? 0 : 1)
            
            // Settings Overlay
            if showSettings {
                SettingsView(isPresented: $showSettings)
                    .transition(.opacity)
            }
        }
        .frame(minWidth: 1200, minHeight: 800)
        .background(ThemeColors.windowBackground(colorScheme))
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
        .animation(.easeInOut(duration: 0.2), value: showSettings)
        // Handle menu commands
        .onReceive(NotificationCenter.default.publisher(for: .newChatRequested)) { _ in
            showSettings = false
            _ = conversationStore.createNewConversation()
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsRequested)) { _ in
            showSettings = true
        }
    }
}

#Preview {
    MainView()
        .environment(ConversationStore())
        .environment(ThemeManager())
        .environment(CognitoAuthService.shared)
}
