//
//  ContentView.swift
//  LanguageSuggestion
//
//  Main interface for text input and output
//

import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var menuBarManager: MenuBarManager
    @StateObject private var apiService = APIService()
    @StateObject private var accessibilityService = AccessibilityService()
    @StateObject private var floatingOverlayManager = FloatingOverlayManager()
    
    @State private var inputText: String = "Thiss sentence have a bigg typo and bad grammer, pls fix."
    @State private var outputText: String = ""
    @State private var currentAction: ActionType = .fixGrammar
    @State private var showChanges: Bool = false
    @State private var changes: [TextChange] = []
    @State private var confidence: Double?
    @State private var targetLanguage: String = "English"
    @State private var isScanningForOverlay: Bool = false
    @State private var suggestionPopup: NSWindow?
    @State private var suggestionText: String = ""
    @State private var isProcessingSuggestion: Bool = false
    @State private var currentActionName: String = "Grammar Suggestion"
    
    private var wordCount: Int {
        inputText.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.sRGB, red: 0.97, green: 0.98, blue: 1.0, opacity: 1.0),
                    Color(.sRGB, red: 0.94, green: 0.96, blue: 1.0, opacity: 1.0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 14) {
                headerBar
                
                HStack(alignment: .top, spacing: 16) {
                    inputPanel
                        .frame(maxWidth: .infinity, minHeight: 320)
                    outputPanel
                        .frame(maxWidth: .infinity, minHeight: 320)
                }
                
                HStack {
                    Button {
                        processText()
                    } label: {
                        Label("Process Now", systemImage: "arrow.right.circle.fill")
                            .font(.headline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(inputText.isEmpty || apiService.isLoading || settingsManager.currentAPIKey.isEmpty)
                    
                    if apiService.isLoading {
                        ProgressView()
                            .scaleEffect(0.9)
                            .padding(.leading, 6)
                    }
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: processText) {
                    Label("Process", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(inputText.isEmpty || apiService.isLoading || settingsManager.currentAPIKey.isEmpty)
            }
            
            ToolbarItem(placement: .secondaryAction) {
                Button(action: copyOutput) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(outputText.isEmpty)
            }
            
            ToolbarItem(placement: .secondaryAction) {
                Button(action: clearAll) {
                    Label("Clear", systemImage: "trash")
                }
            }
            
            ToolbarItem(placement: .secondaryAction) {
                EmptyView()
            }
        }
        .alert("Error", isPresented: .constant(apiService.errorMessage != nil)) {
            Button("OK") {
                apiService.errorMessage = nil
            }
        } message: {
            Text(apiService.errorMessage ?? "")
        }
        .onAppear {
            currentAction = settingsManager.defaultAction
            targetLanguage = settingsManager.targetLanguage
            setupNotificationHandlers()
            
            // Auto-show floating overlay on startup with retry
            autoShowOverlayWithRetry()
        }
    }
    
    private var headerBar: some View {
        HStack(spacing: 8) {
            Label("LanguageSuggestion", systemImage: "wand.and.stars")
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            StatusPill(
                title: settingsManager.apiProvider.rawValue,
                systemImage: "antenna.radiowaves.left.and.right",
                color: .blue.opacity(0.15),
                textColor: .blue
            )
            
            StatusPill(
                title: currentAction.rawValue,
                systemImage: currentAction == .translate ? "globe" : "text.badge.checkmark",
                color: .purple.opacity(0.15),
                textColor: .purple
            )
            
            if apiService.isLoading {
                StatusPill(
                    title: "Running",
                    systemImage: "hourglass",
                    color: .orange.opacity(0.2),
                    textColor: .orange
                )
            }
            
            // Accessibility permission indicator
            Button(action: {
                accessibilityService.openAccessibilitySettings()
            }) {
                Text(accessibilityService.isAccessibilityEnabled ? "Accessibility ✓" : "Grant Permission")
                    .font(.caption)
                    .foregroundColor(accessibilityService.isAccessibilityEnabled ? .green : .orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(accessibilityService.isAccessibilityEnabled ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    )
            }
            .buttonStyle(.plain)
            .help(accessibilityService.isAccessibilityEnabled ? "Accessibility Enabled ✓" : "Click to Grant Accessibility Permission")
            
            // Settings button
            Button(action: {
                menuBarManager.openSettings()
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
            .help("Open Settings")
        }
        .padding(.horizontal, 10)
    }
    
    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Input")
                    .font(.title3.weight(.semibold))
                Spacer()
                Picker("Action", selection: $currentAction) {
                    ForEach(ActionType.allCases, id: \.self) { action in
                        Text(action.rawValue).tag(action)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }
            
            if currentAction == .translate {
                HStack(spacing: 8) {
                    Label("Target Language", systemImage: "globe")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("e.g. Vietnamese", text: $targetLanguage)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                }
            }
            
            RichCard {
                TextEditor(text: $inputText)
                    .font(.system(.body, design: .default))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.vertical, 8)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 12) {
                    Label("\(wordCount) words", systemImage: "character.cursor.ibeam")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if inputText.isEmpty {
                        Text("Paste or type your text here to translate or fix grammar.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .overlay(alignment: .bottomTrailing) {
                if !floatingOverlayManager.isOverlayVisible && !isScanningForOverlay {
                    Button(action: showOverlay) {
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.title3)
                            .foregroundColor(.blue.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Retry showing overlay on supported apps (Teams, Notes)")
                    .padding(12)
                } else if isScanningForOverlay {
                    ProgressView()
                        .controlSize(.small)
                        .padding(12)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.9)))
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
        .frame(minWidth: 360)
    }
    
    private var outputPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            outputHeader
            
            if showChanges && !changes.isEmpty {
                changesSection
            }
            
            outputTextSection
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.9)))
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
        .frame(minWidth: 360)
    }
    
    @ViewBuilder
    private var outputHeader: some View {
        HStack {
            Text("Output")
                .font(.title3.weight(.semibold))
            Spacer()
            if let confidence = confidence {
                StatusPill(
                    title: "\(Int(confidence * 100))% confidence",
                    systemImage: "checkmark.seal.fill",
                    color: .green.opacity(0.15),
                    textColor: .green
                )
            }
            if !changes.isEmpty {
                Button(action: { showChanges.toggle() }) {
                    Label(showChanges ? "Hide Changes" : "Show Changes", systemImage: showChanges ? "eye.slash" : "eye")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    @ViewBuilder
    private var changesSection: some View {
        RichCard {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(changes.indices, id: \.self) { idx in
                        ChangeRow(change: changes[idx])
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 180)
        }
    }
    
    private var outputTextSection: some View {
        RichCard {
            ScrollView {
                Text(outputText.isEmpty ? "Processed text will appear here..." : outputText)
                    .font(.system(.body, design: .default))
                    .foregroundColor(outputText.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .textSelection(.enabled)
            }
        }
    }
    
    private func processText() {
        guard !inputText.isEmpty else { return }
        guard !settingsManager.currentAPIKey.isEmpty else {
            apiService.errorMessage = "Please configure your API key in Settings."
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
                
                await MainActor.run {
                    outputText = response.processedText
                    changes = response.changes ?? []
                    confidence = response.confidence
                    showChanges = !changes.isEmpty
                }
            } catch {
                await MainActor.run {
                    apiService.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func processCustomPrompt(_ customPrompt: CustomPrompt) {
        // Get text from focused element
        var textToProcess: String?
        
        // Try to get selected text first
        if let text = accessibilityService.getTextFromFocusedElement(), !text.isEmpty {
            textToProcess = text
            print("✅ Got text from focused element: \(text.prefix(50))...")
        } else if let text = accessibilityService.getTextFromTeams(), !text.isEmpty {
            textToProcess = text
            print("✅ Got text from Teams: \(text.prefix(50))...")
        }
        
        guard let text = textToProcess, !text.isEmpty else {
            print("❌ No text found to process")
            apiService.errorMessage = "No text found. Please select or focus on some text first."
            return
        }
        
        guard !settingsManager.currentAPIKey.isEmpty else {
            apiService.errorMessage = "Please configure your API key in Settings."
            return
        }
        
        // Update input text and action name
        inputText = text
        currentActionName = customPrompt.name
        
        // Process with custom prompt
        Task {
            do {
                let response = try await apiService.processTextWithCustomPrompt(
                    text: text,
                    customPrompt: customPrompt.prompt,
                    provider: settingsManager.apiProvider,
                    apiKey: settingsManager.currentAPIKey
                )
                
                await MainActor.run {
                    outputText = response.processedText
                    changes = response.changes ?? []
                    confidence = response.confidence
                    showChanges = !changes.isEmpty
                    
                    // Show suggestion popup with custom prompt name
                    showSuggestionPopup(suggestion: response.processedText, title: customPrompt.name)
                    
                    // Copy to clipboard automatically
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(response.processedText, forType: .string)
                    print("📋 Result copied to clipboard")
                }
            } catch {
                await MainActor.run {
                    apiService.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func copyOutput() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(outputText, forType: .string)
    }
    
    private func clearAll() {
        inputText = ""
        outputText = ""
        changes = []
        confidence = nil
        showChanges = false
    }
    
    private func showOverlay() {
        print("🚀 Starting overlay scan for supported apps...")
        
        // Check if any supported app is running
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
        
        // Check accessibility permission
        if !accessibilityService.checkAccessibilityPermission() {
            print("❌ Accessibility permission not granted - click shield icon to grant permission")
            return
        }
        
        isScanningForOverlay = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Try Teams first
            if teamsRunning {
                print("🔍 Scanning for Teams compose box (depth: 25)...")
                if let composeBox = self.accessibilityService.findTeamsComposeBox(maxDepth: 25) {
                    DispatchQueue.main.async {
                        print("✅ Found Teams compose box, showing overlay")
                        self.floatingOverlayManager.showOverlay(for: composeBox, accessibilityService: self.accessibilityService, settingsManager: self.settingsManager)
                        self.isScanningForOverlay = false
                    }
                    return
                }
            }
            
            // Try Notes if Teams failed or not running
            if notesRunning {
                print("🔍 Scanning for Notes text area (depth: 25)...")
                if let notesTextArea = self.accessibilityService.findNotesTextArea(maxDepth: 25) {
                    DispatchQueue.main.async {
                        print("✅ Found Notes text area, showing overlay")
                        self.floatingOverlayManager.showOverlay(for: notesTextArea, accessibilityService: self.accessibilityService, settingsManager: self.settingsManager)
                        self.isScanningForOverlay = false
                    }
                    return
                }
            }
            
            // If we get here, nothing was found
            DispatchQueue.main.async {
                print("❌ Could not find text area in any supported app")
                print("💡 Make sure Teams or Notes is open with an active text field")
                self.isScanningForOverlay = false
            }
        }
    }
    
    private func setupNotificationHandlers() {
        // Handle execute custom prompt from menu bar
        NotificationCenter.default.addObserver(
            forName: .executeCustomPrompt,
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let customPrompt = userInfo["customPrompt"] as? CustomPrompt else {
                print("❌ No custom prompt in notification")
                return
            }
            
            print("🚀 Processing custom prompt: \(customPrompt.name)")
            self.processCustomPrompt(customPrompt)
        }
        
        // Handle capture text from overlay and auto-fix
        NotificationCenter.default.addObserver(
            forName: .captureTextFromOverlay,
            object: nil,
            queue: .main
        ) { [weak accessibilityService] _ in
            print("📸 Capture text triggered from overlay")
            
            guard let accessibilityService = accessibilityService else { return }
            
            // Try to get text from the focused element (works for both Teams and Notes)
            var capturedText: String?
            
            // First try getting text from Teams if it's running
            if let text = accessibilityService.getTextFromTeams(), !text.isEmpty {
                capturedText = text
                print("✅ Text captured from Teams: \(text.prefix(50))...")
            }
            // If Teams didn't work, try getting from focused element (works for Notes)
            else if let text = accessibilityService.getTextFromFocusedElement(), !text.isEmpty {
                capturedText = text
                print("✅ Text captured from focused element: \(text.prefix(50))...")
            }
            
            if let text = capturedText {
                // Store original text
                self.inputText = text
                self.isProcessingSuggestion = true
                self.currentActionName = "Fix Grammar"
                
                // Auto-call API to fix grammar
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
                            
                            // Show suggestion popup with "Fix Grammar" title
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
        
        // Handle close overlay
        NotificationCenter.default.addObserver(
            forName: .closeFloatingOverlay,
            object: nil,
            queue: .main
        ) { _ in
            print("❌ Close overlay triggered")
            self.floatingOverlayManager.hideOverlay()
        }
    }
    
    private func showSuggestionPopup(suggestion: String, title: String = "Grammar Suggestion") {
        print("💬 Showing suggestion popup with title: \(title)")
        
        // Close existing popup if any
        suggestionPopup?.close()
        
        // Create popup window with dynamic title
        let popup = SuggestionPopupWindow(title: title)
        
        // Create SwiftUI content with dynamic title
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
        
        // Position popup near floating icon (center of screen for now)
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
        let delay: TimeInterval = Double(attempt) * 1.0 // 1s, 2s, 3s, 4s, 5s
        
        print("🔄 Auto-show overlay attempt \(attempt)/\(maxAttempts) - waiting \(delay)s...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // Check if any supported app is running
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
                    self.autoShowOverlayWithRetry(attempt: attempt + 1, maxAttempts: maxAttempts)
                } else {
                    print("⏹️ Max attempts reached, giving up")
                }
                return
            }
            
            // Try to show overlay
            self.isScanningForOverlay = true
            
            DispatchQueue.global(qos: .userInitiated).async {
                var foundTextArea: AccessibleElement?
                
                // Try Teams first
                if teamsRunning {
                    foundTextArea = self.accessibilityService.findTeamsComposeBox(maxDepth: 25)
                }
                
                // Try Notes if Teams failed
                if foundTextArea == nil && notesRunning {
                    foundTextArea = self.accessibilityService.findNotesTextArea(maxDepth: 25)
                }
                
                if let textArea = foundTextArea {
                    DispatchQueue.main.async {
                        print("✅ Auto-show successful on attempt \(attempt)!")
                        self.floatingOverlayManager.showOverlay(for: textArea, accessibilityService: self.accessibilityService, settingsManager: self.settingsManager)
                        self.isScanningForOverlay = false
                    }
                } else {
                    DispatchQueue.main.async {
                        print("❌ Attempt \(attempt) failed to find text area")
                        self.isScanningForOverlay = false
                        
                        // Retry if not max attempts
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

private struct StatusPill: View {
    let title: String
    let systemImage: String
    let color: Color
    let textColor: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.caption)
        .foregroundColor(textColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(color))
    }
}

private struct RichCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.textBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

private struct ChangeRow: View {
    let change: TextChange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(change.original)
                    .strikethrough()
                    .foregroundColor(.red)
                Text("→")
                    .foregroundColor(.secondary)
                Text(change.corrected)
                    .foregroundColor(.green)
            }
            .font(.system(.body, design: .monospaced))
            
            if !change.reason.isEmpty {
                Text(change.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(SettingsManager())
        .frame(width: 800, height: 600)
}

// Teams Elements Viewer
struct TeamsElementsViewer: View {
    @ObservedObject var accessibilityService: AccessibilityService
    @Binding var elements: [AccessibleElement]
    @Binding var isLoading: Bool
    @State private var searchText: String = ""
    @State private var selectedRole: String = "All"
    @State private var maxDepth: Int = 10
    let onSelectElement: (AccessibleElement) -> Void
    
    private let roleOptions = ["All", "AXTextField", "AXTextArea", "AXButton", "AXStaticText", "AXGroup", "AXScrollArea", "AXWindow"]
    
    var filteredElements: [AccessibleElement] {
        var filtered = elements
        
        // Filter by role
        if selectedRole != "All" {
            filtered = filtered.filter { $0.role == selectedRole }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { element in
                element.role.localizedCaseInsensitiveContains(searchText) ||
                element.title?.localizedCaseInsensitiveContains(searchText) == true ||
                element.value?.localizedCaseInsensitiveContains(searchText) == true ||
                element.identifier?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        return filtered
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Teams UI Elements Explorer")
                    .font(.title2.bold())
                
                Spacer()
                
                Button("Close") {
                    // Close handled by parent
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // Controls
            VStack(spacing: 12) {
                HStack {
                    Button(action: loadElements) {
                        Label(isLoading ? "Loading..." : "Scan Teams Elements", systemImage: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                    
                    Stepper("Max Depth: \(maxDepth)", value: $maxDepth, in: 1...30)
                        .frame(width: 200)
                    
                    Spacer()
                    
                    Text("\(filteredElements.count) elements")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                
                HStack {
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    
                    Picker("Role", selection: $selectedRole) {
                        ForEach(roleOptions, id: \.self) { role in
                            Text(role).tag(role)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }
            }
            .padding()
            
            Divider()
            
            // Elements List
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Scanning Teams UI...")
                        .scaleEffect(1.2)
                    Spacer()
                }
            } else if elements.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No elements scanned yet")
                        .font(.headline)
                    Text("Click 'Scan Teams Elements' to explore the UI")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if filteredElements.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No matching elements")
                        .font(.headline)
                    Text("Try adjusting your filters")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(filteredElements) { element in
                            ElementRow(element: element, onSelect: {
                                onSelectElement(element)
                            })
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    private func loadElements() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let scannedElements = accessibilityService.getAllTeamsElements(maxDepth: maxDepth)
            
            DispatchQueue.main.async {
                elements = scannedElements
                isLoading = false
            }
        }
    }
}

// Element Row
struct ElementRow: View {
    let element: AccessibleElement
    let onSelect: () -> Void
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Indentation
                Text(String(repeating: "  ", count: element.depth))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.clear)
                
                // Role badge
                Text(element.role)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(roleColor(element.role).opacity(0.2))
                    .foregroundColor(roleColor(element.role))
                    .cornerRadius(4)
                
                // Title/Value
                if let title = element.title, !title.isEmpty {
                    Text(title)
                        .font(.body)
                        .lineLimit(1)
                }
                
                if let value = element.value, !value.isEmpty, element.title != element.value {
                    Text(value)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Indicators
                if element.focused {
                    Image(systemName: "circle.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                
                // Actions
                if element.value != nil && !element.value!.isEmpty {
                    Button(action: onSelect) {
                        Image(systemName: "arrow.down.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Use this text")
                }
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(element.focused ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(4)
            
            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    if let identifier = element.identifier {
                        DetailRow(label: "Identifier", value: identifier)
                    }
                    if let elementDescription = element.elementDescription {
                        DetailRow(label: "Description", value: elementDescription)
                    }
                    if let position = element.position {
                        DetailRow(label: "Position", value: "(\(Int(position.x)), \(Int(position.y)))")
                    }
                    if let size = element.size {
                        DetailRow(label: "Size", value: "\(Int(size.width)) × \(Int(size.height))")
                    }
                    DetailRow(label: "Depth", value: "\(element.depth)")
                    DetailRow(label: "Enabled", value: element.enabled ? "Yes" : "No")
                }
                .padding(.leading, 40)
                .padding(.vertical, 4)
                .font(.caption)
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(isExpanded ? 0.5 : 0))
    }
    
    private func roleColor(_ role: String) -> Color {
        switch role {
        case "AXTextField", "AXTextArea":
            return .blue
        case "AXButton":
            return .green
        case "AXStaticText":
            return .purple
        case "AXWindow":
            return .orange
        case "AXGroup":
            return .gray
        default:
            return .secondary
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text("\(label):")
                .foregroundColor(.secondary)
            Text(value)
                .foregroundColor(.primary)
        }
    }
}

// Suggestion popup content
struct SuggestionPopupContent: View {
    let title: String
    let originalText: String
    let suggestedText: String
    let onCopy: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(.purple)
                Text(title)
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Original text
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "text.quote")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Original:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ScrollView {
                    Text(originalText)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                }
                .frame(minHeight: 60, maxHeight: .infinity)
            }
            
            // Suggested text
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Suggestion:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ScrollView {
                    Text(suggestedText)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                }
                .frame(minHeight: 60, maxHeight: .infinity)
            }
            
            // Actions
            HStack(spacing: 12) {
                Button(action: onCopy) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                Button(action: onClose) {
                    Text("Close")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(minWidth: 300, minHeight: 200)
    }
}


