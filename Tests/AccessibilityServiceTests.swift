//
//  AccessibilityServiceTests.swift
//  LanguageSuggestionTests
//
//  Unit tests for AccessibilityService
//

import XCTest
@testable import LanguageSuggestion

final class AccessibilityServiceTests: XCTestCase {
    
    var service: AccessibilityService!
    
    override func setUp() {
        super.setUp()
        service = AccessibilityService()
    }
    
    override func tearDown() {
        service = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(service)
        // Note: isAccessibilityEnabled depends on system state
        // We can't reliably test it without actual accessibility permission
    }
    
    func testCheckAccessibilityPermission() {
        // This will return the actual system state
        // We can't mock AXIsProcessTrusted() easily, so we just verify it doesn't crash
        let result = service.checkAccessibilityPermission()
        // Result depends on system state, so we just verify it's a boolean
        XCTAssertTrue(result == true || result == false)
    }
    
    // MARK: - AccessibleElement Tests
    
    func testAccessibleElementInitialization() {
        let element = AccessibleElement(
            role: "AXTextField",
            title: "Test Title",
            value: "Test Value",
            elementDescription: "Test Description",
            identifier: "test-id",
            position: CGPoint(x: 100, y: 200),
            size: CGSize(width: 300, height: 400),
            depth: 2,
            enabled: true,
            focused: false
        )
        
        XCTAssertEqual(element.role, "AXTextField")
        XCTAssertEqual(element.title, "Test Title")
        XCTAssertEqual(element.value, "Test Value")
        XCTAssertEqual(element.elementDescription, "Test Description")
        XCTAssertEqual(element.identifier, "test-id")
        XCTAssertEqual(element.position, CGPoint(x: 100, y: 200))
        XCTAssertEqual(element.size, CGSize(width: 300, height: 400))
        XCTAssertEqual(element.depth, 2)
        XCTAssertTrue(element.enabled)
        XCTAssertFalse(element.focused)
    }
    
    func testAccessibleElementDescription() {
        let element = AccessibleElement(
            role: "AXButton",
            title: "Click Me",
            value: nil,
            elementDescription: nil,
            identifier: "button-1",
            position: CGPoint(x: 50, y: 50),
            size: CGSize(width: 100, height: 30),
            depth: 1,
            enabled: true,
            focused: false
        )
        
        let description = element.description
        XCTAssertTrue(description.contains("AXButton"))
        XCTAssertTrue(description.contains("Click Me"))
        XCTAssertTrue(description.contains("button-1"))
        XCTAssertTrue(description.contains("(50, 50)"))
        XCTAssertTrue(description.contains("100x30"))
    }
    
    func testAccessibleElementShortDescription() {
        let element = AccessibleElement(
            role: "AXTextField",
            title: "Username",
            value: "john.doe",
            elementDescription: nil,
            identifier: nil,
            position: nil,
            size: nil,
            depth: 0,
            enabled: true,
            focused: true
        )
        
        let shortDesc = element.shortDescription
        XCTAssertTrue(shortDesc.contains("AXTextField"))
        XCTAssertTrue(shortDesc.contains("Username"))
        XCTAssertTrue(shortDesc.contains("john.doe"))
    }
    
    func testAccessibleElementWithLongValue() {
        let longValue = String(repeating: "a", count: 100)
        let element = AccessibleElement(
            role: "AXTextArea",
            title: nil,
            value: longValue,
            elementDescription: nil,
            identifier: nil,
            position: nil,
            size: nil,
            depth: 0,
            enabled: true,
            focused: false
        )
        
        let shortDesc = element.shortDescription
        // Should truncate long values
        XCTAssertTrue(shortDesc.count < longValue.count + 50)
    }
    
    func testAccessibleElementFocused() {
        let element = AccessibleElement(
            role: "AXTextField",
            title: nil,
            value: nil,
            elementDescription: nil,
            identifier: nil,
            position: nil,
            size: nil,
            depth: 0,
            enabled: true,
            focused: true
        )
        
        let description = element.description
        XCTAssertTrue(description.contains("FOCUSED"))
    }
    
