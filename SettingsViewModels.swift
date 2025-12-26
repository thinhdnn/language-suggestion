//
//  SettingsViewModels.swift
//  LanguageSuggestion
//
//  ViewModels for SettingsView following MVVM architecture
//

import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    var openAIKey: String = ""
    var openRouterKey: String = ""
    var geminiKey: String = ""
    var apiProvider: APIProvider = .openai
    var defaultAction: ActionType = .fixGrammar
    var targetLanguage: String = "English"
    var showSaveConfirmation = false
    var showAddPromptSheet = false
    var editingPrompt: CustomPrompt?
    
    private let settingsManager: SettingsManager
    
    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        loadSettings()
    }
    
    func loadSettings() {
        openAIKey = settingsManager.openAIKey
        openRouterKey = settingsManager.openRouterKey
        geminiKey = settingsManager.geminiKey
        apiProvider = settingsManager.apiProvider
        defaultAction = settingsManager.defaultAction
        targetLanguage = settingsManager.targetLanguage
    }
    
    func saveSettings() {
        settingsManager.openAIKey = openAIKey
        settingsManager.openRouterKey = openRouterKey
        settingsManager.geminiKey = geminiKey
        settingsManager.apiProvider = apiProvider
        settingsManager.defaultAction = defaultAction
        settingsManager.targetLanguage = targetLanguage
        settingsManager.saveSettings()
        showSaveConfirmation = true
    }
    
    func restoreDefaultPrompts() {
        settingsManager.restoreDefaultPrompts()
    }
    
    func addCustomPrompt(_ prompt: CustomPrompt) {
        settingsManager.addCustomPrompt(prompt)
    }
    
    func updateCustomPrompt(_ prompt: CustomPrompt) {
        settingsManager.updateCustomPrompt(prompt)
    }
    
    func deleteCustomPrompt(at offsets: IndexSet) {
        settingsManager.deleteCustomPrompt(at: offsets)
    }
    
    var customPrompts: [CustomPrompt] {
        settingsManager.customPrompts
    }
}

