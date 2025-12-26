//
//  FloatingOverlayWindow.swift
//  LanguageSuggestion
//
//  Floating icon overlay for quick text capture from Teams
//

import SwiftUI
import AppKit
import Observation

// Supported apps for overlay
enum SupportedApp: String {
    case teams = "Teams"
    case notes = "Notes"
    
    var bundleIdentifiers: [String] {
        switch self {
        case .teams:
            return ["com.microsoft.teams", "com.microsoft.teams2"]
        case .notes:
            return ["com.apple.Notes"]
        }
    }
}

// Floating overlay window manager
@Observable
final class FloatingOverlayManager {
    var isOverlayVisible: Bool = false
    
    private var overlayWindow: FloatingOverlayWindow?
    private var monitorTimer: Timer?
    private var targetElement: AccessibleElement?
    private var accessibilityService: AccessibilityService?
    private var currentApp: SupportedApp = .teams
    private var settingsManager: SettingsManager?
    
    func showOverlay(for element: AccessibleElement, accessibilityService: AccessibilityService, settingsManager: SettingsManager? = nil) {
        self.targetElement = element
        self.accessibilityService = accessibilityService
        self.settingsManager = settingsManager
        
        // Create window if needed
        if overlayWindow == nil {
            overlayWindow = FloatingOverlayWindow(overlayManager: self)
        }
        
        // Position the icon at the top-right of the target element
        updateOverlayPosition(for: element)
        
        // Show the window
        overlayWindow?.makeKeyAndOrderFront(nil)
        isOverlayVisible = true
        
        print("✅ Overlay window created and shown")
        
        // Start monitoring Teams window state and position
        startMonitoring()
    }
    
    func hideOverlay() {
        stopMonitoring()
        overlayWindow?.close()
        overlayWindow = nil
        isOverlayVisible = false
        print("🔴 Overlay hidden")
    }
    
    private func updateOverlayPosition(for element: AccessibleElement) {
        guard let position = element.position, let size = element.size else {
            print("⚠️ Cannot update overlay position - missing position or size")
            return
        }
        
        let iconSize: CGFloat = 24
        let padding: CGFloat = 6
        let screenHeight = NSScreen.main?.frame.height ?? 0
        
        // Position icon at top-right of the text area
        // Accessibility API: top-left origin (0,0 at top-left)
        // NSWindow: bottom-left origin (0,0 at bottom-left)
        let iconX = position.x + size.width - iconSize - padding
        let iconY = screenHeight - position.y - iconSize - padding
        
        print("📍 Positioning overlay:")
        print("   Text area (Accessibility): (\(position.x), \(position.y))")
        print("   Text area size: \(size.width) x \(size.height)")
        print("   Screen height: \(screenHeight)")
        print("   Icon position (NSWindow): (\(iconX), \(iconY))")
        
        overlayWindow?.setFrameOrigin(CGPoint(x: iconX, y: iconY))
        overlayWindow?.setContentSize(CGSize(width: iconSize, height: iconSize))
    }
    
    private func startMonitoring() {
        stopMonitoring()
        
        // Check supported apps window state every 1 second
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self,
                  let accessibilityService = self.accessibilityService else { return }
            
            // Check which supported app is active
            let activeApp = self.getActiveSupportedApp()
            
            print("🔍 Monitor check - Active app: \(activeApp?.rawValue ?? "none")")
            
            if let activeApp = activeApp {
                // A supported app is active - show overlay and update position
                self.currentApp = activeApp
                
                if !self.isOverlayVisible {
                    print("✅ \(activeApp.rawValue) became active - showing overlay")
                    self.overlayWindow?.orderFront(nil)
                    self.isOverlayVisible = true
                }
                
                // Update position by re-scanning
                DispatchQueue.global(qos: .userInitiated).async {
                    let textArea: AccessibleElement?
                    
                    switch activeApp {
                    case .teams:
                        textArea = accessibilityService.findTeamsComposeBox(maxDepth: 25)
                    case .notes:
                        textArea = accessibilityService.findNotesTextArea(maxDepth: 25)
                    }
                    
                    if let textArea = textArea {
                        DispatchQueue.main.async {
                            self.updateOverlayPosition(for: textArea)
                            self.targetElement = textArea
                        }
                    }
                }
            } else {
                // No supported app is active - hide overlay
                if self.isOverlayVisible {
                    print("🔴 Supported app became inactive - hiding overlay")
                    self.overlayWindow?.orderOut(nil)
                    self.isOverlayVisible = false
                }
            }
        }
    }
    
    private func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }
    
    private func isTeamsActive() -> Bool {
        guard let activeApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }
        
        let bundleId = activeApp.bundleIdentifier ?? ""
        let isActive = bundleId == "com.microsoft.teams" || bundleId == "com.microsoft.teams2"
        
        return isActive
    }
    
    // Check if any supported app is active and return which one
    private func getActiveSupportedApp() -> SupportedApp? {
        guard let activeApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = activeApp.bundleIdentifier else {
            return nil
        }
        
        // Check Teams
        if SupportedApp.teams.bundleIdentifiers.contains(bundleId) {
            return .teams
        }
        
        // Check Notes
        if SupportedApp.notes.bundleIdentifiers.contains(bundleId) {
            return .notes
        }
        
        return nil
    }
    
    // Show menu with custom prompts
    func showCustomPromptsMenu(at point: NSPoint) {
        guard let settingsManager = settingsManager else {
            print("⚠️ No settings manager available")
            return
        }
        
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        // Add custom prompt items
        if !settingsManager.customPrompts.isEmpty {
            for customPrompt in settingsManager.customPrompts {
                let menuItem = NSMenuItem(
                    title: customPrompt.name,
                    action: #selector(executeCustomPromptFromFloating(_:)),
                    keyEquivalent: ""
                )
                menuItem.target = self
                menuItem.representedObject = customPrompt
                menuItem.isEnabled = true
                menu.addItem(menuItem)
            }
            
            menu.addItem(NSMenuItem.separator())
        }
        
        // Add default "Fix Grammar" option
        let fixGrammarItem = NSMenuItem(
            title: "Fix Grammar (Default)",
            action: #selector(captureAndFixGrammar),
            keyEquivalent: ""
        )
        fixGrammarItem.target = self
        fixGrammarItem.isEnabled = true
        menu.addItem(fixGrammarItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add close option
        let closeItem = NSMenuItem(
            title: "Close Overlay",
            action: #selector(closeOverlayFromMenu),
            keyEquivalent: ""
        )
        closeItem.target = self
        closeItem.isEnabled = true
        menu.addItem(closeItem)
        
        // Show menu at the icon position
        menu.popUp(positioning: nil, at: point, in: nil)
    }
    
    @objc private func executeCustomPromptFromFloating(_ sender: NSMenuItem) {
        guard let customPrompt = sender.representedObject as? CustomPrompt else {
            print("❌ No custom prompt found")
            return
        }
        
        print("🚀 Executing custom prompt from floating icon: \(customPrompt.name)")
        
        // Post notification with the custom prompt
        NotificationCenter.default.post(
            name: .executeCustomPrompt,
            object: nil,
            userInfo: ["customPrompt": customPrompt]
        )
    }
    
    @objc private func captureAndFixGrammar() {
        print("🔧 Capture and fix grammar from floating icon")
        // Send notification to capture text (default behavior)
        NotificationCenter.default.post(name: .captureTextFromOverlay, object: nil)
    }
    
    @objc private func closeOverlayFromMenu() {
        print("❌ Close overlay from menu")
        NotificationCenter.default.post(name: .closeFloatingOverlay, object: nil)
    }
}