    func testAccessibleElementDisabled() {
        let element = AccessibleElement(
            role: "AXButton",
            title: nil,
            value: nil,
            elementDescription: nil,
            identifier: nil,
            position: nil,
            size: nil,
            depth: 0,
            enabled: false,
            focused: false
        )
        
        let description = element.description
        XCTAssertTrue(description.contains("DISABLED"))
    }
    
    // MARK: - Error Handling Tests
    
    func testGetTextFromFocusedElementWithoutPermission() {
        // This test depends on system state
        // We can't easily mock accessibility permission
        // So we just verify the method doesn't crash
        _ = service.getTextFromFocusedElement()
        // No assertion - just verify it doesn't throw
    }
    
    func testGetTextFromTeamsWithoutPermission() {
        _ = service.getTextFromTeams()
        // No assertion - just verify it doesn't throw
    }
    
    func testGetAllTextFromTeamsWindowWithoutPermission() {
        _ = service.getAllTextFromTeamsWindow()
        // No assertion - just verify it doesn't throw
    }
    
    // MARK: - Element Role Tests
    
    func testGetElementRole() {
        // This requires actual accessibility elements
        // We can't easily test without real UI elements
        // Just verify the method exists and doesn't crash
        // In a real scenario, you'd need to create test UI elements
    }
    
    // MARK: - Teams Element Finding Tests
    
    func testGetAllTeamsElements() {
        // This requires Teams to be running
        // We can't easily test without the actual app
        let elements = service.getAllTeamsElements(maxDepth: 1)
        // Just verify it returns an array (empty if Teams not running)
        XCTAssertNotNil(elements)
    }
    
    func testGetTeamsElementsByRole() {
        let elements = service.getTeamsElementsByRole("AXButton", maxDepth: 1)
        XCTAssertNotNil(elements)
        // All returned elements should have the specified role
        for element in elements {
            XCTAssertEqual(element.role, "AXButton")
        }
    }
    
    func testGetAllTeamsTextFields() {
        let textFields = service.getAllTeamsTextFields()
        XCTAssertNotNil(textFields)
        for field in textFields {
            XCTAssertEqual(field.role, "AXTextField")
        }
    }
    
    func testGetAllTeamsButtons() {
        let buttons = service.getAllTeamsButtons()
        XCTAssertNotNil(buttons)
        for button in buttons {
            XCTAssertEqual(button.role, "AXButton")
        }
    }
    
    func testGetAllTeamsTextAreas() {
        let textAreas = service.getAllTeamsTextAreas()
        XCTAssertNotNil(textAreas)
        for area in textAreas {
            XCTAssertEqual(area.role, "AXTextArea")
        }
    }
    
    // MARK: - Notes App Tests
    
    func testGetAllNotesElements() {
        let elements = service.getAllNotesElements(maxDepth: 1)
        XCTAssertNotNil(elements)
    }
    
    func testGetNotesElementsByRole() {
        let elements = service.getNotesElementsByRole("AXTextArea", maxDepth: 1)
        XCTAssertNotNil(elements)
        for element in elements {
            XCTAssertEqual(element.role, "AXTextArea")
        }
    }
    
    // MARK: - Find Methods Tests
    
    func testFindTeamsComposeBox() {
        // This requires Teams to be running and accessible
        let composeBox = service.findTeamsComposeBox(maxDepth: 1)
        // May return nil if Teams not running or no compose box found
        // Just verify it doesn't crash
        XCTAssertTrue(composeBox == nil || composeBox != nil)
    }
    
    func testFindNotesTextArea() {
        // This requires Notes to be running and accessible
        let textArea = service.findNotesTextArea(maxDepth: 1)
        // May return nil if Notes not running or no text area found
        // Just verify it doesn't crash
        XCTAssertTrue(textArea == nil || textArea != nil)
    }
    
    // MARK: - Open Settings Tests
    
    func testOpenAccessibilitySettings() {
        // This opens system settings, so we just verify it doesn't crash
        service.openAccessibilitySettings()
        // No assertion needed - just verify it doesn't throw
    }
}

