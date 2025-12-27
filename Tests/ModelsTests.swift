//
//  ModelsTests.swift
//  LanguageSuggestionTests
//
//  Unit tests for Models.swift
//

import XCTest
@testable import LanguageSuggestion

final class ModelsTests: XCTestCase {
    
    // MARK: - APIProvider Tests
    
    func testAPIProviderRawValues() {
        XCTAssertEqual(APIProvider.openai.rawValue, "OpenAI")
        XCTAssertEqual(APIProvider.openrouter.rawValue, "OpenRouter")
        XCTAssertEqual(APIProvider.gemini.rawValue, "Gemini")
    }
    
    func testAPIProviderInitFromRawValue() {
        XCTAssertEqual(APIProvider(rawValue: "OpenAI"), .openai)
        XCTAssertEqual(APIProvider(rawValue: "OpenRouter"), .openrouter)
        XCTAssertEqual(APIProvider(rawValue: "Gemini"), .gemini)
        XCTAssertNil(APIProvider(rawValue: "Invalid"))
    }
    
    func testAPIProviderCaseIterable() {
        let allCases = APIProvider.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.openai))
        XCTAssertTrue(allCases.contains(.openrouter))
        XCTAssertTrue(allCases.contains(.gemini))
    }
    
    func testAPIProviderCodable() throws {
        let provider = APIProvider.openai
        let encoder = JSONEncoder()
        let data = try encoder.encode(provider)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(APIProvider.self, from: data)
        
        XCTAssertEqual(decoded, provider)
    }
    
    // MARK: - ActionType Tests
    
    func testActionTypeRawValues() {
        XCTAssertEqual(ActionType.translate.rawValue, "Translate")
        XCTAssertEqual(ActionType.fixGrammar.rawValue, "Fix Grammar")
    }
    
    func testActionTypeInitFromRawValue() {
        XCTAssertEqual(ActionType(rawValue: "Translate"), .translate)
        XCTAssertEqual(ActionType(rawValue: "Fix Grammar"), .fixGrammar)
        XCTAssertNil(ActionType(rawValue: "Invalid"))
    }
    
    func testActionTypeCaseIterable() {
        let allCases = ActionType.allCases
        XCTAssertEqual(allCases.count, 2)
        XCTAssertTrue(allCases.contains(.translate))
        XCTAssertTrue(allCases.contains(.fixGrammar))
    }
    
    func testActionTypeCodable() throws {
        let action = ActionType.fixGrammar
        let encoder = JSONEncoder()
        let data = try encoder.encode(action)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ActionType.self, from: data)
        
        XCTAssertEqual(decoded, action)
    }
    
    // MARK: - CustomPrompt Tests
    
    func testCustomPromptInitialization() {
        let prompt = CustomPrompt(
            name: "Test Prompt",
            prompt: "Test prompt text",
            keyEquivalent: "t"
        )
        
        XCTAssertEqual(prompt.name, "Test Prompt")
        XCTAssertEqual(prompt.prompt, "Test prompt text")
        XCTAssertEqual(prompt.keyEquivalent, "t")
        XCTAssertNotNil(prompt.id)
    }
    
    func testCustomPromptWithDefaultKeyEquivalent() {
        let prompt = CustomPrompt(name: "Test", prompt: "Test text")
        XCTAssertEqual(prompt.keyEquivalent, "")
    }
    
    func testCustomPromptIdentifiable() {
        let prompt1 = CustomPrompt(name: "Test", prompt: "Text")
        let prompt2 = CustomPrompt(name: "Test", prompt: "Text")
        
        // IDs should be different
        XCTAssertNotEqual(prompt1.id, prompt2.id)
    }
    
    func testCustomPromptCodable() throws {
        let prompt = CustomPrompt(
            name: "Test Prompt",
            prompt: "Test prompt text",
            keyEquivalent: "t"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(prompt)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CustomPrompt.self, from: data)
        
        XCTAssertEqual(decoded.name, prompt.name)
        XCTAssertEqual(decoded.prompt, prompt.prompt)
        XCTAssertEqual(decoded.keyEquivalent, prompt.keyEquivalent)
    }
    
    func testCustomPromptArrayCodable() throws {
        let prompts = [
            CustomPrompt(name: "Prompt 1", prompt: "Text 1", keyEquivalent: "1"),
            CustomPrompt(name: "Prompt 2", prompt: "Text 2", keyEquivalent: "2")
        ]
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(prompts)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode([CustomPrompt].self, from: data)
        
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].name, "Prompt 1")
        XCTAssertEqual(decoded[1].name, "Prompt 2")
    }
    
    // MARK: - AIResponse Tests
    
    func testAIResponseInitialization() {
        let response = AIResponse(
            originalText: "Hello",
            processedText: "Hello World",
            action: "Translate",
            language: "English",
            changes: nil,
            confidence: 0.95
        )
        
        XCTAssertEqual(response.originalText, "Hello")
        XCTAssertEqual(response.processedText, "Hello World")
        XCTAssertEqual(response.action, "Translate")
        XCTAssertEqual(response.language, "English")
        XCTAssertNil(response.changes)
        XCTAssertEqual(response.confidence, 0.95)
    }
    
    func testAIResponseWithChanges() {
        let changes = [
            TextChange(original: "teh", corrected: "the", reason: "Typo")
        ]
        
        let response = AIResponse(
            originalText: "teh cat",
            processedText: "the cat",
            action: "Fix Grammar",
            language: nil,
            changes: changes,
            confidence: 0.98
        )
        
        XCTAssertNotNil(response.changes)
        XCTAssertEqual(response.changes?.count, 1)
        XCTAssertEqual(response.changes?.first?.original, "teh")
        XCTAssertEqual(response.changes?.first?.corrected, "the")
    }
    
    func testAIResponseCodable() throws {
        let changes = [
            TextChange(original: "teh", corrected: "the", reason: "Typo")
        ]
        
        let response = AIResponse(
            originalText: "teh cat",
            processedText: "the cat",
            action: "Fix Grammar",
            language: nil,
            changes: changes,
            confidence: 0.98
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AIResponse.self, from: data)
        
        XCTAssertEqual(decoded.originalText, response.originalText)
        XCTAssertEqual(decoded.processedText, response.processedText)
        XCTAssertEqual(decoded.action, response.action)
        XCTAssertEqual(decoded.language, response.language)
        XCTAssertEqual(decoded.confidence, response.confidence)
        XCTAssertEqual(decoded.changes?.count, 1)
    }
    
    // MARK: - TextChange Tests
    
    func testTextChangeInitialization() {
        let change = TextChange(
            original: "teh",
            corrected: "the",
            reason: "Typo correction"
        )
        
        XCTAssertEqual(change.original, "teh")
        XCTAssertEqual(change.corrected, "the")
        XCTAssertEqual(change.reason, "Typo correction")
    }
    
    func testTextChangeCodable() throws {
        let change = TextChange(
            original: "teh",
            corrected: "the",
            reason: "Typo"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(change)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TextChange.self, from: data)
        
        XCTAssertEqual(decoded.original, change.original)
        XCTAssertEqual(decoded.corrected, change.corrected)
        XCTAssertEqual(decoded.reason, change.reason)
    }
    
    // MARK: - SettingsManager Tests
    
    // Helper method to create a clean test UserDefaults
    private func createTestUserDefaults() -> UserDefaults {
        let testDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        // Clear any existing data
        let dictionary = testDefaults.dictionaryRepresentation()
        dictionary.keys.forEach { key in
            testDefaults.removeObject(forKey: key)
        }
        return testDefaults
    }
    
    func testSettingsManagerInitialization() {
        let testDefaults = createTestUserDefaults()
        let settings = SettingsManager(userDefaults: testDefaults)
        
        // Check default values
        XCTAssertEqual(settings.apiProvider, .openai)
        XCTAssertEqual(settings.defaultAction, .fixGrammar)
        XCTAssertEqual(settings.targetLanguage, "English")
        XCTAssertTrue(settings.openAIKey.isEmpty)
        XCTAssertTrue(settings.openRouterKey.isEmpty)
        XCTAssertTrue(settings.geminiKey.isEmpty)
    }
    
    func testSettingsManagerDefaultInitializer() {
        // Test that default initializer still works (uses UserDefaults.standard)
        let settings = SettingsManager()
        XCTAssertNotNil(settings)
    }
    
    func testSettingsManagerCurrentAPIKey() {
        let testDefaults = createTestUserDefaults()
        let settings = SettingsManager(userDefaults: testDefaults)
        
        // Test OpenAI key
        settings.apiProvider = .openai
        settings.openAIKey = "openai-key"
        XCTAssertEqual(settings.currentAPIKey, "openai-key")
        
        // Test OpenRouter key
        settings.apiProvider = .openrouter
        settings.openRouterKey = "openrouter-key"
        XCTAssertEqual(settings.currentAPIKey, "openrouter-key")
        
        // Test Gemini key
        settings.apiProvider = .gemini
        settings.geminiKey = "gemini-key"
        XCTAssertEqual(settings.currentAPIKey, "gemini-key")
    }
    
    func testSettingsManagerSaveAndLoad() {
        let testDefaults = createTestUserDefaults()
        
        // Create settings and modify values
        let settings = SettingsManager(userDefaults: testDefaults)
        settings.apiProvider = .openrouter
        settings.defaultAction = .translate
        settings.targetLanguage = "Vietnamese"
        settings.openRouterKey = "test-key"
        settings.openAIKey = "openai-test-key"
        settings.geminiKey = "gemini-test-key"
        
        // Save settings
        settings.saveSettings()
        
        // Create new instance with same UserDefaults and verify it loads correctly
        let loadedSettings = SettingsManager(userDefaults: testDefaults)
        
        XCTAssertEqual(loadedSettings.apiProvider, .openrouter)
        XCTAssertEqual(loadedSettings.defaultAction, .translate)
        XCTAssertEqual(loadedSettings.targetLanguage, "Vietnamese")
        XCTAssertEqual(loadedSettings.openRouterKey, "test-key")
        XCTAssertEqual(loadedSettings.openAIKey, "openai-test-key")
        XCTAssertEqual(loadedSettings.geminiKey, "gemini-test-key")
    }
    
    func testSettingsManagerSaveAndLoadCustomPrompts() {
        let testDefaults = createTestUserDefaults()
        
        let settings = SettingsManager(userDefaults: testDefaults)
        
        // Clear default prompts for this test
        settings.customPrompts = []
        
        let prompt1 = CustomPrompt(name: "Test 1", prompt: "Prompt 1", keyEquivalent: "1")
        let prompt2 = CustomPrompt(name: "Test 2", prompt: "Prompt 2", keyEquivalent: "2")
        
        settings.customPrompts = [prompt1, prompt2]
        settings.saveSettings()
        
        // Create new instance and verify prompts are loaded
        let loadedSettings = SettingsManager(userDefaults: testDefaults)
        
        XCTAssertEqual(loadedSettings.customPrompts.count, 2)
        XCTAssertTrue(loadedSettings.customPrompts.contains { $0.id == prompt1.id })
        XCTAssertTrue(loadedSettings.customPrompts.contains { $0.id == prompt2.id })
    }
    
    func testSettingsManagerAddCustomPrompt() {
        let testDefaults = createTestUserDefaults()
        let settings = SettingsManager(userDefaults: testDefaults)
        
        // Clear default prompts for this test
        settings.customPrompts = []
        settings.saveSettings()
        
        let initialCount = settings.customPrompts.count
        
        let newPrompt = CustomPrompt(
            name: "Test Prompt",
            prompt: "Test text",
            keyEquivalent: "t"
        )
        
        settings.addCustomPrompt(newPrompt)
        
        XCTAssertEqual(settings.customPrompts.count, initialCount + 1)
        XCTAssertTrue(settings.customPrompts.contains { $0.id == newPrompt.id })
        
        // Verify it's persisted
        let loadedSettings = SettingsManager(userDefaults: testDefaults)
        XCTAssertTrue(loadedSettings.customPrompts.contains { $0.id == newPrompt.id })
    }
    
    func testSettingsManagerUpdateCustomPrompt() {
        let testDefaults = createTestUserDefaults()
        let settings = SettingsManager(userDefaults: testDefaults)
        
        // Clear default prompts for this test
        settings.customPrompts = []
        settings.saveSettings()
        
        // Add a prompt
        let prompt = CustomPrompt(
            name: "Original",
            prompt: "Original text",
            keyEquivalent: "o"
        )
        settings.addCustomPrompt(prompt)
        
        // Update the prompt
        let updatedPrompt = CustomPrompt(
            id: prompt.id,
            name: "Updated",
            prompt: "Updated text",
            keyEquivalent: "u"
        )
        settings.updateCustomPrompt(updatedPrompt)
        
        let found = settings.customPrompts.first { $0.id == prompt.id }
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "Updated")
        XCTAssertEqual(found?.prompt, "Updated text")
        XCTAssertEqual(found?.keyEquivalent, "u")
        
        // Verify it's persisted
        let loadedSettings = SettingsManager(userDefaults: testDefaults)
        let loadedFound = loadedSettings.customPrompts.first { $0.id == prompt.id }
        XCTAssertEqual(loadedFound?.name, "Updated")
    }
    
    func testSettingsManagerUpdateNonExistentPrompt() {
        let testDefaults = createTestUserDefaults()
        let settings = SettingsManager(userDefaults: testDefaults)
        
        // Try to update a prompt that doesn't exist
        let nonExistentPrompt = CustomPrompt(
            id: UUID(),
            name: "Non Existent",
            prompt: "Text",
            keyEquivalent: "n"
        )
        
        let initialCount = settings.customPrompts.count
        settings.updateCustomPrompt(nonExistentPrompt)
        
        // Should not add a new prompt
        XCTAssertEqual(settings.customPrompts.count, initialCount)
    }
    
    func testSettingsManagerDeleteCustomPrompt() {
        let testDefaults = createTestUserDefaults()
        let settings = SettingsManager(userDefaults: testDefaults)
        
        // Clear default prompts for this test
        settings.customPrompts = []
        settings.saveSettings()
        
        // Add a prompt
        let prompt = CustomPrompt(
            name: "To Delete",
            prompt: "Delete me",
            keyEquivalent: "d"
        )
        settings.addCustomPrompt(prompt)
        
        let initialCount = settings.customPrompts.count
        let index = settings.customPrompts.firstIndex { $0.id == prompt.id }!
        
        // Delete the prompt
        settings.deleteCustomPrompt(at: IndexSet(integer: index))
        
        XCTAssertEqual(settings.customPrompts.count, initialCount - 1)
        XCTAssertFalse(settings.customPrompts.contains { $0.id == prompt.id })
        
        // Verify it's persisted
        let loadedSettings = SettingsManager(userDefaults: testDefaults)
        XCTAssertFalse(loadedSettings.customPrompts.contains { $0.id == prompt.id })
    }
    
    func testSettingsManagerRestoreDefaultPrompts() {
        let testDefaults = createTestUserDefaults()
        let settings = SettingsManager(userDefaults: testDefaults)
        
        // Clear and add a custom prompt
        settings.customPrompts = []
        let customPrompt = CustomPrompt(
            name: "Custom",
            prompt: "Custom text",
            keyEquivalent: "c"
        )
        settings.addCustomPrompt(customPrompt)
        
        // Restore defaults
        settings.restoreDefaultPrompts()
        
        // Should have 4 default prompts
        XCTAssertEqual(settings.customPrompts.count, 4)
        
        // Check default prompt names
        let names = Set(settings.customPrompts.map { $0.name })
        XCTAssertTrue(names.contains("Summarize"))
        XCTAssertTrue(names.contains("Make Professional"))
        XCTAssertTrue(names.contains("Make Casual"))
        XCTAssertTrue(names.contains("Paragraph IT Style"))
        
        // Custom prompt should be gone
        XCTAssertFalse(settings.customPrompts.contains { $0.name == "Custom" })
        
        // Verify it's persisted
        let loadedSettings = SettingsManager(userDefaults: testDefaults)
        XCTAssertEqual(loadedSettings.customPrompts.count, 4)
    }
    
    func testSettingsManagerDefaultPromptsOnFirstRun() {
        let testDefaults = createTestUserDefaults()
        let settings = SettingsManager(userDefaults: testDefaults)
        
        // Should have default prompts after initialization (when array is empty)
        XCTAssertFalse(settings.customPrompts.isEmpty)
        XCTAssertGreaterThanOrEqual(settings.customPrompts.count, 4)
        
        // Verify default prompt names exist
        let names = Set(settings.customPrompts.map { $0.name })
        XCTAssertTrue(names.contains("Summarize"))
        XCTAssertTrue(names.contains("Make Professional"))
        XCTAssertTrue(names.contains("Make Casual"))
        XCTAssertTrue(names.contains("Paragraph IT Style"))
    }
    
    func testSettingsManagerLoadsExistingSettings() {
        let testDefaults = createTestUserDefaults()
        
        // Pre-populate UserDefaults
        testDefaults.set("OpenRouter", forKey: "apiProvider")
        testDefaults.set("Translate", forKey: "defaultAction")
        testDefaults.set("French", forKey: "targetLanguage")
        testDefaults.set("test-openai-key", forKey: "openAIKey")
        testDefaults.set("test-openrouter-key", forKey: "openRouterKey")
        testDefaults.set("test-gemini-key", forKey: "geminiKey")
        
        // Create settings and verify it loads existing values
        let settings = SettingsManager(userDefaults: testDefaults)
        
        XCTAssertEqual(settings.apiProvider, .openrouter)
        XCTAssertEqual(settings.defaultAction, .translate)
        XCTAssertEqual(settings.targetLanguage, "French")
        XCTAssertEqual(settings.openAIKey, "test-openai-key")
        XCTAssertEqual(settings.openRouterKey, "test-openrouter-key")
        XCTAssertEqual(settings.geminiKey, "test-gemini-key")
    }
    
    func testSettingsManagerHandlesInvalidProvider() {
        let testDefaults = createTestUserDefaults()
        
        // Set invalid provider value
        testDefaults.set("InvalidProvider", forKey: "apiProvider")
        
        // Should default to .openai
        let settings = SettingsManager(userDefaults: testDefaults)
        XCTAssertEqual(settings.apiProvider, .openai)
    }
    
    func testSettingsManagerHandlesInvalidAction() {
        let testDefaults = createTestUserDefaults()
        
        // Set invalid action value
        testDefaults.set("InvalidAction", forKey: "defaultAction")
        
        // Should default to .fixGrammar
        let settings = SettingsManager(userDefaults: testDefaults)
        XCTAssertEqual(settings.defaultAction, .fixGrammar)
    }
    
    func testSettingsManagerMigrationAddsParagraphITStyle() {
        let testDefaults = createTestUserDefaults()
        
        // Simulate old prompts without "Paragraph IT Style"
        let oldPrompts = [
            CustomPrompt(name: "Summarize", prompt: "Summarize:", keyEquivalent: "s"),
            CustomPrompt(name: "Make Professional", prompt: "Make professional:", keyEquivalent: "p")
        ]
        
        if let encoded = try? JSONEncoder().encode(oldPrompts) {
            testDefaults.set(encoded, forKey: "customPrompts")
        }
        
        // Create settings - should auto-add "Paragraph IT Style"
        let settings = SettingsManager(userDefaults: testDefaults)
        
        XCTAssertTrue(settings.customPrompts.contains { $0.name == "Paragraph IT Style" })
        XCTAssertEqual(settings.customPrompts.count, 3)
    }
}

