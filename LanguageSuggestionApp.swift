//
//  LanguageSuggestionApp.swift
//  LanguageSuggestion
//
//  Created on macOS
//

import SwiftUI

@main
struct LanguageSuggestionApp: App {
    @State private var settingsManager = SettingsManager()
    @State private var menuBarManager = MenuBarManager()
    @State private var accessibilityService = AccessibilityService()
    @State private var apiService = APIService()
    @State private var floatingOverlayManager = FloatingOverlayManager()
    @State private var showOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            Group {
                if showOnboarding {
                    OnboardingGuideView(
                        settingsManager: settingsManager,
                        accessibilityService: accessibilityService
                    ) {
                        showOnboarding = false
                    }
                } else {
                    ContentView(
                        apiService: apiService,
                        accessibilityService: accessibilityService,
                        floatingOverlayManager: floatingOverlayManager,
                        settingsManager: settingsManager,
                        menuBarManager: menuBarManager
                    )
                    .frame(minWidth: 800, minHeight: 600)
                    .onAppear {
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
            SettingsView(settingsManager: settingsManager)
        }
    }
    
    private func checkOnboardingStatus() {
        // Check if onboarding has been completed
        let onboardingCompleted = UserDefaults.standard.bool(forKey: "onboardingCompleted")
        
        // Refresh accessibility status
        _ = accessibilityService.checkAccessibilityPermission()
        
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

