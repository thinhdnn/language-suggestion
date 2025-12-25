//
//  LanguageSuggestionApp.swift
//  LanguageSuggestion
//
//  Created on macOS
//

import SwiftUI

@main
struct LanguageSuggestionApp: App {
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var menuBarManager = MenuBarManager()
    @StateObject private var accessibilityService = AccessibilityService()
    @State private var showOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            Group {
                if showOnboarding {
                    OnboardingGuideView(accessibilityService: accessibilityService) {
                        showOnboarding = false
                    }
                    .environmentObject(settingsManager)
                } else {
                    ContentView()
                        .environmentObject(settingsManager)
                        .environmentObject(menuBarManager)
                        .frame(minWidth: 800, minHeight: 600)
                        .onAppear {
                            // Setup menu bar when app appears
                            menuBarManager.setupMenuBar(settingsManager: settingsManager)
                        }
                }
            }
            .onAppear {
                checkOnboardingStatus()
            }
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Button("Settings...") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(settingsManager)
        }
    }
    
    private func checkOnboardingStatus() {
        // Check if onboarding has been completed
        let onboardingCompleted = UserDefaults.standard.bool(forKey: "onboardingCompleted")
        
        // Refresh accessibility status
        accessibilityService.checkAccessibilityPermission()
        
        if onboardingCompleted {
            // Onboarding was completed, check if setup is still valid
            // If API key is missing or accessibility is not granted, show onboarding again
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Wait a bit for settings to load
                if settingsManager.currentAPIKey.isEmpty || !accessibilityService.isAccessibilityEnabled {
                    showOnboarding = true
                }
            }
        } else {
            // First time opening app, show onboarding
            showOnboarding = true
        }
    }
}

