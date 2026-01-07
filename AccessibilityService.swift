//
//  AccessibilityService.swift
//  LanguageSuggestion
//
//  Service for accessing text from other applications using Accessibility API
//

import ApplicationServices
import AppKit
import Observation

@Observable
final class AccessibilityService {
    var lastError: String?
    var isAccessibilityEnabled: Bool = false
    
    // Use NSLog for debug logs so they always appear in Console.app
    private func debugLog(_ message: String) {
        NSLog("%@", "[AccessibilityService] \(message)")
    }
    
    init() {
        checkAccessibilityPermission()
    }
    
    // Check if accessibility permission is granted (without prompting)
    func checkAccessibilityPermission() -> Bool {
        // Check permission status
        let accessEnabled = AXIsProcessTrusted()
        
        // Update state on main thread
        DispatchQueue.main.async {
            let oldValue = self.isAccessibilityEnabled
            self.isAccessibilityEnabled = accessEnabled
            
            // Log state change for debugging
            if oldValue != accessEnabled {
                self.debugLog("🔐 Accessibility permission status changed: \(oldValue) -> \(accessEnabled)")
            }
        }
        
        return accessEnabled
    }
    
    // Open System Settings to Accessibility page
    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    // Get text from Teams or any focused text field
    func getTextFromFocusedElement() -> String? {
        guard checkAccessibilityPermission() else {
            lastError = "Accessibility permission not granted. Please enable it in System Preferences > Privacy & Security > Accessibility"
            return nil
        }
        
        // Get the system-wide focused element
        guard let focusedElement = getFocusedElement() else {
            lastError = "No focused element found. Please click on a text field in Teams first."
            return nil
        }
        
        // Try to get text from the focused element
        if let text = getTextFromElement(focusedElement) {
            return text
        }
        
        lastError = "Could not extract text from the focused element."
        return nil
    }
    
    // Get text from Teams application specifically
    func getTextFromTeams() -> String? {
        guard checkAccessibilityPermission() else {
            lastError = "Accessibility permission not granted. Please enable it in System Preferences > Privacy & Security > Accessibility"
            return nil
        }
        
        // Find Microsoft Teams app
        guard let teamsApp = findApplication(bundleIdentifier: "com.microsoft.teams2") ?? 
                            findApplication(bundleIdentifier: "com.microsoft.teams") else {
            lastError = "Microsoft Teams is not running or cannot be found."
            return nil
        }
        
        // Get the focused text field from Teams
        if let text = getTextFromApplication(teamsApp) {
            return text
        }
        
        lastError = "Could not find or extract text from Teams. Please make sure a text field is focused."
        return nil
    }
    
    // Get all text from Teams chat window
    func getAllTextFromTeamsWindow() -> String? {
        guard checkAccessibilityPermission() else {
            lastError = "Accessibility permission not granted."
            return nil
        }
        
        guard let teamsApp = findApplication(bundleIdentifier: "com.microsoft.teams2") ?? 
                            findApplication(bundleIdentifier: "com.microsoft.teams") else {
            lastError = "Microsoft Teams is not running."
            return nil
        }
        
        // Try to get all text content
        var allText = [String]()
        
        // Get windows
        var windowsValue: CFTypeRef?
        let windowsResult = AXUIElementCopyAttributeValue(teamsApp, kAXWindowsAttribute as CFString, &windowsValue)
        
        if windowsResult == .success, let windows = windowsValue as? [AXUIElement] {
            for window in windows {
                // Get focused window
                var focusedValue: CFTypeRef?
                let focusedResult = AXUIElementCopyAttributeValue(window, kAXFocusedAttribute as CFString, &focusedValue)
                
                if focusedResult == .success, let focused = focusedValue as? Bool, focused {
                    // Search for text fields in this window
                    if let text = searchForTextInElement(window) {
                        allText.append(text)
                    }
                }
            }
        }
        
        if !allText.isEmpty {
            return allText.joined(separator: "\n")
        }
        
        lastError = "Could not find text in Teams window."
        return nil
    }
    
    // MARK: - Private Helper Methods
    
    private func getFocusedElement() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        
        // Get the currently focused application
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        
        guard result == .success, let app = focusedApp else {
            return nil
        }
        
        // Get the focused UI element within that app
        var focusedElement: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        if focusResult == .success, let element = focusedElement {
            return element as! AXUIElement
        }
        
