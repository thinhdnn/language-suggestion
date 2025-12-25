//
//  MenuBarManager.swift
//  LanguageSuggestion
//
//  Menu bar icon manager for background operation
//

import SwiftUI
import AppKit

class MenuBarManager: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    @Published var isWindowVisible = true
    private var settingsManager: SettingsManager?
    private var settingsWindow: NSWindow?
    
    func setupMenuBar(settingsManager: SettingsManager? = nil) {
        self.settingsManager = settingsManager
        
        // Listen for custom prompts changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildMenu),
            name: .customPromptsChanged,
            object: nil
        )
        print("🎯 MenuBarManager: Setting up menu bar...")
        
        // Set app to regular mode (shows dock icon and menu bar)
        NSApp.setActivationPolicy(.regular)
        print("✅ Activation policy set to .regular (dock icon enabled)")
        
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        print("✅ Status item created: \(statusItem != nil)")
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: "LanguageSuggestion")
            button.image?.isTemplate = true
            print("✅ Button image set: \(button.image != nil)")
        } else {
            print("❌ Failed to get status item button")
        }
        
        buildMenu()
        
        print("✅ Menu set to status item")
        print("🎉 Menu bar setup COMPLETE! Icon should be visible in menu bar now.")
        print("📍 Look for ⭐ icon in top-right menu bar (near WiFi/Battery/Clock)")
    }
    
    @objc private func rebuildMenu() {
        print("🔄 Rebuilding menu with updated custom prompts...")
        buildMenu()
    }
    
    private func buildMenu() {
        // Create menu
        let menu = NSMenu()
        print("✅ Menu created")
        
        // Open LanguageSuggestion (always show)
        let openItem = NSMenuItem(
            title: "Open LanguageSuggestion",
            action: #selector(showWindow),
            keyEquivalent: "o"
        )
        openItem.target = self
        menu.addItem(openItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Custom prompts section
        if let settingsManager = settingsManager, !settingsManager.customPrompts.isEmpty {
            for customPrompt in settingsManager.customPrompts {
                let promptItem = NSMenuItem(
                    title: customPrompt.name,
                    action: #selector(executeCustomPrompt(_:)),
                    keyEquivalent: customPrompt.keyEquivalent.lowercased()
                )
                promptItem.target = self
                promptItem.representedObject = customPrompt
                menu.addItem(promptItem)
            }
            
            menu.addItem(NSMenuItem.separator())
        }
        
        // Show/Hide Window
        let showHideItem = NSMenuItem(
            title: isWindowVisible ? "Hide Window" : "Show Window",
            action: #selector(toggleWindow),
            keyEquivalent: "w"
        )
        showHideItem.target = self
        menu.addItem(showHideItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // About
        let aboutItem = NSMenuItem(
            title: "About LanguageSuggestion",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(
            title: "Quit LanguageSuggestion",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc func executeCustomPrompt(_ sender: NSMenuItem) {
        guard let customPrompt = sender.representedObject as? CustomPrompt else {
            print("❌ No custom prompt found in menu item")
            return
        }
        
        print("🚀 Executing custom prompt: \(customPrompt.name)")
        
        // Post notification with the custom prompt
        NotificationCenter.default.post(
            name: .executeCustomPrompt,
            object: nil,
            userInfo: ["customPrompt": customPrompt]
        )
    }
    
    @objc func showWindow() {
        print("🔵 Opening LanguageSuggestion window...")
        
        // Find the main window
        let mainWindow = NSApplication.shared.windows.first { window in
            window.styleMask.contains(.titled) && !window.styleMask.contains(.nonactivatingPanel)
        }
        
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            isWindowVisible = true
            
            // Update menu item
            if let menu = statusItem?.menu,
               let items = menu.items as [NSMenuItem]?,
               let showHideItem = items.first(where: { $0.action == #selector(toggleWindow) }) {
                showHideItem.title = "Hide Window"
            }
            
            print("✅ Window opened")
        } else {
            print("⚠️ No main window found")
        }
    }
    
    @objc func toggleWindow() {
        isWindowVisible.toggle()
        
        // Find the main window (not panels or floating windows)
        let mainWindow = NSApplication.shared.windows.first { window in
            window.styleMask.contains(.titled) && !window.styleMask.contains(.nonactivatingPanel)
        }
        
        if isWindowVisible {
            print("🔵 Showing window...")
            NSApplication.shared.activate(ignoringOtherApps: true)
            if let window = mainWindow {
                window.makeKeyAndOrderFront(nil)
                print("✅ Main window shown")
            } else {
                print("⚠️ No main window found")
            }
        } else {
            print("⚪️ Hiding window...")
            mainWindow?.orderOut(nil)
        }
        
        // Update menu item title
        if let menu = statusItem?.menu,
           let firstItem = menu.items.first {
            firstItem.title = isWindowVisible ? "Hide Window" : "Show Window"
        }
    }
    
    @objc func openSettings() {
        print("⚙️ Opening settings window...")
        
        // If settings window already exists, just bring it to front
        if let existingWindow = settingsWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            print("✅ Settings window brought to front")
            return
        }
        
        // Create new settings window
        guard let settingsManager = settingsManager else {
            print("❌ No settings manager available")
            return
        }
        
        let settingsView = SettingsView()
            .environmentObject(settingsManager)
        
        let hostingController = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 700, height: 600))
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .normal
        window.collectionBehavior = [.managed]
        
        // Handle window close
        window.delegate = self
        
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        print("✅ Settings window created and shown")
    }
    
    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "LanguageSuggestion"
        alert.informativeText = """
        Version 1.0
        
        AI-powered grammar correction and translation tool.
        
        Features:
        • Fix grammar with AI
        • Translate text
        • Teams integration
        • Floating overlay for quick access
        
        © 2024 LanguageSuggestion
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc func quit() {
        print("👋 Quitting LanguageSuggestion")
        NSApplication.shared.terminate(nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }
}

// MARK: - NSWindowDelegate
extension MenuBarManager: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == settingsWindow {
            print("🔴 Settings window closed")
            settingsWindow = nil
        }
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == settingsWindow {
            print("✅ Settings window became key")
        }
    }
    
    func windowDidResignKey(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == settingsWindow {
            print("⚠️ Settings window resigned key (but not closed)")
        }
    }
}

// Notification names
extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let customPromptsChanged = Notification.Name("customPromptsChanged")
    static let executeCustomPrompt = Notification.Name("executeCustomPrompt")
}

