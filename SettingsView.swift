//
//  SettingsView.swift
//  LanguageSuggestion
//
//  Settings interface for API configuration
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    @State private var openAIKey: String = ""
    @State private var openRouterKey: String = ""
    @State private var geminiKey: String = ""
    @State private var apiProvider: APIProvider = .openai
    @State private var defaultAction: ActionType = .fixGrammar
    @State private var targetLanguage: String = "English"
    @State private var showSaveConfirmation = false
    @State private var showAddPromptSheet = false
    @State private var editingPrompt: CustomPrompt?
    
    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.sRGB, red: 0.97, green: 0.98, blue: 1.0, opacity: 1.0),
                    Color(.sRGB, red: 0.94, green: 0.96, blue: 1.0, opacity: 1.0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                header
                card
            }
            .padding(16)
        }
        .frame(width: 700, height: 600)
        .onAppear {
            loadSettings()
        }
        .alert("Settings Saved", isPresented: $showSaveConfirmation) {
            Button("OK") {}
        } message: {
            Text("Your settings have been saved successfully.")
        }
        .sheet(isPresented: $showAddPromptSheet, onDismiss: {
            editingPrompt = nil
        }) {
            AddCustomPromptView(settingsManager: settingsManager, editingPrompt: editingPrompt) {
                editingPrompt = nil
            }
            .interactiveDismissDisabled(false)
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.title3.bold())
                Text("Configure provider, keys, and defaults.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if showSaveConfirmation {
                Label("Saved", systemImage: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.subheadline)
            }
        }
    }
    
    private var card: some View {
        VStack(spacing: 12) {
            Form {
                providerSection
                apiKeySection
                defaultsSection
                customPromptsSection
                saveSection
            }
            .formStyle(.grouped)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
        )
    }
    
    private var providerSection: some View {
        Section {
            Picker("API Provider", selection: $apiProvider) {
                ForEach(APIProvider.allCases, id: \.self) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
        } header: {
            Text("API Configuration")
        } footer: {
            Text("Select your preferred AI service provider")
        }
    }
    
    private var apiKeySection: some View {
        Section {
            if apiProvider == .openai {
                SecureField("OpenAI API Key", text: $openAIKey)
                    .textContentType(.password)
                    .disableAutocorrection(true)
            } else if apiProvider == .openrouter {
                SecureField("OpenRouter API Key", text: $openRouterKey)
                    .textContentType(.password)
                    .disableAutocorrection(true)
            } else if apiProvider == .gemini {
                SecureField("Gemini API Key", text: $geminiKey)
                    .textContentType(.password)
                    .disableAutocorrection(true)
            }
        } header: {
            Text("API Key")
        } footer: {
            Text(apiProvider == .openai ? "OpenAI key is used when provider is OpenAI." : apiProvider == .openrouter ? "OpenRouter key is used when provider is OpenRouter." : "Gemini key is used when provider is Gemini.")
        }
    }
    
    private var defaultsSection: some View {
        Section {
            Picker("Default Action", selection: $defaultAction) {
                ForEach(ActionType.allCases, id: \.self) { action in
                    Text(action.rawValue).tag(action)
                }
            }
            
            TextField("Default Target Language", text: $targetLanguage)
                .help("Used when translating text")
        } header: {
            Text("Defaults")
        } footer: {
            Text("These are applied on app launch.")
        }
    }
    
    private var customPromptsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Configure custom menu items with AI prompts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: {
                        settingsManager.restoreDefaultPrompts()
                    }) {
                        Label("Restore Defaults", systemImage: "arrow.counterclockwise")
                    }
                    .help("Restore the 3 default prompts")
                    
                    Button(action: {
                        editingPrompt = nil
                        showAddPromptSheet = true
                    }) {
                        Label("Add", systemImage: "plus.circle.fill")
                    }
                }
                
                if settingsManager.customPrompts.isEmpty {
                    Text("No custom prompts yet. Add one to get started!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    List {
                        ForEach(settingsManager.customPrompts) { prompt in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(prompt.name)
                                        .font(.headline)
                                    Text(prompt.prompt)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                HStack(spacing: 8) {
                                    if !prompt.keyEquivalent.isEmpty {
                                        Text("⌘\(prompt.keyEquivalent)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.gray.opacity(0.15))
                                            .cornerRadius(4)
                                    }
                                    Button(action: {
                                        // Ensure sheet is closed first
                                        showAddPromptSheet = false
                                        // Then set editing prompt and show
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            editingPrompt = prompt
                                            showAddPromptSheet = true
                                        }
                                    }) {
                                        Image(systemName: "pencil")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete { offsets in
                            settingsManager.deleteCustomPrompt(at: offsets)
                        }
                    }
                    .frame(minHeight: 150, maxHeight: 200)
                }
            }
        } header: {
            Text("Custom Prompts (Menu Items)")
        } footer: {
            Text("These will appear as menu items when you click the menu bar icon")
        }
    }
    
    private var saveSection: some View {
        Section {
            Button("Save Settings") {
                saveSettings()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
    
    private func loadSettings() {
        openAIKey = settingsManager.openAIKey
        openRouterKey = settingsManager.openRouterKey
        geminiKey = settingsManager.geminiKey
        apiProvider = settingsManager.apiProvider
        defaultAction = settingsManager.defaultAction
        targetLanguage = settingsManager.targetLanguage
    }
    
    private func saveSettings() {
        settingsManager.openAIKey = openAIKey
        settingsManager.openRouterKey = openRouterKey
        settingsManager.geminiKey = geminiKey
        settingsManager.apiProvider = apiProvider
        settingsManager.defaultAction = defaultAction
        settingsManager.targetLanguage = targetLanguage
        settingsManager.saveSettings()
        showSaveConfirmation = true
    }
}

// MARK: - Add/Edit Custom Prompt View
struct AddCustomPromptView: View {
    @ObservedObject var settingsManager: SettingsManager
    var editingPrompt: CustomPrompt?
    var onDismiss: () -> Void
    
    @State private var name: String = ""
    @State private var prompt: String = ""
    @State private var keyEquivalent: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var isEditing: Bool {
        editingPrompt != nil
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(isEditing ? "Edit Custom Prompt" : "Add Custom Prompt")
                .font(.title2.bold())
            
            Form {
                Section("Menu Item Name") {
                    TextField("e.g., Summarize, Make Professional", text: $name)
                }
                
                Section("Custom Prompt") {
                    TextEditor(text: $prompt)
                        .frame(minHeight: 100)
                        .font(.body)
                }
                .help("This prompt will be combined with the selected text and sent to AI")
                
                Section("Keyboard Shortcut (Optional)") {
                    TextField("e.g., s, p, c (single character)", text: $keyEquivalent)
                        .onChange(of: keyEquivalent) { newValue in
                            // Limit to single character
                            if newValue.count > 1 {
                                keyEquivalent = String(newValue.prefix(1))
                            }
                        }
                }
                .help("Optional keyboard shortcut (Command + key)")
            }
            .formStyle(.grouped)
            .frame(width: 500, height: 350)
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    onDismiss()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button(isEditing ? "Update" : "Add") {
                    savePrompt()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || prompt.isEmpty)
            }
        }
        .padding()
        .onAppear {
            if let editing = editingPrompt {
                name = editing.name
                prompt = editing.prompt
                keyEquivalent = editing.keyEquivalent
            }
        }
    }
    
    private func savePrompt() {
        if let editing = editingPrompt {
            // Update existing prompt
            let updated = CustomPrompt(
                id: editing.id,
                name: name,
                prompt: prompt,
                keyEquivalent: keyEquivalent
            )
            settingsManager.updateCustomPrompt(updated)
        } else {
            // Add new prompt
            let newPrompt = CustomPrompt(
                name: name,
                prompt: prompt,
                keyEquivalent: keyEquivalent
            )
            settingsManager.addCustomPrompt(newPrompt)
        }
        onDismiss()
        dismiss()
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsManager())
}