        return nil
    }
    
    private func findApplication(bundleIdentifier: String) -> AXUIElement? {
        let runningApps = NSWorkspace.shared.runningApplications
        
        for app in runningApps {
            if app.bundleIdentifier == bundleIdentifier {
                let pid = app.processIdentifier
                return AXUIElementCreateApplication(pid)
            }
        }
        
        return nil
    }
    
    private func getTextFromElement(_ element: AXUIElement) -> String? {
        // Try to get selected text first
        var selectedTextValue: CFTypeRef?
        let selectedResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedTextValue)
        
        if selectedResult == .success, let selectedText = selectedTextValue as? String, !selectedText.isEmpty {
            return selectedText
        }
        
        // Try to get all text value
        var textValue: CFTypeRef?
        let valueResult = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &textValue)
        
        if valueResult == .success, let text = textValue as? String {
            return text
        }
        
        // Try to get title
        var titleValue: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue)
        
        if titleResult == .success, let title = titleValue as? String {
            return title
        }
        
        return nil
    }
    
    private func getTextFromApplication(_ app: AXUIElement) -> String? {
        // Get the focused element in the app
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        if result == .success, let element = focusedElement as! AXUIElement? {
            return getTextFromElement(element)
        }
        
        return nil
    }
    
    private func searchForTextInElement(_ element: AXUIElement) -> String? {
        // Try to get text from this element
        if let text = getTextFromElement(element), !text.isEmpty {
            return text
        }
        
        // Get children and search recursively
        var childrenValue: CFTypeRef?
        let childrenResult = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue)
        
        if childrenResult == .success, let children = childrenValue as? [AXUIElement] {
            for child in children {
                if let text = searchForTextInElement(child) {
                    return text
                }
            }
        }
        
        return nil
    }
    
    // Get role of an element (for debugging)
    func getElementRole(_ element: AXUIElement) -> String? {
        var roleValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        
        if result == .success, let role = roleValue as? String {
            return role
        }
        
        return nil
    }
    
    // Debug: Print element information
    func debugElement(_ element: AXUIElement, depth: Int = 0) {
        let indent = String(repeating: "  ", count: depth)
        
        // Get role
        if let role = getElementRole(element) {
            print("\(indent)Role: \(role)")
        }
        
        // Get value
        if let value = getTextFromElement(element) {
            print("\(indent)Value: \(value)")
        }
        
        // Get children
        var childrenValue: CFTypeRef?
        let childrenResult = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue)
        
        if childrenResult == .success, let children = childrenValue as? [AXUIElement] {
            print("\(indent)Children count: \(children.count)")
            
            // Limit depth to avoid infinite recursion
            if depth < 3 {
                for child in children {
                    debugElement(child, depth: depth + 1)
                }
            }
        }
    }
    
    // Get all visible elements from Teams with detailed information
    func getAllTeamsElements(maxDepth: Int = 10) -> [AccessibleElement] {
        debugLog("🔍 getAllTeamsElements called with maxDepth: \(maxDepth)")
        
        guard checkAccessibilityPermission() else {
            lastError = "Accessibility permission not granted."
            debugLog("❌ Accessibility permission not granted")
            return []
        }
        
        guard let teamsApp = findApplication(bundleIdentifier: "com.microsoft.teams2") ?? 
                            findApplication(bundleIdentifier: "com.microsoft.teams") else {
            lastError = "Microsoft Teams is not running."
            debugLog("❌ Microsoft Teams is not running")
            return []
        }
        
        var allElements: [AccessibleElement] = []
        
        // Try to get focused window first (more efficient)
        var focusedWindowValue: CFTypeRef?
        let focusedWindowResult = AXUIElementCopyAttributeValue(teamsApp, kAXFocusedWindowAttribute as CFString, &focusedWindowValue)
        
        if focusedWindowResult == .success, let focusedWindowCF = focusedWindowValue {
            let focusedWindow = focusedWindowCF as! AXUIElement
            debugLog("✅ Found focused window, scanning from focused window")
            collectElements(from: focusedWindow, depth: 0, maxDepth: maxDepth, elements: &allElements)
            debugLog("📊 Found \(allElements.count) elements from focused window")
        } else {
            debugLog("⚠️ No focused window, scanning all windows")
            
            // Fallback: scan all windows
            var windowsValue: CFTypeRef?
            let windowsResult = AXUIElementCopyAttributeValue(teamsApp, kAXWindowsAttribute as CFString, &windowsValue)
            
            if windowsResult == .success, let windows = windowsValue as? [AXUIElement] {
                debugLog("📊 Found \(windows.count) windows")
                for (index, window) in windows.enumerated() {
                    debugLog("   Scanning window \(index + 1)/\(windows.count)")
                    collectElements(from: window, depth: 0, maxDepth: maxDepth, elements: &allElements)
                }
            } else {
                debugLog("⚠️ Could not get windows, scanning from app level")
                collectElements(from: teamsApp, depth: 0, maxDepth: maxDepth, elements: &allElements)
            }
        }
        
        debugLog("✅ Total elements collected: \(allElements.count)")
        return allElements
    }
    
    // Recursively collect all elements
    private func collectElements(from element: AXUIElement, depth: Int, maxDepth: Int, elements: inout [AccessibleElement]) {
        // Prevent infinite recursion
        guard depth < maxDepth else { return }
        
        // Get element information
        let elementInfo = getElementInfo(element, depth: depth)
        elements.append(elementInfo)
        
        // Log AXTextArea elements found (for debugging)
        if elementInfo.role == "AXTextArea" {
            debugLog("   Found AXTextArea at depth \(depth): pos=\(elementInfo.position?.debugDescription ?? "nil"), size=\(elementInfo.size?.debugDescription ?? "nil"), title=\(elementInfo.title ?? "nil")")
        }
        
        // Get children
        var childrenValue: CFTypeRef?
        let childrenResult = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue)
        
        if childrenResult == .success, let children = childrenValue as? [AXUIElement] {
            for child in children {
                collectElements(from: child, depth: depth + 1, maxDepth: maxDepth, elements: &elements)
            }
        } else if depth == 0 {
            // Log if we can't get children at root level
            debugLog("⚠️ Could not get children at depth 0, result: \(childrenResult)")
        }
    }
    
    // Get detailed information about an element
    private func getElementInfo(_ element: AXUIElement, depth: Int) -> AccessibleElement {
        let role = getElementRole(element) ?? "Unknown"
        let value = getTextFromElement(element)
        let title = getElementTitle(element)
        let elementDescription = getElementDescription(element)
        let identifier = getElementIdentifier(element)
        let position = getElementPosition(element)
        let size = getElementSize(element)
        let enabled = isElementEnabled(element)
        let focused = isElementFocused(element)
        
        return AccessibleElement(
            role: role,
            title: title,
            value: value,
            elementDescription: elementDescription,
            identifier: identifier,
            position: position,
            size: size,
            depth: depth,
            enabled: enabled,
            focused: focused
        )
    }
    
    // Helper functions to get element attributes
    private func getElementTitle(_ element: AXUIElement) -> String? {
        var titleValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue)
        return result == .success ? titleValue as? String : nil
    }
    
    private func getElementDescription(_ element: AXUIElement) -> String? {
        var descValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descValue)
        return result == .success ? descValue as? String : nil
    }
    
    private func getElementIdentifier(_ element: AXUIElement) -> String? {
        var idValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &idValue)
        return result == .success ? idValue as? String : nil
    }
    
    private func getElementPosition(_ element: AXUIElement) -> CGPoint? {
        var posValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue)
        if result == .success, let axValue = posValue {
            var point = CGPoint.zero
            if AXValueGetValue(axValue as! AXValue, .cgPoint, &point) {
                return point
            }
        }
        return nil
    }
    
    private func getElementSize(_ element: AXUIElement) -> CGSize? {
        var sizeValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)
        if result == .success, let axValue = sizeValue {
            var size = CGSize.zero
            if AXValueGetValue(axValue as! AXValue, .cgSize, &size) {
                return size
            }
        }
        return nil
    }
    
    private func isElementEnabled(_ element: AXUIElement) -> Bool {
        var enabledValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &enabledValue)
        return result == .success ? (enabledValue as? Bool ?? false) : false
    }
    
    private func isElementFocused(_ element: AXUIElement) -> Bool {
        var focusedValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXFocusedAttribute as CFString, &focusedValue)
        return result == .success ? (focusedValue as? Bool ?? false) : false
    }
    
    // Get elements by role (useful for filtering)
    func getTeamsElementsByRole(_ targetRole: String, maxDepth: Int = 10) -> [AccessibleElement] {
        let allElements = getAllTeamsElements(maxDepth: maxDepth)
        return allElements.filter { $0.role == targetRole }
    }
    
    // Get all text fields in Teams
    func getAllTeamsTextFields() -> [AccessibleElement] {
        return getTeamsElementsByRole("AXTextField")
    }
    
    // Get all buttons in Teams
    func getAllTeamsButtons() -> [AccessibleElement] {
        return getTeamsElementsByRole("AXButton")
    }
    
    // Get all text areas (multiline text) in Teams
    func getAllTeamsTextAreas() -> [AccessibleElement] {
        return getTeamsElementsByRole("AXTextArea")
    }
    
    // Find Teams compose box specifically with multiple strategies
    func findTeamsComposeBox(maxDepth: Int = 25) -> AccessibleElement? {
        debugLog("🔍 Finding Teams compose box (maxDepth: \(maxDepth))")
        debugLog(String(repeating: "=", count: 60))
        
        guard checkAccessibilityPermission() else {
            lastError = "Accessibility permission not granted."
            debugLog("❌ Accessibility permission not granted")
            return nil
        }
        
        // Get all AXTextArea elements from Teams
        let textAreas = getTeamsElementsByRole("AXTextArea", maxDepth: maxDepth)
        debugLog("📊 Found \(textAreas.count) AXTextArea elements")
        
        // Also check AXTextField (Teams might use either)
        let textFields = getTeamsElementsByRole("AXTextField", maxDepth: maxDepth)
        debugLog("📊 Found \(textFields.count) AXTextField elements")
        
        // Combine both types
        let allTextElements = textAreas + textFields
        debugLog("📊 Total text elements: \(allTextElements.count)")
        
        if allTextElements.isEmpty {
            debugLog("❌ No text elements (AXTextArea or AXTextField) found")
            debugLog("💡 Make sure:")
            debugLog("   1. Teams is running")
            debugLog("   2. A chat/conversation is open")
            debugLog("   3. Click in the compose box")
            debugLog(String(repeating: "=", count: 60))
            return nil
        }
        
        // Strategy 1: Look for keywords in title, value, or description
        let keywords = ["type a message", "compose", "message-editor", "ck-editor", "ckeditor", "message", "type"]
        debugLog("🎯 Strategy 1: Searching for keywords: \(keywords.joined(separator: ", "))")
        for textArea in allTextElements {
            let title = textArea.title?.lowercased() ?? ""
            let value = textArea.value?.lowercased() ?? ""
            let desc = textArea.elementDescription?.lowercased() ?? ""
            let identifier = textArea.identifier?.lowercased() ?? ""
            
            for keyword in keywords {
                if title.contains(keyword) || 
                   value.contains(keyword) || 
                   desc.contains(keyword) ||
                   identifier.contains(keyword) {
                    debugLog("✅ Found compose box by keyword '\(keyword)'")
                    debugLog("   Title: \(textArea.title ?? "nil")")
                    debugLog("   Position: \(textArea.position?.debugDescription ?? "nil")")
                    debugLog("   Size: \(textArea.size?.debugDescription ?? "nil")")
                    return textArea
                }
            }
        }
        
        debugLog("⚠️ No compose box found by keyword, trying focus detection...")
        
        // Strategy 2: Look for focused text area
        debugLog("🎯 Strategy 2: Looking for focused text element...")
        for textArea in allTextElements {
            if textArea.focused {
                debugLog("✅ Found compose box by focus")
                debugLog("   Title: \(textArea.title ?? "nil")")
                debugLog("   Position: \(textArea.position?.debugDescription ?? "nil")")
                debugLog("   Size: \(textArea.size?.debugDescription ?? "nil")")
                return textArea
            }
        }
        
        debugLog("⚠️ No focused text area, using largest text element as fallback...")
        
        // Strategy 3: Fallback - use the largest text element (compose box is usually large)
        debugLog("🎯 Strategy 3: Using largest text element as fallback...")
        let sortedBySize = allTextElements
            .filter { $0.size != nil }
            .sorted { ($0.size!.width * $0.size!.height) > ($1.size!.width * $1.size!.height) }
        
        if let largest = sortedBySize.first {
            debugLog("✅ Using largest text element as compose box")
            debugLog("   Role: \(largest.role)")
            debugLog("   Size: \(largest.size?.width ?? 0) x \(largest.size?.height ?? 0)")
            debugLog("   Position: \(largest.position?.debugDescription ?? "nil")")
            debugLog("   Title: \(largest.title ?? "nil")")
            debugLog(String(repeating: "=", count: 60))
            return largest
        }
        
        debugLog("❌ Could not determine compose box")
        debugLog("💡 Debug info:")
        debugLog("   - Total elements scanned: \(allTextElements.count)")
        for (index, element) in allTextElements.prefix(5).enumerated() {
            debugLog("   Element \(index + 1): role=\(element.role), size=\(element.size?.debugDescription ?? "nil"), title=\(element.title ?? "nil")")
        }
        debugLog(String(repeating: "=", count: 60))
        return nil
    }
    
    // MARK: - Notes App Support
    
    // Get all elements from Notes app
    func getAllNotesElements(maxDepth: Int = 10) -> [AccessibleElement] {
        guard checkAccessibilityPermission() else {
            lastError = "Accessibility permission not granted."
            return []
        }
        
        guard let notesApp = findApplication(bundleIdentifier: "com.apple.Notes") else {
            lastError = "Apple Notes is not running."
            return []
        }
        
        var allElements: [AccessibleElement] = []
        collectElements(from: notesApp, depth: 0, maxDepth: maxDepth, elements: &allElements)
        
        return allElements
    }
    
    // Get elements by role from Notes
    func getNotesElementsByRole(_ targetRole: String, maxDepth: Int = 10) -> [AccessibleElement] {
        let allElements = getAllNotesElements(maxDepth: maxDepth)
        return allElements.filter { $0.role == targetRole }
    }
    
    // Find Notes text area (where user writes notes)
    func findNotesTextArea(maxDepth: Int = 25) -> AccessibleElement? {
        debugLog("🔍 Finding Notes text area (maxDepth: \(maxDepth))")
        debugLog(String(repeating: "=", count: 60))
        
        guard checkAccessibilityPermission() else {
            lastError = "Accessibility permission not granted."
            return nil
        }
        
        // Get ALL elements from Notes for detailed analysis
        debugLog("📋 Scanning ALL Notes UI elements...")
        let allElements = getAllNotesElements(maxDepth: maxDepth)
        debugLog("📊 Total elements found: \(allElements.count)")
        debugLog(String(repeating: "=", count: 60))
        
        // Log element type distribution
        var roleCount: [String: Int] = [:]
        for element in allElements {
            roleCount[element.role, default: 0] += 1
        }
        
        debugLog("📊 Element distribution by role:")
        for (role, count) in roleCount.sorted(by: { $0.value > $1.value }) {
            debugLog("   - \(role): \(count)")
        }
        debugLog(String(repeating: "=", count: 60))
        
        // Get all text areas from Notes
        let textAreas = allElements.filter { $0.role == "AXTextArea" }
        debugLog("📊 Found \(textAreas.count) AXTextArea elements in Notes:")
        for (index, textArea) in textAreas.enumerated() {
            debugLog("   TextArea #\(index + 1):")
            debugLog("     - Title: \(textArea.title ?? "nil")")
            debugLog("     - Value: \(textArea.value?.prefix(50) ?? "nil")")
            debugLog("     - Identifier: \(textArea.identifier ?? "nil")")
            debugLog("     - Position: \(textArea.position?.debugDescription ?? "nil")")
            debugLog("     - Size: \(textArea.size?.debugDescription ?? "nil")")
            debugLog("     - Depth: \(textArea.depth)")
            debugLog("     - Focused: \(textArea.focused)")
            debugLog("     - Enabled: \(textArea.enabled)")
        }
        debugLog(String(repeating: "=", count: 60))
        
        // Also check for scroll areas that might contain the text editor
        let scrollAreas = allElements.filter { $0.role == "AXScrollArea" }
        debugLog("📊 Found \(scrollAreas.count) AXScrollArea elements in Notes:")
        for (index, scrollArea) in scrollAreas.enumerated() {
            debugLog("   ScrollArea #\(index + 1):")
            debugLog("     - Title: \(scrollArea.title ?? "nil")")
            debugLog("     - Identifier: \(scrollArea.identifier ?? "nil")")
            debugLog("     - Position: \(scrollArea.position?.debugDescription ?? "nil")")
            debugLog("     - Size: \(scrollArea.size?.debugDescription ?? "nil")")
            debugLog("     - Depth: \(scrollArea.depth)")
            debugLog("     - Focused: \(scrollArea.focused)")
        }
        debugLog(String(repeating: "=", count: 60))
        
        // Check for other potentially relevant roles
        let textFields = allElements.filter { $0.role == "AXTextField" }
        debugLog("📊 Found \(textFields.count) AXTextField elements")
        
        let webAreas = allElements.filter { $0.role == "AXWebArea" }
        debugLog("📊 Found \(webAreas.count) AXWebArea elements")
        
        let groups = allElements.filter { $0.role == "AXGroup" }
        debugLog("📊 Found \(groups.count) AXGroup elements")
        debugLog(String(repeating: "=", count: 60))
        
        if textAreas.isEmpty && scrollAreas.isEmpty {
            debugLog("❌ No text area or scroll area found in Notes")
            debugLog("💡 Try opening a note and clicking in the text editor area")
            return nil
        }
        
        // Strategy 1: Look for focused text area
        debugLog("🎯 Strategy 1: Looking for focused text area...")
        for textArea in textAreas {
            if textArea.focused {
                debugLog("✅ Found Notes text area by focus")
                debugLog("   Title: \(textArea.title ?? "nil")")
                debugLog("   Position: \(textArea.position?.debugDescription ?? "nil")")
                debugLog("   Size: \(textArea.size?.debugDescription ?? "nil")")
                return textArea
            }
        }
        
        debugLog("⚠️ No focused text area found")
        debugLog("🎯 Strategy 2: Looking for largest text area...")
        
        // Strategy 2: Use the largest text area (main content area is usually large)
        let sortedBySize = textAreas
            .filter { $0.size != nil }
            .sorted { ($0.size!.width * $0.size!.height) > ($1.size!.width * $1.size!.height) }
        
        if let largest = sortedBySize.first {
            debugLog("✅ Using largest text area in Notes")
            debugLog("   Size: \(largest.size?.width ?? 0) x \(largest.size?.height ?? 0)")
            debugLog("   Position: \(largest.position?.debugDescription ?? "nil")")
            debugLog("   Title: \(largest.title ?? "nil")")
            return largest
        }
        
        debugLog("⚠️ No suitable text area found")
        debugLog("🎯 Strategy 3: Fallback to largest scroll area...")
        
        // Strategy 3: Fallback to scroll area if no text area found
        let sortedScrollAreas = scrollAreas
            .filter { $0.size != nil }
            .sorted { ($0.size!.width * $0.size!.height) > ($1.size!.width * $1.size!.height) }
        
        if let largestScroll = sortedScrollAreas.first {
            debugLog("✅ Using largest scroll area in Notes as fallback")
            debugLog("   Size: \(largestScroll.size?.width ?? 0) x \(largestScroll.size?.height ?? 0)")
            debugLog("   Position: \(largestScroll.position?.debugDescription ?? "nil")")
            return largestScroll
        }
        
        debugLog(String(repeating: "=", count: 60))
        debugLog("❌ Could not determine Notes text area")
        debugLog("💡 Make sure:")
        debugLog("   1. Notes app is open")
        debugLog("   2. A note is open")
        debugLog("   3. Click in the text editing area")
        debugLog(String(repeating: "=", count: 60))
        return nil
    }
}