// Custom floating window
class FloatingOverlayWindow: NSPanel {
    weak var overlayManager: FloatingOverlayManager?
    
    init(overlayManager: FloatingOverlayManager? = nil) {
        self.overlayManager = overlayManager
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 24, height: 24),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        // Window properties
        self.level = .floating  // Stay on top of other windows
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        
        // Make it not activating (clicking won't switch focus to this window)
        self.isMovableByWindowBackground = false
        
        // Set the content view
        self.contentView = NSHostingView(rootView: FloatingOverlayContent(window: self))
        
        print("🪟 FloatingOverlayWindow initialized")
    }
    
    // Don't become key window (preserve focus)
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    
    // Handle mouse down to show menu
    override func mouseDown(with event: NSEvent) {
        print("🖱️ Click detected on floating icon")
        showMenu(at: event.locationInWindow)
    }
    
    private func showMenu(at point: NSPoint) {
        // Convert window point to screen point
        let screenPoint = self.convertToScreen(NSRect(origin: point, size: .zero)).origin
        overlayManager?.showCustomPromptsMenu(at: screenPoint)
    }
}

// SwiftUI content for the floating icon
struct FloatingOverlayContent: View {
    weak var window: FloatingOverlayWindow?
    @State private var isHovered = false
    
    var body: some View {
        ZStack {
            // Main icon button
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.95), Color.purple.opacity(0.95)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            
            // Menu icon (3 lines)
            VStack(spacing: 2) {
                ForEach(0..<3) { _ in
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 10, height: 2)
                        .cornerRadius(1)
                }
            }
        }
        .frame(width: 24, height: 24)
        .clipShape(Circle())
        .contentShape(Circle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// Suggestion popup window
class SuggestionPopupWindow: NSPanel {
    private static let sizeKey = "SuggestionPopupWindowSize"
    private let defaultWidth: CGFloat = 400
    private let defaultHeight: CGFloat = 280
    private let minWidth: CGFloat = 300
    private let minHeight: CGFloat = 200
    
    init(title: String = "Grammar Suggestion") {
        // Load saved size from UserDefaults
        let savedSize = SuggestionPopupWindow.loadSavedSize()
        let width = savedSize.width > 0 ? savedSize.width : defaultWidth
        let height = savedSize.height > 0 ? savedSize.height : defaultHeight
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        self.title = title
        self.level = .floating
        self.backgroundColor = .windowBackgroundColor
        self.isOpaque = true
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.minSize = NSSize(width: minWidth, height: minHeight)
        
        // Set delegate to save size when resized
        self.delegate = self
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    private static func loadSavedSize() -> NSSize {
        let userDefaults = UserDefaults.standard
        let width = userDefaults.double(forKey: "\(sizeKey)_width")
        let height = userDefaults.double(forKey: "\(sizeKey)_height")
        return NSSize(width: width, height: height)
    }
    
    private func saveSize(_ size: NSSize) {
        let userDefaults = UserDefaults.standard
        userDefaults.set(size.width, forKey: "\(SuggestionPopupWindow.sizeKey)_width")
        userDefaults.set(size.height, forKey: "\(SuggestionPopupWindow.sizeKey)_height")
        userDefaults.synchronize()
        print("💾 Saved popup size: \(size.width) x \(size.height)")
    }
}

// MARK: - NSWindowDelegate
extension SuggestionPopupWindow: NSWindowDelegate {
    func windowDidResize(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            let newSize = window.frame.size
            saveSize(newSize)
        }
    }
}

// Notification names
extension Notification.Name {
    static let captureTextFromOverlay = Notification.Name("captureTextFromOverlay")
    static let closeFloatingOverlay = Notification.Name("closeFloatingOverlay")
    static let showSuggestionResult = Notification.Name("showSuggestionResult")
}

