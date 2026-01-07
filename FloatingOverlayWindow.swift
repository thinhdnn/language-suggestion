//
//  FloatingOverlayWindow.swift
//  LanguageSuggestion
//
//  Floating icon overlay for quick text capture from Teams
//

import SwiftUI
import AppKit
import Observation
import OSLog

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
    private var workspaceObserver: NSObjectProtocol?
    private var appLaunchObserver: NSObjectProtocol?
    private var appTerminateObserver: NSObjectProtocol?
    private var targetElement: AccessibleElement?
    private var accessibilityService: AccessibilityService?
    private var currentApp: SupportedApp = .teams
    private var settingsManager: SettingsManager?
    
    // Logger for console output
    private let logger = Logger(subsystem: "com.languagesuggestion", category: "FloatingOverlay")
    
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
        overlayWindow?.orderFrontRegardless()  // Force to front even if app is not active
        isOverlayVisible = true
        
        logger.info("✅ Overlay window created and shown")
        logger.info("   Window level: \(self.overlayWindow?.level.rawValue ?? 0)")
        logger.info("   Window frame: \(self.overlayWindow?.frame.debugDescription ?? "nil")")
        logger.info("   Window is visible: \(self.overlayWindow?.isVisible ?? false)")
        
        // Start monitoring Teams window state and position
        startMonitoring()
    }
    
    func hideOverlay() {
        stopMonitoring()
        overlayWindow?.close()
        overlayWindow = nil
        isOverlayVisible = false
        logger.info("🔴 Overlay hidden")
    }
    
    private func updateOverlayPosition(for element: AccessibleElement) {
        guard let position = element.position, let size = element.size else {
            logger.warning("⚠️ Cannot update overlay position - missing position or size")
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
        
        logger.debug("📍 Positioning overlay:")
        logger.debug("   Text area (Accessibility): (\(position.x), \(position.y))")
        logger.debug("   Text area size: \(size.width) x \(size.height)")
        logger.debug("   Screen height: \(screenHeight)")
        logger.debug("   Icon position (NSWindow): (\(iconX), \(iconY))")
        
        overlayWindow?.setFrameOrigin(CGPoint(x: iconX, y: iconY))
        overlayWindow?.setContentSize(CGSize(width: iconSize, height: iconSize))
        
        // Ensure window is visible after position update
        overlayWindow?.orderFrontRegardless()
        
        // Save position for current app
        savePositionForCurrentApp(iconX: iconX, iconY: iconY)
        
        // Log visibility status for debugging
        logger.debug("   Window is visible: \(self.overlayWindow?.isVisible ?? false)")
        logger.debug("   Window level: \(self.overlayWindow?.level.rawValue ?? 0)")
    }
    
    // Save position for current app
    private func savePositionForCurrentApp(iconX: CGFloat, iconY: CGFloat) {
        let key = "overlay_position_\(currentApp.rawValue)"
        let userDefaults = UserDefaults.standard
        userDefaults.set(iconX, forKey: "\(key)_x")
        userDefaults.set(iconY, forKey: "\(key)_y")
        userDefaults.synchronize()
        logger.info("💾 Saved position for \(self.currentApp.rawValue): (\(iconX), \(iconY))")
    }
    
    // Load saved position for app
    private func loadPositionForApp(_ app: SupportedApp) -> CGPoint? {
        let key = "overlay_position_\(app.rawValue)"
        let userDefaults = UserDefaults.standard
        let x = userDefaults.double(forKey: "\(key)_x")
        let y = userDefaults.double(forKey: "\(key)_y")
        
        // Return nil if position was never saved (both are 0)
        if x == 0 && y == 0 {
            return nil
        }
        
        logger.info("📂 Loaded saved position for \(app.rawValue): (\(x), \(y))")
        return CGPoint(x: x, y: y)
    }
    
    private func startMonitoring() {
        stopMonitoring()
        
        let workspace = NSWorkspace.shared
        
        // Listen to app activation changes (immediate response)
        workspaceObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: workspace,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            self.handleAppActivationChange()
        }
        
        // Listen to app launch (when app is opened)
        appLaunchObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: workspace,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleId = app.bundleIdentifier else { return }
            
            // Check if launched app is a supported app
            if SupportedApp.teams.bundleIdentifiers.contains(bundleId) ||
               SupportedApp.notes.bundleIdentifiers.contains(bundleId) {
                logger.info("🚀 Supported app launched: \(bundleId)")
                // Wait a bit for app to fully initialize, then check
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.handleAppActivationChange()
                }
            }
        }
        
        // Listen to app termination (when app is closed)
        appTerminateObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: workspace,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleId = app.bundleIdentifier else { return }
            
            // Check if terminated app was the current app
            let wasCurrentApp = (self.currentApp == .teams && SupportedApp.teams.bundleIdentifiers.contains(bundleId)) ||
                                (self.currentApp == .notes && SupportedApp.notes.bundleIdentifiers.contains(bundleId))
            
            if wasCurrentApp {
                logger.info("🔴 Current app (\(bundleId)) was terminated - checking for other supported apps")
                // Reset current app and check for other supported apps
                self.currentApp = .teams // Reset to default
                self.handleAppActivationChange()
            }
        }
        
        // Also use timer as backup to check periodically (in case notification is missed)
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.checkAndUpdateOverlayPosition()
        }
        
        // Initial check
        checkAndUpdateOverlayPosition()
    }
    
    private func handleAppActivationChange() {
        logger.debug("🔄 App activation changed - checking overlay position")
        checkAndUpdateOverlayPosition()
    }
    
    private func checkAndUpdateOverlayPosition() {
        guard let accessibilityService = self.accessibilityService else {
            logger.warning("⚠️ No accessibility service available")
            return
        }
        
        // Check which supported app is active
        let activeApp = self.getActiveSupportedApp()
        
        logger.info("🔍 Monitor check - Active app: \(activeApp?.rawValue ?? "none")")
        
        // Check if Teams is running
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        let teamsRunning = runningApps.contains { app in
            app.bundleIdentifier == "com.microsoft.teams" ||
            app.bundleIdentifier == "com.microsoft.teams2"
        }
        logger.info("   Teams running: \(teamsRunning)")
        
        if let activeApp = activeApp {
            // Check if app has changed
            let appChanged = self.currentApp != activeApp
            self.currentApp = activeApp
            
            if !self.isOverlayVisible {
                logger.info("✅ \(activeApp.rawValue) became active - showing overlay")
                
                // Try to load saved position first
                if let savedPosition = self.loadPositionForApp(activeApp) {
                    logger.info("📍 Restoring saved position for \(activeApp.rawValue)")
                    self.overlayWindow?.setFrameOrigin(savedPosition)
                }
                
                // Use makeKeyAndOrderFront and orderFrontRegardless to ensure visibility
                self.overlayWindow?.makeKeyAndOrderFront(nil)
                self.overlayWindow?.orderFrontRegardless()
                self.isOverlayVisible = true
                logger.info("   Window is visible: \(self.overlayWindow?.isVisible ?? false)")
            } else if appChanged {
                logger.info("🔄 App changed to \(activeApp.rawValue) - updating position immediately")
                
                // Try to load saved position first when app changes
                if let savedPosition = self.loadPositionForApp(activeApp) {
                    logger.info("📍 Restoring saved position for \(activeApp.rawValue)")
                    self.overlayWindow?.setFrameOrigin(savedPosition)
                }
                
                // Ensure window is visible when app changes
                self.overlayWindow?.orderFrontRegardless()
            }
            
            // Always update position when app is active (especially when app changes)
            // If app changed, we MUST update position even if text area not found yet
            self.updatePositionForApp(activeApp, accessibilityService: accessibilityService, forceUpdate: appChanged)
        } else {
            // No supported app is active - hide overlay
            if self.isOverlayVisible {
                logger.info("🔴 Supported app became inactive - hiding overlay")
                self.overlayWindow?.orderOut(nil)
                self.isOverlayVisible = false
            }
        }
    }
    
    private func updatePositionForApp(_ app: SupportedApp, accessibilityService: AccessibilityService, forceUpdate: Bool = false, retryCount: Int = 0) {
        logger.info("🔍 updatePositionForApp called for \(app.rawValue), forceUpdate: \(forceUpdate), retryCount: \(retryCount)")
        
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let textArea: AccessibleElement?
            
            switch app {
            case .teams:
                self.logger.info("🔍 Scanning Teams compose box with maxDepth: 30...")
                textArea = accessibilityService.findTeamsComposeBox(maxDepth: 30)
            case .notes:
                self.logger.info("🔍 Scanning Notes text area with maxDepth: 30...")
                textArea = accessibilityService.findNotesTextArea(maxDepth: 30)
            }
            
            if let textArea = textArea {
                DispatchQueue.main.async { [self] in
                    self.logger.info("✅ Found text area for \(app.rawValue)")
                    self.logger.info("   Position: \(textArea.position?.debugDescription ?? "nil")")
                    self.logger.info("   Size: \(textArea.size?.debugDescription ?? "nil")")
                    self.logger.info("📍 Updating overlay position for \(app.rawValue)")
                    self.updateOverlayPosition(for: textArea)
                    self.targetElement = textArea
                    
                    // Ensure window is visible after position update
                    self.overlayWindow?.orderFrontRegardless()
                    self.logger.info("   Window is visible: \(self.overlayWindow?.isVisible ?? false)")
                }
            } else {
                self.logger.warning("⚠️ Could not find text area for \(app.rawValue)")
                self.logger.warning("   This might mean:")
                self.logger.warning("   1. \(app.rawValue) is not running")
                self.logger.warning("   2. Chat box/compose area is not open")
                self.logger.warning("   3. Accessibility permission not granted")
                self.logger.warning("   4. UI structure changed")
                
                // If app changed and we can't find text area, retry a few times
                // This handles the case when app just launched and UI isn't ready yet
                if forceUpdate && retryCount < 3 {
                    self.logger.debug("🔄 Retrying to find text area for \(app.rawValue) (attempt \(retryCount + 1)/3)...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.updatePositionForApp(app, accessibilityService: accessibilityService, forceUpdate: true, retryCount: retryCount + 1)
                    }
                } else if forceUpdate {
                    self.logger.error("❌ Failed to find text area for \(app.rawValue) after retries - overlay may be at wrong position")
                    // Even if we can't find the text area, try to show overlay at saved position
                    DispatchQueue.main.async { [self] in
                        if let savedPosition = self.loadPositionForApp(app) {
                            self.logger.info("📍 Showing overlay at saved position: \(savedPosition.debugDescription)")
                            self.overlayWindow?.setFrameOrigin(savedPosition)
                            self.overlayWindow?.orderFrontRegardless()
                            self.isOverlayVisible = true
                        }
                    }
                }
            }
        }
    }
    
    private func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        
        if let observer = workspaceObserver {
            NotificationCenter.default.removeObserver(observer)
            workspaceObserver = nil
        }
        
        if let observer = appLaunchObserver {
            NotificationCenter.default.removeObserver(observer)
            appLaunchObserver = nil
        }
        
        if let observer = appTerminateObserver {
            NotificationCenter.default.removeObserver(observer)
            appTerminateObserver = nil
        }
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
            logger.warning("⚠️ No settings manager available")
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
        
        // Add "Recheck size" option
        let recheckItem = NSMenuItem(
            title: "Recheck size",
            action: #selector(recheckSize),
            keyEquivalent: ""
        )
        recheckItem.target = self
        recheckItem.isEnabled = true
        menu.addItem(recheckItem)
        
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
            logger.error("❌ No custom prompt found")
            return
        }
        
        logger.info("🚀 Executing custom prompt from floating icon: \(customPrompt.name)")
        
        // Post notification with the custom prompt
        NotificationCenter.default.post(
            name: .executeCustomPrompt,
            object: nil,
            userInfo: ["customPrompt": customPrompt]
        )
    }
    
    @objc private func captureAndFixGrammar() {
        logger.info("🔧 Capture and fix grammar from floating icon")
        // Send notification to capture text (default behavior)
        NotificationCenter.default.post(name: .captureTextFromOverlay, object: nil)
    }
    
    @objc private func closeOverlayFromMenu() {
        logger.info("❌ Close overlay from menu")
        NotificationCenter.default.post(name: .closeFloatingOverlay, object: nil)
    }
    
    @objc private func recheckSize() {
        logger.info("🔍 Recheck size requested for \(self.currentApp.rawValue)")
        guard let accessibilityService = self.accessibilityService else {
            logger.error("❌ No accessibility service available")
            return
        }
        
        // Scan with depth 30 for more thorough search
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let textArea: AccessibleElement?
            
            switch self.currentApp {
            case .teams:
                self.logger.info("🔍 Scanning Teams compose box with depth 30...")
                textArea = accessibilityService.findTeamsComposeBox(maxDepth: 30)
            case .notes:
                self.logger.info("🔍 Scanning Notes text area with depth 30...")
                textArea = accessibilityService.findNotesTextArea(maxDepth: 30)
            }
            
            if let textArea = textArea {
                DispatchQueue.main.async { [self] in
                    self.logger.info("✅ Found text area for \(self.currentApp.rawValue) - updating position")
                    self.updateOverlayPosition(for: textArea)
                    self.targetElement = textArea
                }
            } else {
                DispatchQueue.main.async { [self] in
                    self.logger.error("❌ Could not find text area for \(self.currentApp.rawValue) even with depth 30")
                }
            }
        }
    }
}

