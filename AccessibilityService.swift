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
    
    init() {
        checkAccessibilityPermission()
    }
    
    // Check if accessibility permission is granted (without prompting)
    func checkAccessibilityPermission() -> Bool {
        let accessEnabled = AXIsProcessTrusted()
        
        DispatchQueue.main.async {
            self.isAccessibilityEnabled = accessEnabled
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
        guard checkAccessibilityPermission() else {
            lastError = "Accessibility permission not granted."
            return []
        }
        
        guard let teamsApp = findApplication(bundleIdentifier: "com.microsoft.teams2") ?? 
                            findApplication(bundleIdentifier: "com.microsoft.teams") else {
            lastError = "Microsoft Teams is not running."
            return []
        }
        
        var allElements: [AccessibleElement] = []
        collectElements(from: teamsApp, depth: 0, maxDepth: maxDepth, elements: &allElements)
        
        return allElements
    }
    
    // Recursively collect all elements
    private func collectElements(from element: AXUIElement, depth: Int, maxDepth: Int, elements: inout [AccessibleElement]) {
        // Prevent infinite recursion
        guard depth < maxDepth else { return }
        
        // Get element information
        let elementInfo = getElementInfo(element, depth: depth)
        elements.append(elementInfo)
        
        // Get children
        var childrenValue: CFTypeRef?
        let childrenResult = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue)
        
        if childrenResult == .success, let children = childrenValue as? [AXUIElement] {
            for child in children {
                collectElements(from: child, depth: depth + 1, maxDepth: maxDepth, elements: &elements)
            }
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
        print("🔍 Finding Teams compose box (maxDepth: \(maxDepth))")
        
        guard checkAccessibilityPermission() else {
            lastError = "Accessibility permission not granted."
            return nil
        }
        
        // Get all AXTextArea elements from Teams
        let textAreas = getTeamsElementsByRole("AXTextArea", maxDepth: maxDepth)
        print("📊 Found \(textAreas.count) AXTextArea elements")
        
        if textAreas.isEmpty {
            print("❌ No AXTextArea found")
            return nil
        }
        
        // Strategy 1: Look for keywords in title, value, or description
        let keywords = ["type a message", "compose", "message-editor", "ck-editor", "ckeditor"]
        for textArea in textAreas {
            let title = textArea.title?.lowercased() ?? ""
            let value = textArea.value?.lowercased() ?? ""
            let desc = textArea.elementDescription?.lowercased() ?? ""
            let identifier = textArea.identifier?.lowercased() ?? ""
            
            for keyword in keywords {
                if title.contains(keyword) || 
                   value.contains(keyword) || 
                   desc.contains(keyword) ||
                   identifier.contains(keyword) {
                    print("✅ Found compose box by keyword '\(keyword)'")
                    print("   Title: \(textArea.title ?? "nil")")
                    print("   Position: \(textArea.position?.debugDescription ?? "nil")")
                    print("   Size: \(textArea.size?.debugDescription ?? "nil")")
                    return textArea
                }
            }
        }
        
        print("⚠️ No compose box found by keyword, trying focus detection...")
        
        // Strategy 2: Look for focused text area
        for textArea in textAreas {
            if textArea.focused {
                print("✅ Found compose box by focus")
                print("   Title: \(textArea.title ?? "nil")")
                print("   Position: \(textArea.position?.debugDescription ?? "nil")")
                print("   Size: \(textArea.size?.debugDescription ?? "nil")")
                return textArea
            }
        }
        
        print("⚠️ No focused text area, using largest text area as fallback...")
        
        // Strategy 3: Fallback - use the largest text area (compose box is usually large)
        let sortedBySize = textAreas
            .filter { $0.size != nil }
            .sorted { ($0.size!.width * $0.size!.height) > ($1.size!.width * $1.size!.height) }
        
        if let largest = sortedBySize.first {
            print("✅ Using largest text area as compose box")
            print("   Size: \(largest.size?.width ?? 0) x \(largest.size?.height ?? 0)")
            print("   Position: \(largest.position?.debugDescription ?? "nil")")
            return largest
        }
        
        print("❌ Could not determine compose box")
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
        print("🔍 Finding Notes text area (maxDepth: \(maxDepth))")
        print(String(repeating: "=", count: 60))
        
        guard checkAccessibilityPermission() else {
            lastError = "Accessibility permission not granted."
            return nil
        }
        
        // Get ALL elements from Notes for detailed analysis
        print("📋 Scanning ALL Notes UI elements...")
        let allElements = getAllNotesElements(maxDepth: maxDepth)
        print("📊 Total elements found: \(allElements.count)")
        print(String(repeating: "=", count: 60))
        
        // Log element type distribution
        var roleCount: [String: Int] = [:]
        for element in allElements {
            roleCount[element.role, default: 0] += 1
        }
        
        print("📊 Element distribution by role:")
        for (role, count) in roleCount.sorted(by: { $0.value > $1.value }) {
            print("   - \(role): \(count)")
        }
        print(String(repeating: "=", count: 60))
        
        // Get all text areas from Notes
        let textAreas = allElements.filter { $0.role == "AXTextArea" }
        print("📊 Found \(textAreas.count) AXTextArea elements in Notes:")
        for (index, textArea) in textAreas.enumerated() {
            print("\n   TextArea #\(index + 1):")
            print("     - Title: \(textArea.title ?? "nil")")
            print("     - Value: \(textArea.value?.prefix(50) ?? "nil")")
            print("     - Identifier: \(textArea.identifier ?? "nil")")
            print("     - Position: \(textArea.position?.debugDescription ?? "nil")")
            print("     - Size: \(textArea.size?.debugDescription ?? "nil")")
            print("     - Depth: \(textArea.depth)")
            print("     - Focused: \(textArea.focused)")
            print("     - Enabled: \(textArea.enabled)")
        }
        print(String(repeating: "=", count: 60))
        
        // Also check for scroll areas that might contain the text editor
        let scrollAreas = allElements.filter { $0.role == "AXScrollArea" }
        print("📊 Found \(scrollAreas.count) AXScrollArea elements in Notes:")
        for (index, scrollArea) in scrollAreas.enumerated() {
            print("\n   ScrollArea #\(index + 1):")
            print("     - Title: \(scrollArea.title ?? "nil")")
            print("     - Identifier: \(scrollArea.identifier ?? "nil")")
            print("     - Position: \(scrollArea.position?.debugDescription ?? "nil")")
            print("     - Size: \(scrollArea.size?.debugDescription ?? "nil")")
            print("     - Depth: \(scrollArea.depth)")
            print("     - Focused: \(scrollArea.focused)")
        }
        print(String(repeating: "=", count: 60))
        
        // Check for other potentially relevant roles
        let textFields = allElements.filter { $0.role == "AXTextField" }
        print("📊 Found \(textFields.count) AXTextField elements")
        
        let webAreas = allElements.filter { $0.role == "AXWebArea" }
        print("📊 Found \(webAreas.count) AXWebArea elements")
        
        let groups = allElements.filter { $0.role == "AXGroup" }
        print("📊 Found \(groups.count) AXGroup elements")
        print(String(repeating: "=", count: 60))
        
        if textAreas.isEmpty && scrollAreas.isEmpty {
            print("❌ No text area or scroll area found in Notes")
            print("💡 Try opening a note and clicking in the text editor area")
            return nil
        }
        
        // Strategy 1: Look for focused text area
        print("\n🎯 Strategy 1: Looking for focused text area...")
        for textArea in textAreas {
            if textArea.focused {
                print("✅ Found Notes text area by focus")
                print("   Title: \(textArea.title ?? "nil")")
                print("   Position: \(textArea.position?.debugDescription ?? "nil")")
                print("   Size: \(textArea.size?.debugDescription ?? "nil")")
                return textArea
            }
        }
        
        print("⚠️ No focused text area found")
        print("\n🎯 Strategy 2: Looking for largest text area...")
        
        // Strategy 2: Use the largest text area (main content area is usually large)
        let sortedBySize = textAreas
            .filter { $0.size != nil }
            .sorted { ($0.size!.width * $0.size!.height) > ($1.size!.width * $1.size!.height) }
        
        if let largest = sortedBySize.first {
            print("✅ Using largest text area in Notes")
            print("   Size: \(largest.size?.width ?? 0) x \(largest.size?.height ?? 0)")
            print("   Position: \(largest.position?.debugDescription ?? "nil")")
            print("   Title: \(largest.title ?? "nil")")
            return largest
        }
        
        print("⚠️ No suitable text area found")
        print("\n🎯 Strategy 3: Fallback to largest scroll area...")
        
        // Strategy 3: Fallback to scroll area if no text area found
        let sortedScrollAreas = scrollAreas
            .filter { $0.size != nil }
            .sorted { ($0.size!.width * $0.size!.height) > ($1.size!.width * $1.size!.height) }
        
        if let largestScroll = sortedScrollAreas.first {
            print("✅ Using largest scroll area in Notes as fallback")
            print("   Size: \(largestScroll.size?.width ?? 0) x \(largestScroll.size?.height ?? 0)")
            print("   Position: \(largestScroll.position?.debugDescription ?? "nil")")
            return largestScroll
        }
        
        print(String(repeating: "=", count: 60))
        print("❌ Could not determine Notes text area")
        print("💡 Make sure:")
        print("   1. Notes app is open")
        print("   2. A note is open")
        print("   3. Click in the text editing area")
        print(String(repeating: "=", count: 60))
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

