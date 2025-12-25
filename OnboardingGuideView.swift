//
//  OnboardingGuideView.swift
//  LanguageSuggestion
//
//  Onboarding guide for first-time users
//

import SwiftUI

struct OnboardingGuideView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @ObservedObject var accessibilityService: AccessibilityService
    
    @State private var currentStep: OnboardingStep = .welcome
    @State private var openAIKey: String = ""
    @State private var openRouterKey: String = ""
    @State private var geminiKey: String = ""
    @State private var selectedProvider: APIProvider = .openai
    @State private var showKeySaved = false
    
    var onComplete: () -> Void
    
    enum OnboardingStep {
        case welcome
        case apiKey
        case accessibility
        case complete
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.sRGB, red: 0.97, green: 0.98, blue: 1.0, opacity: 1.0),
                    Color(.sRGB, red: 0.94, green: 0.96, blue: 1.0, opacity: 1.0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                
                // Content
                ScrollView {
                    VStack(spacing: 32) {
                        switch currentStep {
                        case .welcome:
                            welcomeStep
                        case .apiKey:
                            apiKeyStep
                        case .accessibility:
                            accessibilityStep
                        case .complete:
                            completeStep
                        }
                    }
                    .padding(40)
                    .frame(maxWidth: 600)
                }
                
                // Navigation buttons
                navigationButtons
                    .padding(24)
                    .background(
                        Rectangle()
                            .fill(Color(NSColor.windowBackgroundColor).opacity(0.8))
                            .shadow(color: Color.black.opacity(0.1), radius: 8, y: -4)
                    )
            }
        }
        .frame(width: 700, height: 600)
        .onAppear {
            loadCurrentKeys()
            checkInitialState()
            // Check permission immediately when view appears
            accessibilityService.checkAccessibilityPermission()
        }
        .task(id: currentStep) {
            // Periodically check accessibility permission when on accessibility step
            if currentStep == .accessibility {
                while currentStep == .accessibility {
                    accessibilityService.checkAccessibilityPermission()
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
            }
        }
        .onChange(of: accessibilityService.isAccessibilityEnabled) { enabled in
            if enabled && currentStep == .accessibility {
                // Auto-advance when permission is granted
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    currentStep = .complete
                }
            }
        }
        .onChange(of: currentStep) { newStep in
            // Check permission immediately when switching to accessibility step
            if newStep == .accessibility {
                accessibilityService.checkAccessibilityPermission()
            }
        }
        .onChange(of: settingsManager.currentAPIKey) { key in
            if !key.isEmpty && currentStep == .apiKey {
                showKeySaved = true
                // Auto-advance after a moment
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if !accessibilityService.isAccessibilityEnabled {
                        currentStep = .accessibility
                    } else {
                        currentStep = .complete
                    }
                }
            }
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach([OnboardingStep.welcome, .apiKey, .accessibility, .complete], id: \.self) { step in
                Circle()
                    .fill(stepProgressColor(for: step))
                    .frame(width: 12, height: 12)
            }
        }
        .padding(.top, 20)
        .padding(.horizontal, 24)
    }
    
    private func stepProgressColor(for step: OnboardingStep) -> Color {
        let stepOrder: [OnboardingStep] = [.welcome, .apiKey, .accessibility, .complete]
        guard let currentIndex = stepOrder.firstIndex(of: currentStep),
              let stepIndex = stepOrder.firstIndex(of: step) else {
            return .gray.opacity(0.3)
        }
        
        if stepIndex < currentIndex {
            return .green
        } else if stepIndex == currentIndex {
            return .blue
        } else {
            return .gray.opacity(0.3)
        }
    }
    
    // MARK: - Welcome Step
    
    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 64))
                .foregroundColor(.purple)
            
            Text("Welcome to LanguageSuggestion")
                .font(.title.bold())
            
            Text("Let's get you started in just a few steps")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 16) {
                OnboardingFeatureRow(
                    icon: "key.fill",
                    title: "Add API Key",
                    description: "Configure your AI service provider API key"
                )
                
                OnboardingFeatureRow(
                    icon: "lock.shield.fill",
                    title: "Grant Permissions",
                    description: "Enable accessibility to capture text from other apps"
                )
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - API Key Step
    
    private var apiKeyStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("Add Your API Key")
                .font(.title.bold())
            
            Text("Choose your AI provider and enter your API key to get started")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                // Provider selection
                Picker("API Provider", selection: $selectedProvider) {
                    ForEach(APIProvider.allCases, id: \.self) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedProvider) { _ in
                    loadCurrentKeys()
                }
                
                // API Key input
                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedProvider == .openai ? "OpenAI API Key" : 
                         selectedProvider == .openrouter ? "OpenRouter API Key" : 
                         "Gemini API Key")
                        .font(.headline)
                    
                    SecureField("Enter your API key", text: currentKeyBinding)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                        .disableAutocorrection(true)
                    
                    if showKeySaved {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("API key saved successfully!")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
            }
            .padding(.top, 8)
        }
    }
    
    private var currentKeyBinding: Binding<String> {
        Binding(
            get: {
                switch selectedProvider {
                case .openai: return openAIKey
                case .openrouter: return openRouterKey
                case .gemini: return geminiKey
                }
            },
            set: { newValue in
                switch selectedProvider {
                case .openai: openAIKey = newValue
                case .openrouter: openRouterKey = newValue
                case .gemini: geminiKey = newValue
                }
            }
        )
    }
    
    // MARK: - Accessibility Step
    
    private var accessibilityStep: some View {
        VStack(spacing: 24) {
            Image(systemName: accessibilityService.isAccessibilityEnabled ? "checkmark.shield.fill" : "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(accessibilityService.isAccessibilityEnabled ? .green : .orange)
            
            Text(accessibilityService.isAccessibilityEnabled ? "Permission Granted!" : "Grant Accessibility Permission")
                .font(.title.bold())
            
            if accessibilityService.isAccessibilityEnabled {
                Text("Great! Accessibility permission is enabled. You can now capture text from other applications.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("LanguageSuggestion needs accessibility permission to:")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            PermissionFeatureRow(
                                icon: "text.cursor",
                                text: "Capture text from Microsoft Teams"
                            )
                            PermissionFeatureRow(
                                icon: "note.text",
                                text: "Capture text from Apple Notes"
                            )
                            PermissionFeatureRow(
                                icon: "app.badge",
                                text: "Show suggestions overlay on supported apps"
                            )
                        }
                        .padding(.leading, 8)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How to grant permission:")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 8) {
                                Text("1.")
                                    .font(.body.bold())
                                    .foregroundColor(.blue)
                                Text("Click \"Open System Settings\" button below")
                                    .font(.body)
                            }
                            
                            HStack(alignment: .top, spacing: 8) {
                                Text("2.")
                                    .font(.body.bold())
                                    .foregroundColor(.blue)
                                Text("In System Settings, find \"LanguageSuggestion\" in the list")
                                    .font(.body)
                            }
                            
                            HStack(alignment: .top, spacing: 8) {
                                Text("3.")
                                    .font(.body.bold())
                                    .foregroundColor(.blue)
                                Text("Turn on the toggle switch next to \"LanguageSuggestion\"")
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                            
                            HStack(alignment: .top, spacing: 8) {
                                Text("4.")
                                    .font(.body.bold())
                                    .foregroundColor(.blue)
                                Text("Return to this app - permission will be detected automatically")
                                    .font(.body)
                            }
                        }
                        .padding(.leading, 8)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
            }
        }
    }
    
    // MARK: - Complete Step
    
    private var completeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("You're All Set!")
                .font(.title.bold())
            
            Text("LanguageSuggestion is ready to use. Start fixing grammar and translating text right away!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack {
            if currentStep != .welcome {
                Button("Back") {
                    goToPreviousStep()
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
            }
            
            Spacer()
            
            if currentStep == .apiKey {
                Button("Save API Key") {
                    saveAPIKey()
                }
                .buttonStyle(.borderedProminent)
                .disabled(currentKeyBinding.wrappedValue.isEmpty)
            } else if currentStep == .accessibility && !accessibilityService.isAccessibilityEnabled {
                HStack(spacing: 12) {
                    Button("Check Again") {
                        accessibilityService.checkAccessibilityPermission()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Open System Settings") {
                        accessibilityService.openAccessibilitySettings()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if currentStep == .complete {
                Button("Get Started") {
                    completeOnboarding()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Next") {
                    goToNextStep()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func checkInitialState() {
        // Check if API key exists
        if settingsManager.currentAPIKey.isEmpty {
            currentStep = .apiKey
        } else if !accessibilityService.isAccessibilityEnabled {
            currentStep = .accessibility
        } else {
            // Both are done, show complete
            currentStep = .complete
        }
    }
    
    private func loadCurrentKeys() {
        openAIKey = settingsManager.openAIKey
        openRouterKey = settingsManager.openRouterKey
        geminiKey = settingsManager.geminiKey
        selectedProvider = settingsManager.apiProvider
    }
    
    private func saveAPIKey() {
        settingsManager.openAIKey = openAIKey
        settingsManager.openRouterKey = openRouterKey
        settingsManager.geminiKey = geminiKey
        settingsManager.apiProvider = selectedProvider
        settingsManager.saveSettings()
        
        showKeySaved = true
        
        // Check if we should move to next step
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !accessibilityService.isAccessibilityEnabled {
                currentStep = .accessibility
            } else {
                currentStep = .complete
            }
        }
    }
    
    private func goToNextStep() {
        switch currentStep {
        case .welcome:
            if settingsManager.currentAPIKey.isEmpty {
                currentStep = .apiKey
            } else if !accessibilityService.isAccessibilityEnabled {
                currentStep = .accessibility
            } else {
                currentStep = .complete
            }
        case .apiKey:
            if !accessibilityService.isAccessibilityEnabled {
                currentStep = .accessibility
            } else {
                currentStep = .complete
            }
        case .accessibility:
            currentStep = .complete
        case .complete:
            completeOnboarding()
        }
    }
    
    private func goToPreviousStep() {
        switch currentStep {
        case .apiKey:
            currentStep = .welcome
        case .accessibility:
            if settingsManager.currentAPIKey.isEmpty {
                currentStep = .apiKey
            } else {
                currentStep = .welcome
            }
        case .complete:
            if !accessibilityService.isAccessibilityEnabled {
                currentStep = .accessibility
            } else if settingsManager.currentAPIKey.isEmpty {
                currentStep = .apiKey
            } else {
                currentStep = .welcome
            }
        default:
            break
        }
    }
    
    private func completeOnboarding() {
        // Mark onboarding as completed
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        onComplete()
    }
}

// MARK: - Supporting Views

struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct PermissionFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.body)
        }
    }
}

