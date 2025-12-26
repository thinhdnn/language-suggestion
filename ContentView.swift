//
//  ContentView.swift
//  LanguageSuggestion
//
//  Main interface for text input and output
//

import SwiftUI
import AppKit

struct ContentView: View {
    @Bindable var viewModel: ContentViewModel
    @Bindable var apiService: APIService
    @Bindable var settingsManager: SettingsManager
    @Bindable var accessibilityService: AccessibilityService
    
    init(
        apiService: APIService,
        accessibilityService: AccessibilityService,
        floatingOverlayManager: FloatingOverlayManager,
        settingsManager: SettingsManager,
        menuBarManager: MenuBarManager
    ) {
        let viewModel = ContentViewModel(
            apiService: apiService,
            accessibilityService: accessibilityService,
            floatingOverlayManager: floatingOverlayManager,
            settingsManager: settingsManager,
            menuBarManager: menuBarManager
        )
        self.viewModel = viewModel
        self.apiService = apiService
        self.settingsManager = settingsManager
        self.accessibilityService = accessibilityService
    }
    
    private var wordCount: Int {
        viewModel.inputText.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
    
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
            
            VStack(alignment: .leading, spacing: 14) {
                headerBar
                
                HStack(alignment: .top, spacing: 16) {
                    inputPanel
                        .frame(maxWidth: .infinity, minHeight: 320)
                    outputPanel
                        .frame(maxWidth: .infinity, minHeight: 320)
                }
                
                HStack {
                    Button {
                        viewModel.processText()
                    } label: {
                        Label("Process Now", systemImage: "arrow.right.circle.fill")
                            .font(.headline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(viewModel.inputText.isEmpty || apiService.isLoading || settingsManager.currentAPIKey.isEmpty)
                    .onHover { inside in
                        if inside {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    
                    if apiService.isLoading {
                        ProgressView()
                            .scaleEffect(0.9)
                            .padding(.leading, 6)
                    }
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { viewModel.processText() }) {
                    Label("Process", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(viewModel.inputText.isEmpty || apiService.isLoading || settingsManager.currentAPIKey.isEmpty)
            }
            
            ToolbarItem(placement: .secondaryAction) {
                Button(action: { viewModel.copyOutput() }) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(viewModel.outputText.isEmpty)
            }
            
            ToolbarItem(placement: .secondaryAction) {
                Button(action: { viewModel.clearAll() }) {
                    Label("Clear", systemImage: "trash")
                }
            }
            
            ToolbarItem(placement: .secondaryAction) {
                EmptyView()
            }
        }
        .alert("Error", isPresented: .constant(apiService.errorMessage != nil)) {
            Button("OK") {
                apiService.errorMessage = nil
            }
        } message: {
            Text(apiService.errorMessage ?? "")
        }
        .onAppear {
            viewModel.initialize()
        }
    }
    
    private var headerBar: some View {
        HStack(spacing: 8) {
            Label("LanguageSuggestion", systemImage: "wand.and.stars")
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            StatusPill(
                title: settingsManager.apiProvider.rawValue,
                systemImage: "antenna.radiowaves.left.and.right",
                color: .blue.opacity(0.15),
                textColor: .blue
            )
            
            StatusPill(
                title: viewModel.currentAction.rawValue,
                systemImage: viewModel.currentAction == .translate ? "globe" : "text.badge.checkmark",
                color: .purple.opacity(0.15),
                textColor: .purple
            )
            
            if apiService.isLoading {
                StatusPill(
                    title: "Running",
                    systemImage: "hourglass",
                    color: .orange.opacity(0.2),
                    textColor: .orange
                )
            }
            
            // Accessibility permission indicator
            Button(action: {
                viewModel.openAccessibilitySettings()
            }) {
                Text(accessibilityService.isAccessibilityEnabled ? "Accessibility ✓" : "Grant Permission")
                    .font(.caption)
                    .foregroundColor(accessibilityService.isAccessibilityEnabled ? .green : .orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(accessibilityService.isAccessibilityEnabled ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    )
            }
            .buttonStyle(.plain)
            .help(accessibilityService.isAccessibilityEnabled ? "Accessibility Enabled ✓" : "Click to Grant Accessibility Permission")
            .onHover { inside in
                if inside {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            
            // Settings button
            Button(action: {
                viewModel.openSettings()
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
            .help("Open Settings")
            .onHover { inside in
                if inside {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
        .padding(.horizontal, 10)
    }
    
    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Input")
                    .font(.title3.weight(.semibold))
                Spacer()
                Picker("Action", selection: $viewModel.currentAction) {
                    ForEach(ActionType.allCases, id: \.self) { action in
                        Text(action.rawValue).tag(action)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }
            
            if viewModel.currentAction == .translate {
                HStack(spacing: 8) {
                    Label("Target Language", systemImage: "globe")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("e.g. Vietnamese", text: $viewModel.targetLanguage)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                }
            }
            
            RichCard {
                TextEditor(text: $viewModel.inputText)
                    .font(.system(.body, design: .default))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.vertical, 8)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 12) {
                    Label("\(wordCount) words", systemImage: "character.cursor.ibeam")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if viewModel.inputText.isEmpty {
                        Text("Paste or type your text here to translate or fix grammar.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .overlay(alignment: .bottomTrailing) {
                if !viewModel.floatingOverlayManager.isOverlayVisible && !viewModel.isScanningForOverlay {
                    Button(action: { viewModel.showOverlay() }) {
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.title3)
                            .foregroundColor(.blue.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Retry showing overlay on supported apps (Teams, Notes)")
                    .padding(12)
                    .onHover { inside in
                        if inside {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                } else if viewModel.isScanningForOverlay {
                    ProgressView()
                        .controlSize(.small)
                        .padding(12)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.9)))
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
        .frame(minWidth: 360)
    }
    
    private var outputPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            outputHeader
            
            if viewModel.showChanges && !viewModel.changes.isEmpty {
                changesSection
            }
            
            outputTextSection
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.9)))
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
        .frame(minWidth: 360)
    }
    
    @ViewBuilder
    private var outputHeader: some View {
        HStack {
            Text("Output")
                .font(.title3.weight(.semibold))
            Spacer()
            if let confidence = viewModel.confidence {
                StatusPill(
                    title: "\(Int(confidence * 100))% confidence",
                    systemImage: "checkmark.seal.fill",
                    color: .green.opacity(0.15),
                    textColor: .green
                )
            }
            if !viewModel.changes.isEmpty {
                Button(action: { viewModel.showChanges.toggle() }) {
                    Label(viewModel.showChanges ? "Hide Changes" : "Show Changes", systemImage: viewModel.showChanges ? "eye.slash" : "eye")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .onHover { inside in
                    if inside {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var changesSection: some View {
        RichCard {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.changes.indices, id: \.self) { idx in
                        ChangeRow(change: viewModel.changes[idx])
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 180)
        }
    }
    
    private var outputTextSection: some View {
        RichCard {
            ScrollView {
                Text(viewModel.outputText.isEmpty ? "Processed text will appear here..." : viewModel.outputText)
                    .font(.system(.body, design: .default))
                    .foregroundColor(viewModel.outputText.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .textSelection(.enabled)
            }
        }
    }
    
}

private struct StatusPill: View {
    let title: String
    let systemImage: String
    let color: Color
    let textColor: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.caption)
        .foregroundColor(textColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(color))
    }
}

private struct RichCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.textBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

private struct ChangeRow: View {
    let change: TextChange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(change.original)
                    .strikethrough()
                    .foregroundColor(.red)
                Text("→")
                    .foregroundColor(.secondary)
                Text(change.corrected)
                    .foregroundColor(.green)
            }
            .font(.system(.body, design: .monospaced))
            
            if !change.reason.isEmpty {
                Text(change.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

#Preview {
    let settingsManager = SettingsManager()
    let apiService = APIService()
    let accessibilityService = AccessibilityService()
    let floatingOverlayManager = FloatingOverlayManager()
    let menuBarManager = MenuBarManager()
    
    return ContentView(
        apiService: apiService,
        accessibilityService: accessibilityService,
        floatingOverlayManager: floatingOverlayManager,
        settingsManager: settingsManager,
        menuBarManager: menuBarManager
    )
    .frame(width: 800, height: 600)
}

// Teams Elements Viewer
struct TeamsElementsViewer: View {
    @Bindable var accessibilityService: AccessibilityService
    @Binding var elements: [AccessibleElement]
    @Binding var isLoading: Bool
    @State private var searchText: String = ""
    @State private var selectedRole: String = "All"
    @State private var maxDepth: Int = 10
    let onSelectElement: (AccessibleElement) -> Void
    
    private let roleOptions = ["All", "AXTextField", "AXTextArea", "AXButton", "AXStaticText", "AXGroup", "AXScrollArea", "AXWindow"]
    
    var filteredElements: [AccessibleElement] {
        var filtered = elements
        
        // Filter by role
        if selectedRole != "All" {
            filtered = filtered.filter { $0.role == selectedRole }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { element in
                element.role.localizedCaseInsensitiveContains(searchText) ||
                element.title?.localizedCaseInsensitiveContains(searchText) == true ||
                element.value?.localizedCaseInsensitiveContains(searchText) == true ||
                element.identifier?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        return filtered
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Teams UI Elements Explorer")
                    .font(.title2.bold())
                
                Spacer()
                
                Button("Close") {
                    // Close handled by parent
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // Controls
            VStack(spacing: 12) {
                HStack {
                    Button(action: loadElements) {
                        Label(isLoading ? "Loading..." : "Scan Teams Elements", systemImage: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                    
                    Stepper("Max Depth: \(maxDepth)", value: $maxDepth, in: 1...30)
                        .frame(width: 200)
                    
                    Spacer()
                    
                    Text("\(filteredElements.count) elements")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                
                HStack {
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    
                    Picker("Role", selection: $selectedRole) {
                        ForEach(roleOptions, id: \.self) { role in
                            Text(role).tag(role)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }
            }
            .padding()
            
            Divider()
            
            // Elements List
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Scanning Teams UI...")
                        .scaleEffect(1.2)
                    Spacer()
                }
            } else if elements.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No elements scanned yet")
                        .font(.headline)
                    Text("Click 'Scan Teams Elements' to explore the UI")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if filteredElements.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No matching elements")
                        .font(.headline)
                    Text("Try adjusting your filters")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(filteredElements) { element in
                            ElementRow(element: element, onSelect: {
                                onSelectElement(element)
                            })
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    private func loadElements() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let scannedElements = accessibilityService.getAllTeamsElements(maxDepth: maxDepth)
            
            DispatchQueue.main.async {
                elements = scannedElements
                isLoading = false
            }
        }
    }
}

// Element Row
struct ElementRow: View {
    let element: AccessibleElement
    let onSelect: () -> Void
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Indentation
                Text(String(repeating: "  ", count: element.depth))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.clear)
                
                // Role badge
                Text(element.role)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(roleColor(element.role).opacity(0.2))
                    .foregroundColor(roleColor(element.role))
                    .cornerRadius(4)
                
                // Title/Value
                if let title = element.title, !title.isEmpty {
                    Text(title)
                        .font(.body)
                        .lineLimit(1)
                }
                
                if let value = element.value, !value.isEmpty, element.title != element.value {
                    Text(value)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Indicators
                if element.focused {
                    Image(systemName: "circle.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                
                // Actions
                if element.value != nil && !element.value!.isEmpty {
                    Button(action: onSelect) {
                        Image(systemName: "arrow.down.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Use this text")
                }
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(element.focused ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(4)
            
            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    if let identifier = element.identifier {
                        DetailRow(label: "Identifier", value: identifier)
                    }
                    if let elementDescription = element.elementDescription {
                        DetailRow(label: "Description", value: elementDescription)
                    }
                    if let position = element.position {
                        DetailRow(label: "Position", value: "(\(Int(position.x)), \(Int(position.y)))")
                    }
                    if let size = element.size {
                        DetailRow(label: "Size", value: "\(Int(size.width)) × \(Int(size.height))")
                    }
                    DetailRow(label: "Depth", value: "\(element.depth)")
                    DetailRow(label: "Enabled", value: element.enabled ? "Yes" : "No")
                }
                .padding(.leading, 40)
                .padding(.vertical, 4)
                .font(.caption)
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(isExpanded ? 0.5 : 0))
    }
    
    private func roleColor(_ role: String) -> Color {
        switch role {
        case "AXTextField", "AXTextArea":
            return .blue
        case "AXButton":
            return .green
        case "AXStaticText":
            return .purple
        case "AXWindow":
            return .orange
        case "AXGroup":
            return .gray
        default:
            return .secondary
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text("\(label):")
                .foregroundColor(.secondary)
            Text(value)
                .foregroundColor(.primary)
        }
    }
}

// Suggestion popup content
struct SuggestionPopupContent: View {
    let title: String
    let originalText: String
    let suggestedText: String
    let onCopy: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(.purple)
                Text(title)
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Original text
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "text.quote")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Original:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ScrollView {
                    Text(originalText)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                }
                .frame(minHeight: 60, maxHeight: .infinity)
            }
            
            // Suggested text
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Suggestion:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ScrollView {
                    Text(suggestedText)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                }
                .frame(minHeight: 60, maxHeight: .infinity)
            }
            
            // Actions
            HStack(spacing: 12) {
                Button(action: onCopy) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                Button(action: onClose) {
                    Text("Close")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(minWidth: 300, minHeight: 200)
    }
}


