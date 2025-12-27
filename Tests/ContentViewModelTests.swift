//
//  ContentViewModelTests.swift
//  LanguageSuggestionTests
//
//  Unit tests for ContentViewModel
//

import XCTest
import AppKit
@testable import LanguageSuggestion

// Mock APIService for testing
class MockAPIService: APIServiceProtocol {
    var isLoading: Bool = false
    var errorMessage: String?
    
    var processTextResult: AIResponse?
    var processTextError: Error?
    var processTextWithCustomPromptResult: AIResponse?
    var processTextWithCustomPromptError: Error?
    
    func processText(
        text: String,
        action: ActionType,
        targetLanguage: String?,
        provider: APIProvider,
        apiKey: String
    ) async throws -> AIResponse {
        if let error = processTextError {
            throw error
        }
        return processTextResult ?? AIResponse(
            originalText: text,
            processedText: "Processed: \(text)",
            action: action.rawValue,
            language: targetLanguage,
            changes: nil,
            confidence: 0.95
        )
    }
    
    func processTextWithCustomPrompt(
        text: String,
        customPrompt: String,
        provider: APIProvider,
        apiKey: String
    ) async throws -> AIResponse {
        if let error = processTextWithCustomPromptError {
            throw error
        }
        return processTextWithCustomPromptResult ?? AIResponse(
            originalText: text,
            processedText: "Custom processed: \(text)",
            action: "Custom Prompt",
            language: nil,
            changes: nil,
            confidence: 0.95
        )
    }
}

// Mock AccessibilityService for testing
class MockAccessibilityService: AccessibilityService {
    var mockTextFromFocusedElement: String?
    var mockTextFromTeams: String?
    var mockAccessibilityEnabled: Bool = true
    var mockFindTeamsComposeBox: AccessibleElement?
    var mockFindNotesTextArea: AccessibleElement?
    
    override func getTextFromFocusedElement() -> String? {
        return mockTextFromFocusedElement
    }
    
    override func getTextFromTeams() -> String? {
        return mockTextFromTeams
    }
    
    override func checkAccessibilityPermission() -> Bool {
        return mockAccessibilityEnabled
    }
    
    override func findTeamsComposeBox(maxDepth: Int = 25) -> AccessibleElement? {
        return mockFindTeamsComposeBox
    }
    
    override func findNotesTextArea(maxDepth: Int = 25) -> AccessibleElement? {
        return mockFindNotesTextArea
    }
}

// Mock FloatingOverlayManager
class MockFloatingOverlayManager: FloatingOverlayManager {
    var showOverlayCalled = false
    var hideOverlayCalled = false
    var lastElement: AccessibleElement?
    
    override func showOverlay(
        for element: AccessibleElement,
        accessibilityService: AccessibilityService,
        settingsManager: SettingsManager
    ) {
        showOverlayCalled = true
        lastElement = element
    }
    
    override func hideOverlay() {
        hideOverlayCalled = true
    }
}

// Mock MenuBarManager
class MockMenuBarManager: MenuBarManager {
    var openSettingsCalled = false
    
    override func openSettings() {
        openSettingsCalled = true
    }
}

@MainActor
final class ContentViewModelTests: XCTestCase {
    
    var mockAPIService: MockAPIService!
    var mockAccessibilityService: MockAccessibilityService!
    var mockFloatingOverlayManager: MockFloatingOverlayManager!
    var mockMenuBarManager: MockMenuBarManager!
    var settingsManager: SettingsManager!
    var viewModel: ContentViewModel!
    
    override func setUp() {
        super.setUp()
        
        let testUserDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let dictionary = testUserDefaults.dictionaryRepresentation()
        dictionary.keys.forEach { key in
            testUserDefaults.removeObject(forKey: key)
        }
        
        mockAPIService = MockAPIService()
        mockAccessibilityService = MockAccessibilityService()
        mockFloatingOverlayManager = MockFloatingOverlayManager()
        mockMenuBarManager = MockMenuBarManager()
        settingsManager = SettingsManager(userDefaults: testUserDefaults)
        
        viewModel = ContentViewModel(
            apiService: mockAPIService,
            accessibilityService: mockAccessibilityService,
            floatingOverlayManager: mockFloatingOverlayManager,
            settingsManager: settingsManager,
            menuBarManager: mockMenuBarManager
        )
    }
    
    override func tearDown() {
        viewModel = nil
        settingsManager = nil
        mockMenuBarManager = nil
        mockFloatingOverlayManager = nil
        mockAccessibilityService = nil
        mockAPIService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(viewModel)
        XCTAssertFalse(viewModel.inputText.isEmpty) // Has default text
        XCTAssertTrue(viewModel.outputText.isEmpty)
        XCTAssertEqual(viewModel.currentAction, .fixGrammar)
        XCTAssertFalse(viewModel.showChanges)
        XCTAssertTrue(viewModel.changes.isEmpty)
    }
    
    func testWordCount() {
        viewModel.inputText = "This is a test"
        XCTAssertEqual(viewModel.wordCount, 4)
        
        viewModel.inputText = "One"
        XCTAssertEqual(viewModel.wordCount, 1)
        
        viewModel.inputText = ""
        XCTAssertEqual(viewModel.wordCount, 0)
    }
    
    // MARK: - Process Text Tests
    
    func testProcessTextWithEmptyInput() {
        viewModel.inputText = ""
        viewModel.processText()
        
        // Should not process empty text
        XCTAssertTrue(viewModel.outputText.isEmpty)
    }
    
    func testProcessTextWithMissingAPIKey() {
        settingsManager.openAIKey = ""
        viewModel.inputText = "Test text"
        
        viewModel.processText()
        
        // Wait a bit for async operation
        let expectation = XCTestExpectation(description: "Process text")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertTrue(viewModel.outputText.isEmpty)
    }
    
