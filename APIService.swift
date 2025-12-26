//
//  APIService.swift
//  LanguageSuggestion
//
//  API integration for OpenAI, OpenRouter, and Gemini
//

import Foundation
import Observation

protocol APIServiceProtocol {
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    func processText(
        text: String,
        action: ActionType,
        targetLanguage: String?,
        provider: APIProvider,
        apiKey: String
    ) async throws -> AIResponse
    func processTextWithCustomPrompt(
        text: String,
        customPrompt: String,
        provider: APIProvider,
        apiKey: String
    ) async throws -> AIResponse
}

@Observable
final class APIService: APIServiceProtocol {
    var isLoading = false
    var errorMessage: String?
    
    private let session = URLSession.shared
    
    func processText(
        text: String,
        action: ActionType,
        targetLanguage: String?,
        provider: APIProvider,
        apiKey: String
    ) async throws -> AIResponse {
        guard !apiKey.isEmpty else {
            throw APIError.missingAPIKey
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let url: URL
        let requestBody: [String: Any]
        
        switch provider {
        case .openai:
            url = URL(string: "https://api.openai.com/v1/chat/completions")!
            requestBody = buildOpenAIRequest(text: text, action: action, targetLanguage: targetLanguage)
        case .openrouter:
            url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
            requestBody = buildOpenRouterRequest(text: text, action: action, targetLanguage: targetLanguage)
        case .gemini:
            url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)")!
            requestBody = buildGeminiRequest(text: text, action: action, targetLanguage: targetLanguage)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        switch provider {
        case .openai:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        case .openrouter:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("LanguageSuggestion/1.0", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("LanguageSuggestion", forHTTPHeaderField: "X-Title")
        case .gemini:
            // Gemini API key is passed as query parameter, no Authorization header needed
            break
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw APIError.apiError(message)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        // Handle Gemini's different response format
        let content: String
        if provider == .gemini {
            let geminiResponse = try JSONDecoder().decode(GeminiAPIResponse.self, from: data)
            guard let text = geminiResponse.candidates.first?.content.parts.first?.text else {
                throw APIError.invalidResponse
            }
            content = text
        } else {
            let apiResponse = try JSONDecoder().decode(APICompletionResponse.self, from: data)
            guard let responseContent = apiResponse.choices.first?.message.content else {
                throw APIError.invalidResponse
            }
            content = responseContent
        }
        
        // Parse JSON response from AI
        guard let jsonData = content.data(using: .utf8),
              let aiResponse = try? JSONDecoder().decode(AIResponse.self, from: jsonData) else {
            // If JSON parsing fails, try to extract JSON from markdown code blocks
            let cleanedContent = content
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let cleanedData = cleanedContent.data(using: .utf8),
                  let aiResponse = try? JSONDecoder().decode(AIResponse.self, from: cleanedData) else {
                throw APIError.invalidJSONResponse
            }
            return aiResponse
        }
        
        return aiResponse
    }
    
    // Process text with custom prompt
    func processTextWithCustomPrompt(
        text: String,
        customPrompt: String,
        provider: APIProvider,
        apiKey: String
    ) async throws -> AIResponse {
        guard !apiKey.isEmpty else {
            throw APIError.missingAPIKey
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let url: URL
        let requestBody: [String: Any]
        
        switch provider {
        case .openai:
            url = URL(string: "https://api.openai.com/v1/chat/completions")!
            requestBody = buildCustomPromptOpenAIRequest(text: text, customPrompt: customPrompt)
        case .openrouter:
            url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
            requestBody = buildCustomPromptOpenRouterRequest(text: text, customPrompt: customPrompt)
        case .gemini:
            url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)")!
            requestBody = buildCustomPromptGeminiRequest(text: text, customPrompt: customPrompt)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        switch provider {
        case .openai:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        case .openrouter:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("LanguageSuggestion/1.0", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("LanguageSuggestion", forHTTPHeaderField: "X-Title")
        case .gemini:
            // Gemini API key is passed as query parameter, no Authorization header needed
            break
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw APIError.apiError(message)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let apiResponse = try JSONDecoder().decode(APICompletionResponse.self, from: data)
        
        guard let content = apiResponse.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        // Parse JSON response from AI
        guard let jsonData = content.data(using: .utf8),
              let aiResponse = try? JSONDecoder().decode(AIResponse.self, from: jsonData) else {
            // If JSON parsing fails, try to extract JSON from markdown code blocks
            let cleanedContent = content
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let cleanedData = cleanedContent.data(using: .utf8),
                  let aiResponse = try? JSONDecoder().decode(AIResponse.self, from: cleanedData) else {
                throw APIError.invalidJSONResponse
            }
            return aiResponse
        }
        
        return aiResponse
    }
    
    private func buildOpenAIRequest(text: String, action: ActionType, targetLanguage: String?) -> [String: Any] {
        let systemPrompt: String
        let userPrompt: String
        
        switch action {
        case .translate:
            let lang = targetLanguage ?? "English"
            systemPrompt = "You are a professional translator. Always respond with valid JSON only, no markdown, no explanations."
            userPrompt = """
            Translate the following text to \(lang). Return the result as a JSON object with this exact structure:
            {
                "originalText": "original text here",
                "processedText": "translated text here",
                "action": "Translate",
                "language": "\(lang)",
                "changes": null,
                "confidence": 0.95
            }
            
            Text to translate: \(text)
            """
        case .fixGrammar:
            systemPrompt = "You are a professional grammar checker. Always respond with valid JSON only, no markdown, no explanations."
            userPrompt = """
            Fix grammar and spelling errors in the following text. Return the result as a JSON object with this exact structure:
            {
                "originalText": "original text here",
                "processedText": "corrected text here",
                "action": "Fix Grammar",
                "language": null,
                "changes": [
                    {
                        "original": "incorrect word",
                        "corrected": "correct word",
                        "reason": "grammar rule explanation"
                    }
                ],
                "confidence": 0.95
            }
            
            Text to fix: \(text)
            """
        }
        
        return [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "response_format": [
                "type": "json_object"
            ],
            "temperature": 0.3
        ]
    }
    
    private func buildOpenRouterRequest(text: String, action: ActionType, targetLanguage: String?) -> [String: Any] {
        let systemPrompt: String
        let userPrompt: String
        
        switch action {
        case .translate:
            let lang = targetLanguage ?? "English"
            systemPrompt = "You are a professional translator. Always respond with valid JSON only, no markdown, no explanations."
            userPrompt = """
            Translate the following text to \(lang). Return the result as a JSON object with this exact structure:
            {
                "originalText": "original text here",
                "processedText": "translated text here",
                "action": "Translate",
                "language": "\(lang)",
                "changes": null,
                "confidence": 0.95
            }
            
            Text to translate: \(text)
            """
        case .fixGrammar:
            systemPrompt = "You are a professional grammar checker. Always respond with valid JSON only, no markdown, no explanations."
            userPrompt = """
            Fix grammar and spelling errors in the following text. Return the result as a JSON object with this exact structure:
            {
                "originalText": "original text here",
                "processedText": "corrected text here",
                "action": "Fix Grammar",
                "language": null,
                "changes": [
                    {
                        "original": "incorrect word",
                        "corrected": "correct word",
                        "reason": "grammar rule explanation"
                    }
                ],
                "confidence": 0.95
            }
            
            Text to fix: \(text)
            """
        }
        
        return [
            "model": "openai/gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.3
        ]
    }
    
    private func buildCustomPromptOpenAIRequest(text: String, customPrompt: String) -> [String: Any] {
        let systemPrompt = "You are a helpful AI assistant. Always respond with valid JSON only, no markdown, no explanations."
        let userPrompt = """
        \(customPrompt)
        
        Return the result as a JSON object with this exact structure:
        {
            "originalText": "original text here",
            "processedText": "processed/transformed text here",
            "action": "Custom Prompt",
            "language": null,
            "changes": null,
            "confidence": 0.95
        }
        
        Text to process: \(text)
        """
        
        return [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "response_format": [
                "type": "json_object"
            ],
            "temperature": 0.3
        ]
    }
    
    private func buildCustomPromptOpenRouterRequest(text: String, customPrompt: String) -> [String: Any] {
        let systemPrompt = "You are a helpful AI assistant. Always respond with valid JSON only, no markdown, no explanations."
        let userPrompt = """
        \(customPrompt)
        
        Return the result as a JSON object with this exact structure:
        {
            "originalText": "original text here",
            "processedText": "processed/transformed text here",
            "action": "Custom Prompt",
            "language": null,
            "changes": null,
            "confidence": 0.95
        }
        
        Text to process: \(text)
        """
        
        return [
            "model": "openai/gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.3
        ]
    }
    
    private func buildGeminiRequest(text: String, action: ActionType, targetLanguage: String?) -> [String: Any] {
        let systemInstruction: String
        let userPrompt: String
        
        switch action {
        case .translate:
            let lang = targetLanguage ?? "English"
            systemInstruction = "You are a professional translator. Always respond with valid JSON only, no markdown, no explanations."
            userPrompt = """
            Translate the following text to \(lang). Return the result as a JSON object with this exact structure:
            {
                "originalText": "original text here",
                "processedText": "translated text here",
                "action": "Translate",
                "language": "\(lang)",
                "changes": null,
                "confidence": 0.95
            }
            
            Text to translate: \(text)
            """
        case .fixGrammar:
            systemInstruction = "You are a professional grammar checker. Always respond with valid JSON only, no markdown, no explanations."
            userPrompt = """
            Fix grammar and spelling errors in the following text. Return the result as a JSON object with this exact structure:
            {
                "originalText": "original text here",
                "processedText": "corrected text here",
                "action": "Fix Grammar",
                "language": null,
                "changes": [
                    {
                        "original": "incorrect word",
                        "corrected": "correct word",
                        "reason": "grammar rule explanation"
                    }
                ],
                "confidence": 0.95
            }
            
            Text to fix: \(text)
            """
        }
        
        return [
            "contents": [
                [
                    "parts": [
                        ["text": userPrompt]
                    ]
                ]
            ],
            "systemInstruction": [
                "parts": [
                    ["text": systemInstruction]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "responseMimeType": "application/json"
            ]
        ]
    }
    
    private func buildCustomPromptGeminiRequest(text: String, customPrompt: String) -> [String: Any] {
        let systemInstruction = "You are a helpful AI assistant. Always respond with valid JSON only, no markdown, no explanations."
        let userPrompt = """
        \(customPrompt)
        
        Return the result as a JSON object with this exact structure:
        {
            "originalText": "original text here",
            "processedText": "processed/transformed text here",
            "action": "Custom Prompt",
            "language": null,
            "changes": null,
            "confidence": 0.95
        }
        
        Text to process: \(text)
        """
        
        return [
            "contents": [
                [
                    "parts": [
                        ["text": userPrompt]
                    ]
                ]
            ],
            "systemInstruction": [
                "parts": [
                    ["text": systemInstruction]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "responseMimeType": "application/json"
            ]
        ]
    }
}

// API Response Structures
struct APICompletionResponse: Codable {
    let choices: [Choice]
}

struct Choice: Codable {
    let message: Message
}

struct Message: Codable {
    let content: String
}

// Gemini API Response Structures
struct GeminiAPIResponse: Codable {
    let candidates: [GeminiCandidate]
}

struct GeminiCandidate: Codable {
    let content: GeminiContent
}

struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

struct GeminiPart: Codable {
    let text: String
}

// API Errors
enum APIError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case invalidJSONResponse
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key is missing. Please configure it in Settings."
        case .invalidResponse:
            return "Invalid response from API."
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return message
        case .invalidJSONResponse:
            return "Failed to parse JSON response from AI."
        }
    }
}

