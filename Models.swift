//
//  Models.swift
//  LanguageSuggestion
//
//  Data models for API responses
//

import Foundation
import Observation

// API Provider enum
enum APIProvider: String, CaseIterable, Codable {
    case openai = "OpenAI"
    case openrouter = "OpenRouter"
    case gemini = "Gemini"
}

// Action type enum
enum ActionType: String, CaseIterable, Codable {
    case translate = "Translate"
    case fixGrammar = "Fix Grammar"
}

// Custom Prompt Model - for dynamic menu items
struct CustomPrompt: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String // Menu item name
    var prompt: String // Custom prompt to send to AI
    var keyEquivalent: String // Optional keyboard shortcut
    
    init(id: UUID = UUID(), name: String, prompt: String, keyEquivalent: String = "") {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.keyEquivalent = keyEquivalent
    }
}

// API Response Model (JSON structure)
struct AIResponse: Codable {
    let originalText: String
    let processedText: String
    let action: String
    let language: String?
    let changes: [TextChange]?
    let confidence: Double?
}

struct TextChange: Codable {
    let original: String
    let corrected: String
    let reason: String
}

// Settings Model
@Observable
final class SettingsManager {
    var apiProvider: APIProvider = .openai
    var openAIKey: String = ""
    var openRouterKey: String = ""
    var geminiKey: String = ""
    var defaultAction: ActionType = .fixGrammar
    var targetLanguage: String = "English"
    var customPrompts: [CustomPrompt] = []
    
    private let userDefaults = UserDefaults.standard
    
    // Computed property to get current API key based on provider
    var currentAPIKey: String {
        switch apiProvider {
        case .openai:
            return openAIKey
        case .openrouter:
            return openRouterKey
        case .gemini:
            return geminiKey
        }
    }
    
    init() {
        loadSettings()
    }
    
    func saveSettings() {
        // Save all settings to UserDefaults
        userDefaults.set(apiProvider.rawValue, forKey: "apiProvider")
        userDefaults.set(defaultAction.rawValue, forKey: "defaultAction")
        userDefaults.set(targetLanguage, forKey: "targetLanguage")
        
        // Save API keys to UserDefaults
        userDefaults.set(openAIKey, forKey: "openAIKey")
        userDefaults.set(openRouterKey, forKey: "openRouterKey")
        userDefaults.set(geminiKey, forKey: "geminiKey")
        
        // Save custom prompts
        if let encoded = try? JSONEncoder().encode(customPrompts) {
            userDefaults.set(encoded, forKey: "customPrompts")
        }
    }
    
    private func loadSettings() {
        // Load settings from UserDefaults
        if let providerString = userDefaults.string(forKey: "apiProvider"),
           let provider = APIProvider(rawValue: providerString) {
            apiProvider = provider
        }
        
        if let actionString = userDefaults.string(forKey: "defaultAction"),
           let action = ActionType(rawValue: actionString) {
            defaultAction = action
        }
        
        targetLanguage = userDefaults.string(forKey: "targetLanguage") ?? "English"
        
        // Load API keys from UserDefaults
        openAIKey = userDefaults.string(forKey: "openAIKey") ?? ""
        openRouterKey = userDefaults.string(forKey: "openRouterKey") ?? ""
        geminiKey = userDefaults.string(forKey: "geminiKey") ?? ""
        
        // Load custom prompts
        if let data = userDefaults.data(forKey: "customPrompts"),
           let decoded = try? JSONDecoder().decode([CustomPrompt].self, from: data) {
            customPrompts = decoded
        }
        
        // Add default prompts if array is empty (first run or user deleted all)
        if customPrompts.isEmpty {
            customPrompts = [
                CustomPrompt(name: "Summarize", prompt: "Summarize the following text concisely:", keyEquivalent: "s"),
                CustomPrompt(name: "Make Professional", prompt: "Rewrite the following text in a professional tone:", keyEquivalent: "p"),
                CustomPrompt(name: "Make Casual", prompt: "Rewrite the following text in a casual, friendly tone:", keyEquivalent: "c"),
                CustomPrompt(name: "Paragraph IT Style", prompt: "Transform the following keyword-based text into a well-written paragraph in IT writing style:", keyEquivalent: "i")
            ]
            saveSettings()
        } else {
            // Auto-add Paragraph IT Style prompt if it doesn't exist (migration for existing users)
            let itStylePrompt = CustomPrompt(name: "Paragraph IT Style", prompt: "Transform the following keyword-based text into a well-written paragraph in IT writing style:", keyEquivalent: "i")
            if !customPrompts.contains(where: { $0.name == "Paragraph IT Style" }) {
                customPrompts.append(itStylePrompt)
                saveSettings()
            }
        }
    }
    
    // Add a custom prompt
    func addCustomPrompt(_ prompt: CustomPrompt) {
        customPrompts.append(prompt)
        saveSettings()
        // Notify menu bar to update
        NotificationCenter.default.post(name: .customPromptsChanged, object: nil)
    }
    
    // Update a custom prompt
    func updateCustomPrompt(_ prompt: CustomPrompt) {
        if let index = customPrompts.firstIndex(where: { $0.id == prompt.id }) {
            customPrompts[index] = prompt
            saveSettings()
            // Notify menu bar to update
            NotificationCenter.default.post(name: .customPromptsChanged, object: nil)
        }
    }
    
    // Delete a custom prompt
    func deleteCustomPrompt(at offsets: IndexSet) {
        customPrompts.remove(atOffsets: offsets)
        saveSettings()
        // Notify menu bar to update
        NotificationCenter.default.post(name: .customPromptsChanged, object: nil)
    }
    
    // Restore default prompts
    func restoreDefaultPrompts() {
        customPrompts = [
            CustomPrompt(name: "Summarize", prompt: "Summarize the following text concisely:", keyEquivalent: "s"),
            CustomPrompt(name: "Make Professional", prompt: "Rewrite the following text in a professional tone:", keyEquivalent: "p"),
            CustomPrompt(name: "Make Casual", prompt: "Rewrite the following text in a casual, friendly tone:", keyEquivalent: "c"),
            CustomPrompt(name: "Paragraph IT Style", prompt: "Transform the following keyword-based text into a well-written paragraph in IT writing style:", keyEquivalent: "i")
        ]
        saveSettings()
        // Notify menu bar to update
        NotificationCenter.default.post(name: .customPromptsChanged, object: nil)
    }
}

