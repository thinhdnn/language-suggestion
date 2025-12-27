//
//  SettingsViewModelTests.swift
//  LanguageSuggestionTests
//
//  Unit tests for SettingsViewModel
//

import XCTest
@testable import LanguageSuggestion

@MainActor
final class SettingsViewModelTests: XCTestCase {
    
    private var testUserDefaults: UserDefaults!
    private var settingsManager: SettingsManager!
    private var viewModel: SettingsViewModel!
    
    override func setUp() {
        super.setUp()
        testUserDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        // Clear any existing data
        let dictionary = testUserDefaults.dictionaryRepresentation()
        dictionary.keys.forEach { key in
            testUserDefaults.removeObject(forKey: key)
        }
        
        settingsManager = SettingsManager(userDefaults: testUserDefaults)
        viewModel = SettingsViewModel(settingsManager: settingsManager)
    }
    
    override func tearDown() {
        viewModel = nil
        settingsManager = nil
        testUserDefaults = nil
        super.tearDown()
    }
    
    func testInitialization() {
        XCTAssertNotNil(viewModel)
        XCTAssertEqual(viewModel.apiProvider, .openai)
        XCTAssertEqual(viewModel.defaultAction, .fixGrammar)
        XCTAssertEqual(viewModel.targetLanguage, "English")
    }
    
    func testLoadSettings() {
        // Set values in settings manager
        settingsManager.apiProvider = .openrouter
        settingsManager.defaultAction = .translate
        settingsManager.targetLanguage = "French"
        settingsManager.openAIKey = "test-openai-key"
        settingsManager.openRouterKey = "test-openrouter-key"
        settingsManager.geminiKey = "test-gemini-key"
        settingsManager.saveSettings()
        
        // Create new view model and verify it loads settings
        let newViewModel = SettingsViewModel(settingsManager: settingsManager)
        
        XCTAssertEqual(newViewModel.apiProvider, .openrouter)
        XCTAssertEqual(newViewModel.defaultAction, .translate)
        XCTAssertEqual(newViewModel.targetLanguage, "French")
        XCTAssertEqual(newViewModel.openAIKey, "test-openai-key")
        XCTAssertEqual(newViewModel.openRouterKey, "test-openrouter-key")
        XCTAssertEqual(newViewModel.geminiKey, "test-gemini-key")
    }
    
    func testSaveSettings() {
        // Modify view model values
        viewModel.apiProvider = .gemini
        viewModel.defaultAction = .translate
        viewModel.targetLanguage = "Spanish"
        viewModel.openAIKey = "new-openai-key"
        viewModel.openRouterKey = "new-openrouter-key"
        viewModel.geminiKey = "new-gemini-key"
        
        // Save settings
        viewModel.saveSettings()
        
        // Verify settings are saved in manager
        XCTAssertEqual(settingsManager.apiProvider, .gemini)
        XCTAssertEqual(settingsManager.defaultAction, .translate)
        XCTAssertEqual(settingsManager.targetLanguage, "Spanish")
        XCTAssertEqual(settingsManager.openAIKey, "new-openai-key")
        XCTAssertEqual(settingsManager.openRouterKey, "new-openrouter-key")
        XCTAssertEqual(settingsManager.geminiKey, "new-gemini-key")
        
        // Verify save confirmation is shown
        XCTAssertTrue(viewModel.showSaveConfirmation)
    }
    
    func testRestoreDefaultPrompts() {
        // Add a custom prompt
        let customPrompt = CustomPrompt(
            name: "Custom Test",
            prompt: "Test prompt",
            keyEquivalent: "t"
        )
        settingsManager.addCustomPrompt(customPrompt)
        
        let initialCount = viewModel.customPrompts.count
        
        // Restore defaults
        viewModel.restoreDefaultPrompts()
        
        // Should have 4 default prompts
        XCTAssertEqual(viewModel.customPrompts.count, 4)
        XCTAssertNotEqual(viewModel.customPrompts.count, initialCount)
        
        // Verify default prompt names
        let names = Set(viewModel.customPrompts.map { $0.name })
        XCTAssertTrue(names.contains("Summarize"))
        XCTAssertTrue(names.contains("Make Professional"))
        XCTAssertTrue(names.contains("Make Casual"))
        XCTAssertTrue(names.contains("Paragraph IT Style"))
    }
    
    func testAddCustomPrompt() {
        let initialCount = viewModel.customPrompts.count
        
        let newPrompt = CustomPrompt(
            name: "New Prompt",
            prompt: "New prompt text",
            keyEquivalent: "n"
        )
        
        viewModel.addCustomPrompt(newPrompt)
        
        XCTAssertEqual(viewModel.customPrompts.count, initialCount + 1)
        XCTAssertTrue(viewModel.customPrompts.contains { $0.id == newPrompt.id })
    }
    
    func testUpdateCustomPrompt() {
        // Add a prompt
        let prompt = CustomPrompt(
            name: "Original",
            prompt: "Original text",
            keyEquivalent: "o"
        )
        viewModel.addCustomPrompt(prompt)
        
        // Update the prompt
        let updatedPrompt = CustomPrompt(
            id: prompt.id,
            name: "Updated",
            prompt: "Updated text",
            keyEquivalent: "u"
        )
        viewModel.updateCustomPrompt(updatedPrompt)
        
        let found = viewModel.customPrompts.first { $0.id == prompt.id }
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "Updated")
        XCTAssertEqual(found?.prompt, "Updated text")
    }
    
    func testDeleteCustomPrompt() {
        // Add a prompt
        let prompt = CustomPrompt(
            name: "To Delete",
            prompt: "Delete me",
            keyEquivalent: "d"
        )
        viewModel.addCustomPrompt(prompt)
        
        let initialCount = viewModel.customPrompts.count
        let index = viewModel.customPrompts.firstIndex { $0.id == prompt.id }!
        
        // Delete the prompt
        viewModel.deleteCustomPrompt(at: IndexSet(integer: index))
        
        XCTAssertEqual(viewModel.customPrompts.count, initialCount - 1)
        XCTAssertFalse(viewModel.customPrompts.contains { $0.id == prompt.id })
    }
    
    func testCustomPromptsProperty() {
        // Add a prompt directly to settings manager
        let prompt = CustomPrompt(
            name: "Direct Prompt",
            prompt: "Direct text",
            keyEquivalent: "d"
        )
        settingsManager.addCustomPrompt(prompt)
        
        // View model should reflect the change
        XCTAssertTrue(viewModel.customPrompts.contains { $0.id == prompt.id })
    }
}