// Data model for accessible element
struct AccessibleElement: Identifiable, CustomStringConvertible {
    let id = UUID()
    let role: String
    let title: String?
    let value: String?
    let elementDescription: String?
    let identifier: String?
    let position: CGPoint?
    let size: CGSize?
    let depth: Int
    let enabled: Bool
    let focused: Bool
    
    var description: String {
        var desc = String(repeating: "  ", count: depth)
        desc += "[\(role)]"
        
        if let title = title, !title.isEmpty {
            desc += " title: \"\(title)\""
        }
        
        if let value = value, !value.isEmpty {
            let truncated = value.count > 50 ? String(value.prefix(50)) + "..." : value
            desc += " value: \"\(truncated)\""
        }
        
        if let identifier = identifier {
            desc += " id: \"\(identifier)\""
        }
        
        if let pos = position {
            desc += " pos: (\(Int(pos.x)), \(Int(pos.y)))"
        }
        
        if let size = size {
            desc += " size: (\(Int(size.width))x\(Int(size.height)))"
        }
        
        if focused {
            desc += " [FOCUSED]"
        }
        
        if !enabled {
            desc += " [DISABLED]"
        }
        
        return desc
    }
    
    var shortDescription: String {
        var parts: [String] = [role]
        if let title = title, !title.isEmpty {
            parts.append(title)
        }
        if let value = value, !value.isEmpty {
            let truncated = value.count > 30 ? String(value.prefix(30)) + "..." : value
            parts.append(truncated)
        }
        return parts.joined(separator: " - ")
    }
}