    func testProcessTextSuccess() async {
        settingsManager.openAIKey = "test-key"
        settingsManager.apiProvider = .openai
        viewModel.inputText = "Test text"
        viewModel.currentAction = .fixGrammar
        
        let expectedResponse = AIResponse(
            originalText: "Test text",
            processedText: "Fixed text",
            action: "Fix Grammar",
            language: nil,
            changes: [
                TextChange(original: "Test", corrected: "Fixed", reason: "Grammar")
            ],
            confidence: 0.98
        )
        
        mockAPIService.processTextResult = expectedResponse
        
        viewModel.processText()
        
        // Wait for async operation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertEqual(viewModel.outputText, "Fixed text")
        XCTAssertEqual(viewModel.changes.count, 1)
        XCTAssertEqual(viewModel.confidence, 0.98)
        XCTAssertTrue(viewModel.showChanges)
    }
    
    func testProcessTextWithError() async {
        settingsManager.openAIKey = "test-key"
        viewModel.inputText = "Test text"
        
        mockAPIService.processTextError = APIError.missingAPIKey
        
        viewModel.processText()
        
        // Wait for async operation
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Error should be set in APIService
        XCTAssertNotNil(mockAPIService.errorMessage)
    }
    
    // MARK: - Copy Output Tests
    
    func testCopyOutput() {
        viewModel.outputText = "Test output"
        viewModel.copyOutput()
        
        let pasteboard = NSPasteboard.general
        let copiedText = pasteboard.string(forType: .string)
        
        XCTAssertEqual(copiedText, "Test output")
    }
    
    // MARK: - Clear All Tests
    
    func testClearAll() {
        viewModel.inputText = "Input"
        viewModel.outputText = "Output"
        viewModel.changes = [TextChange(original: "a", corrected: "b", reason: "test")]
        viewModel.confidence = 0.95
        viewModel.showChanges = true
        
        viewModel.clearAll()
        
        XCTAssertTrue(viewModel.inputText.isEmpty)
        XCTAssertTrue(viewModel.outputText.isEmpty)
        XCTAssertTrue(viewModel.changes.isEmpty)
        XCTAssertNil(viewModel.confidence)
        XCTAssertFalse(viewModel.showChanges)
    }
    
    // MARK: - Custom Prompt Tests
    
    func testProcessCustomPromptWithNoText() {
        settingsManager.openAIKey = "test-key"
        let customPrompt = CustomPrompt(
            name: "Test Prompt",
            prompt: "Test prompt text",
            keyEquivalent: "t"
        )
        
        mockAccessibilityService.mockTextFromFocusedElement = nil
        mockAccessibilityService.mockTextFromTeams = nil
        
        viewModel.processCustomPrompt(customPrompt)
        
        // Should not process if no text found
        let expectation = XCTestExpectation(description: "Process custom prompt")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertTrue(viewModel.outputText.isEmpty)
    }
    
    func testProcessCustomPromptSuccess() async {
        settingsManager.openAIKey = "test-key"
        settingsManager.apiProvider = .openai
        
        let customPrompt = CustomPrompt(
            name: "Summarize",
            prompt: "Summarize this text",
            keyEquivalent: "s"
        )
        
        mockAccessibilityService.mockTextFromTeams = "Long text to summarize"
        
        let expectedResponse = AIResponse(
            originalText: "Long text to summarize",
            processedText: "Summary",
            action: "Custom Prompt",
            language: nil,
            changes: nil,
            confidence: 0.95
        )
        
        mockAPIService.processTextWithCustomPromptResult = expectedResponse
        
        viewModel.processCustomPrompt(customPrompt)
        
        // Wait for async operation
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        XCTAssertEqual(viewModel.inputText, "Long text to summarize")
        XCTAssertEqual(viewModel.currentActionName, "Summarize")
        XCTAssertEqual(viewModel.outputText, "Summary")
    }
    
    // MARK: - Open Settings Tests
    
    func testOpenSettings() {
        viewModel.openSettings()
        XCTAssertTrue(mockMenuBarManager.openSettingsCalled)
    }
    
    func testOpenAccessibilitySettings() {
        // This calls system API, so we just verify it doesn't crash
        viewModel.openAccessibilitySettings()
        // No assertion needed - just verify it doesn't throw
    }
    
    // MARK: - Initialize Tests
    
    func testInitialize() {
        settingsManager.defaultAction = .translate
        settingsManager.targetLanguage = "French"
        
        viewModel.initialize()
        
        XCTAssertEqual(viewModel.currentAction, .translate)
        XCTAssertEqual(viewModel.targetLanguage, "French")
    }
    
    // MARK: - Show Overlay Tests
    
    func testShowOverlayWithoutPermission() {
        mockAccessibilityService.mockAccessibilityEnabled = false
        
        viewModel.showOverlay()
        
        let expectation = XCTestExpectation(description: "Show overlay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertFalse(mockFloatingOverlayManager.showOverlayCalled)
    }
    
    func testShowOverlayWithTeams() async {
        mockAccessibilityService.mockAccessibilityEnabled = true
        
        let mockElement = AccessibleElement(
            role: "AXTextArea",
            title: "Compose",
            value: nil,
            elementDescription: nil,
            identifier: nil,
            position: CGPoint(x: 100, y: 100),
            size: CGSize(width: 500, height: 200),
            depth: 5,
            enabled: true,
            focused: true
        )
        
        mockAccessibilityService.mockFindTeamsComposeBox = mockElement
        
        viewModel.showOverlay()
        
        // Wait for async operation
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        XCTAssertTrue(mockFloatingOverlayManager.showOverlayCalled)
        XCTAssertEqual(mockFloatingOverlayManager.lastElement?.id, mockElement.id)
    }
}

