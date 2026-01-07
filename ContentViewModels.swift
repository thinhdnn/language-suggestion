//
//  ContentViewModels.swift
//  LanguageSuggestion
//
//  ViewModels for ContentView following MVVM architecture
//

import Foundation
import Observation
import AppKit
import SwiftUI

@Observable
@MainActor
final class ContentViewModel {
    var inputText: String = "Thiss sentence have a bigg typo and bad grammer, pls fix."
    var outputText: String = ""
    var currentAction: ActionType = .fixGrammar
    var showChanges: Bool = false
    var changes: [TextChange] = []
    var confidence: Double?
    var targetLanguage: String = "English"
    var isScanningForOverlay: Bool = false
    var suggestionPopup: NSWindow?
    var suggestionText: String = ""
    var isProcessingSuggestion: Bool = false
    var currentActionName: String = "Grammar Suggestion"
    
    private let apiService: APIServiceProtocol
    private let accessibilityService: AccessibilityService
    let floatingOverlayManager: FloatingOverlayManager
    private let settingsManager: SettingsManager
    private let menuBarManager: MenuBarManager
    
    var wordCount: Int {
        inputText.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
    
    init(
        apiService: APIServiceProtocol,
        accessibilityService: AccessibilityService,
        floatingOverlayManager: FloatingOverlayManager,
        settingsManager: SettingsManager,
        menuBarManager: MenuBarManager
    ) {
        self.apiService = apiService
        self.accessibilityService = accessibilityService
        self.floatingOverlayManager = floatingOverlayManager
        self.settingsManager = settingsManager
        self.menuBarManager = menuBarManager
        
        setupNotificationHandlers()
    }
    
    func processText() {
        guard !inputText.isEmpty else { return }
        guard !settingsManager.currentAPIKey.isEmpty else {
            if let apiService = apiService as? APIService {
                apiService.errorMessage = "Please configure your API key in Settings."
            }
            return
        }
        
        Task {
            do {
                let response = try await apiService.processText(
                    text: inputText,
                    action: currentAction,
                    targetLanguage: currentAction == .translate ? targetLanguage : nil,
                    provider: settingsManager.apiProvider,
                    apiKey: settingsManager.currentAPIKey
                )
                
                outputText = response.processedText
                changes = response.changes ?? []
                confidence = response.confidence
                showChanges = !changes.isEmpty
            } catch {
                if let apiService = apiService as? APIService {
                    apiService.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func processCustomPrompt(_ customPrompt: CustomPrompt) {
        var textToProcess: String?
        
        if let text = accessibilityService.getTextFromFocusedElement(), !text.isEmpty {
            textToProcess = text
            print("✅ Got text from focused element: \(text.prefix(50))...")
        } else if let text = accessibilityService.getTextFromTeams(), !text.isEmpty {
            textToProcess = text
            print("✅ Got text from Teams: \(text.prefix(50))...")
        }
        
        guard let text = textToProcess, !text.isEmpty else {
            print("❌ No text found to process")
            if let apiService = apiService as? APIService {
                apiService.errorMessage = "No text found. Please select or focus on some text first."
            }
            return
        }
        
        guard !settingsManager.currentAPIKey.isEmpty else {
            if let apiService = apiService as? APIService {
                apiService.errorMessage = "Please configure your API key in Settings."
            }
            return
        }
        
        inputText = text
        currentActionName = customPrompt.name
        
        Task {
            do {
                let response = try await apiService.processTextWithCustomPrompt(
                    text: text,
                    customPrompt: customPrompt.prompt,
                    provider: settingsManager.apiProvider,
                    apiKey: settingsManager.currentAPIKey
                )
                
                outputText = response.processedText
                changes = response.changes ?? []
                confidence = response.confidence
                showChanges = !changes.isEmpty
                
                showSuggestionPopup(suggestion: response.processedText, title: customPrompt.name)
                
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(response.processedText, forType: .string)
                print("📋 Result copied to clipboard")
            } catch {
                if let apiService = apiService as? APIService {
                    apiService.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func copyOutput() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(outputText, forType: .string)
    }
    
    func clearAll() {
        inputText = ""
        outputText = ""
        changes = []
        confidence = nil
        showChanges = false
    }
    
    func showOverlay() {
        print("🚀 Starting overlay scan for supported apps...")
        
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        let teamsRunning = runningApps.contains { app in
            app.bundleIdentifier == "com.microsoft.teams" ||
            app.bundleIdentifier == "com.microsoft.teams2"
        }
        
        let notesRunning = runningApps.contains { app in
            app.bundleIdentifier == "com.apple.Notes"
        }
        
        if !teamsRunning && !notesRunning {
            print("⚠️ Neither Teams nor Notes is running!")
        } else {
            if teamsRunning { print("✅ Teams is running") }
            if notesRunning { print("✅ Notes is running") }
        }
        
        if !accessibilityService.checkAccessibilityPermission() {
            print("❌ Accessibility permission not granted - click shield icon to grant permission")
            return
        }
        
        // Check which app is currently active/frontmost
        let activeApp = workspace.frontmostApplication
        let activeBundleId = activeApp?.bundleIdentifier ?? ""
        
        let isTeamsActive = activeBundleId == "com.microsoft.teams" || activeBundleId == "com.microsoft.teams2"
        let isNotesActive = activeBundleId == "com.apple.Notes"
        
        print("🔍 Active app: \(activeBundleId)")
        
        isScanningForOverlay = true
        
        Task.detached(priority: .userInitiated) {
            // Prioritize the currently active app
            if isNotesActive && notesRunning {
                print("🔍 Scanning for Notes text area (depth: 30)...")
                if let notesTextArea = self.accessibilityService.findNotesTextArea(maxDepth: 30) {
                    await MainActor.run {
                        print("✅ Found Notes text area, showing overlay")
                        self.floatingOverlayManager.showOverlay(
                            for: notesTextArea,
                            accessibilityService: self.accessibilityService,
                            settingsManager: self.settingsManager
                        )
                        self.isScanningForOverlay = false
                    }
                    return
                }
            }
            
            if isTeamsActive && teamsRunning {
                print("🔍 Scanning for Teams compose box (depth: 30)...")
                if let composeBox = self.accessibilityService.findTeamsComposeBox(maxDepth: 30) {
                    await MainActor.run {
                        print("✅ Found Teams compose box, showing overlay")
                        self.floatingOverlayManager.showOverlay(
                            for: composeBox,
                            accessibilityService: self.accessibilityService,
                            settingsManager: self.settingsManager
                        )
                        self.isScanningForOverlay = false
                    }
                    return
                }
            }
            
            // Fallback: try Teams if not active app found
            if teamsRunning && !isNotesActive {
                print("🔍 Scanning for Teams compose box (depth: 30)...")
                if let composeBox = self.accessibilityService.findTeamsComposeBox(maxDepth: 30) {
                    await MainActor.run {
                        print("✅ Found Teams compose box, showing overlay")
                        self.floatingOverlayManager.showOverlay(
                            for: composeBox,
                            accessibilityService: self.accessibilityService,
                            settingsManager: self.settingsManager
                        )
                        self.isScanningForOverlay = false
                    }
                    return
                }
            }
            
            // Fallback: try Notes if not active app found
            if notesRunning && !isTeamsActive {
                print("🔍 Scanning for Notes text area (depth: 30)...")
                if let notesTextArea = self.accessibilityService.findNotesTextArea(maxDepth: 30) {
                    await MainActor.run {
                        print("✅ Found Notes text area, showing overlay")
                        self.floatingOverlayManager.showOverlay(
                            for: notesTextArea,
                            accessibilityService: self.accessibilityService,
                            settingsManager: self.settingsManager
                        )
                        self.isScanningForOverlay = false
                    }
                    return
                }
            }
            
            await MainActor.run {
                print("❌ Could not find text area in any supported app")
                print("💡 Make sure Teams or Notes is open with an active text field")
                self.isScanningForOverlay = false
            }
        }
    }
    
    func openSettings() {
        menuBarManager.openSettings()
    }
    
    func openAccessibilitySettings() {
        accessibilityService.openAccessibilitySettings()
    }
    
    func initialize() {
        currentAction = settingsManager.defaultAction
        targetLanguage = settingsManager.targetLanguage
        autoShowOverlayWithRetry()
    }
    
    private func setupNotificationHandlers() {
        NotificationCenter.default.addObserver(
            forName: .executeCustomPrompt,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let customPrompt = userInfo["customPrompt"] as? CustomPrompt else {
                print("❌ No custom prompt in notification")
                return
            }
            
            print("🚀 Processing custom prompt: \(customPrompt.name)")
            Task { @MainActor in
                self.processCustomPrompt(customPrompt)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .captureTextFromOverlay,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            print("📸 Capture text triggered from overlay")
            
            var capturedText: String?
            
            if let text = self.accessibilityService.getTextFromTeams(), !text.isEmpty {
                capturedText = text
                print("✅ Text captured from Teams: \(text.prefix(50))...")
            } else if let text = self.accessibilityService.getTextFromFocusedElement(), !text.isEmpty {
                capturedText = text
                print("✅ Text captured from focused element: \(text.prefix(50))...")
            }
            
            if let text = capturedText {
                self.inputText = text
                self.isProcessingSuggestion = true
                self.currentActionName = "Fix Grammar"
                
                print("🔧 Auto-fixing grammar...")
                Task {
                    do {
                        let result = try await self.apiService.processText(
                            text: text,
                            action: .fixGrammar,
                            targetLanguage: self.targetLanguage,
                            provider: self.settingsManager.apiProvider,
                            apiKey: self.settingsManager.currentAPIKey
                        )
                        
                        await MainActor.run {
                            print("✅ Grammar fixed successfully")
                            self.suggestionText = result.processedText
                            self.outputText = result.processedText
                            self.changes = result.changes ?? []
                            self.confidence = result.confidence
                            self.isProcessingSuggestion = false
                            
                            self.showSuggestionPopup(suggestion: result.processedText, title: "Fix Grammar")
                        }
                    } catch {
                        await MainActor.run {
                            print("❌ Failed to fix grammar: \(error.localizedDescription)")
                            self.isProcessingSuggestion = false
                        }
                    }
                }
            } else {
                print("⚠️ No text captured from any supported app")
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .closeFloatingOverlay,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            print("❌ Close overlay triggered")
            self.floatingOverlayManager.hideOverlay()
        }
    }
    
    private func showSuggestionPopup(suggestion: String, title: String = "Grammar Suggestion") {
        print("💬 Showing suggestion popup with title: \(title)")
        
        suggestionPopup?.close()
        
        let popup = SuggestionPopupWindow(title: title)
        
        let content = SuggestionPopupContent(
            title: title,
            originalText: inputText,
            suggestedText: suggestion,
            onCopy: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(suggestion, forType: .string)
                print("📋 Copied to clipboard")
            },
            onClose: {
                self.suggestionPopup?.close()
                self.suggestionPopup = nil
            }
        )
        
        popup.contentView = NSHostingView(rootView: content)
        
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let popupRect = popup.frame
            let x = (screenRect.width - popupRect.width) / 2 + screenRect.origin.x
            let y = (screenRect.height - popupRect.height) / 2 + screenRect.origin.y
            popup.setFrameOrigin(CGPoint(x: x, y: y))
        }
        
        popup.makeKeyAndOrderFront(nil)
        suggestionPopup = popup
    }
    
    private func autoShowOverlayWithRetry(attempt: Int = 1, maxAttempts: Int = 5) {
        let delay: TimeInterval = Double(attempt) * 1.0
        
        print("🔄 Auto-show overlay attempt \(attempt)/\(maxAttempts) - waiting \(delay)s...")
        
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            let workspace = NSWorkspace.shared
            let runningApps = workspace.runningApplications
            
            let teamsRunning = runningApps.contains { app in
                app.bundleIdentifier == "com.microsoft.teams" ||
                app.bundleIdentifier == "com.microsoft.teams2"
            }
            
            let notesRunning = runningApps.contains { app in
                app.bundleIdentifier == "com.apple.Notes"
            }
            
            if !teamsRunning && !notesRunning {
                print("⏭️ No supported apps running, skipping attempt \(attempt)")
                if attempt < maxAttempts {
                    autoShowOverlayWithRetry(attempt: attempt + 1, maxAttempts: maxAttempts)
                } else {
                    print("⏹️ Max attempts reached, giving up")
                }
                return
            }
            
            isScanningForOverlay = true
            
            // Check which app is currently active/frontmost
            let activeApp = workspace.frontmostApplication
            let activeBundleId = activeApp?.bundleIdentifier ?? ""
            let isTeamsActive = activeBundleId == "com.microsoft.teams" || activeBundleId == "com.microsoft.teams2"
            let isNotesActive = activeBundleId == "com.apple.Notes"
            
            Task.detached(priority: .userInitiated) {
                var foundTextArea: AccessibleElement?
                
                // Prioritize the currently active app
                if isNotesActive && notesRunning {
                    foundTextArea = self.accessibilityService.findNotesTextArea(maxDepth: 30)
                }
                
                if foundTextArea == nil && isTeamsActive && teamsRunning {
                    foundTextArea = self.accessibilityService.findTeamsComposeBox(maxDepth: 30)
                }
                
                // Fallback: try Teams if no active app found
                if foundTextArea == nil && teamsRunning && !isNotesActive {
                    foundTextArea = self.accessibilityService.findTeamsComposeBox(maxDepth: 30)
                }
                
                // Fallback: try Notes if no active app found
                if foundTextArea == nil && notesRunning && !isTeamsActive {
                    foundTextArea = self.accessibilityService.findNotesTextArea(maxDepth: 30)
                }
                
                if let textArea = foundTextArea {
                    await MainActor.run {
                        print("✅ Auto-show successful on attempt \(attempt)!")
                        self.floatingOverlayManager.showOverlay(
                            for: textArea,
                            accessibilityService: self.accessibilityService,
                            settingsManager: self.settingsManager
                        )
                        self.isScanningForOverlay = false
                    }
                } else {
                    await MainActor.run {
                        print("❌ Attempt \(attempt) failed to find text area")
                        self.isScanningForOverlay = false
                        
                        if attempt < maxAttempts {
                            print("🔄 Will retry in \(attempt + 1) seconds...")
                            self.autoShowOverlayWithRetry(attempt: attempt + 1, maxAttempts: maxAttempts)
                        } else {
                            print("⏹️ Max attempts reached. Use retry button to try manually.")
                        }
                    }
                }
            }
        }
    }
}