// Custom floating window
class FloatingOverlayWindow: NSPanel {
    weak var overlayManager: FloatingOverlayManager?
    private let logger = Logger(subsystem: "com.languagesuggestion", category: "FloatingOverlayWindow")
    
    init(overlayManager: FloatingOverlayManager? = nil) {
        self.overlayManager = overlayManager
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 24, height: 24),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        // Window properties
        // Use .popUpMenu level to ensure it shows above Teams windows (Electron apps)
        // This is higher than .floating but lower than .statusBar
        self.level = .popUpMenu
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        // Remove .stationary as it can prevent window from showing properly
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Make it not activating (clicking won't switch focus to this window)
        self.isMovableByWindowBackground = false
        self.ignoresMouseEvents = false  // Ensure it can receive clicks
        
        // Set the content view
        self.contentView = NSHostingView(rootView: FloatingOverlayContent(window: self))
        
        logger.info("🪟 FloatingOverlayWindow initialized")
    }
    
    // Don't become key window (preserve focus)
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    
    // Handle mouse down to show menu
    override func mouseDown(with event: NSEvent) {
        logger.debug("🖱️ Click detected on floating icon")
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
    private let logger = Logger(subsystem: "com.languagesuggestion", category: "SuggestionPopupWindow")
    
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
        logger.info("💾 Saved popup size: \(size.width) x \(size.height)")
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

