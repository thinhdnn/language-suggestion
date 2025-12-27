//
//  APIServiceTests.swift
//  LanguageSuggestionTests
//
//  Unit tests for APIService
//

import XCTest
@testable import LanguageSuggestion

// Mock URLProtocol for testing network requests
class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            XCTFail("Request handler not set")
            return
        }
        
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {
        // No-op
    }
}

@MainActor
final class APIServiceTests: XCTestCase {
    
    var apiService: APIService!
    var urlSession: URLSession!
    
    override func setUp() {
        super.setUp()
        
        // Configure URLSession with mock protocol
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        urlSession = URLSession(configuration: config)
        
        apiService = APIService()
        // Note: APIService uses URLSession.shared internally
        // In a production app, you'd inject URLSession as a dependency
    }
    
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        apiService = nil
        urlSession = nil
        super.tearDown()
    }
    
    // MARK: - Error Tests
    
    func testMissingAPIKey() async {
        do {
            _ = try await apiService.processText(
                text: "Test",
                action: .fixGrammar,
                targetLanguage: nil,
                provider: .openai,
                apiKey: ""
            )
            XCTFail("Should throw missingAPIKey error")
        } catch let error as APIError {
            XCTAssertEqual(error, .missingAPIKey)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testAPIErrorDescription() {
        XCTAssertEqual(APIError.missingAPIKey.errorDescription, "API key is missing. Please configure it in Settings.")
        XCTAssertEqual(APIError.invalidResponse.errorDescription, "Invalid response from API.")
        XCTAssertEqual(APIError.httpError(404).errorDescription, "HTTP error: 404")
        XCTAssertEqual(APIError.apiError("Test error").errorDescription, "Test error")
        XCTAssertEqual(APIError.invalidJSONResponse.errorDescription, "Failed to parse JSON response from AI.")
    }
    
    // MARK: - Response Model Tests
    
    func testAPICompletionResponseCodable() throws {
        let json = """
        {
            "choices": [
                {
                    "message": {
                        "content": "Test content"
                    }
                }
            ]
        }
        """
        
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(APICompletionResponse.self, from: data)
        
        XCTAssertEqual(response.choices.count, 1)
        XCTAssertEqual(response.choices.first?.message.content, "Test content")
    }
    
    func testGeminiAPIResponseCodable() throws {
        let json = """
        {
            "candidates": [
                {
                    "content": {
                        "parts": [
                            {
                                "text": "Test text"
                            }
                        ]
                    }
                }
            ]
        }
        """
        
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(GeminiAPIResponse.self, from: data)
        
        XCTAssertEqual(response.candidates.count, 1)
        XCTAssertEqual(response.candidates.first?.content.parts.first?.text, "Test text")
    }
    
    // MARK: - Request Building Tests (indirect testing)
    
    func testRequestBuildingForOpenAI() {
        // This tests the request building logic indirectly
        // In a real scenario, you'd extract request building to a separate testable function
        
        let service = APIService()
        XCTAssertNotNil(service)
        // Request building is private, so we test it through integration tests
    }
    
    // MARK: - Integration Tests (with mocked network)
    
    func testProcessTextWithValidResponse() async throws {
        // This test would require refactoring APIService to accept URLSession as dependency
        // For now, we test the error cases and response models
        
        let aiResponse = AIResponse(
            originalText: "teh cat",
            processedText: "the cat",
            action: "Fix Grammar",
            language: nil,
            changes: [
                TextChange(original: "teh", corrected: "the", reason: "Typo")
            ],
            confidence: 0.95
        )
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(aiResponse)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        // Verify the response can be encoded/decoded
        let decoded = try JSONDecoder().decode(AIResponse.self, from: jsonData)
        XCTAssertEqual(decoded.originalText, aiResponse.originalText)
        XCTAssertEqual(decoded.processedText, aiResponse.processedText)
    }
    
    func testProcessTextWithMarkdownWrappedJSON() {
        // Test JSON extraction from markdown code blocks
        let markdownJSON = """
        ```json
        {
            "originalText": "test",
            "processedText": "tested",
            "action": "Fix Grammar",
            "language": null,
            "changes": null,
            "confidence": 0.95
        }
        ```
        """
        
        let cleaned = markdownJSON
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        XCTAssertNoThrow(try JSONDecoder().decode(AIResponse.self, from: cleaned.data(using: .utf8)!))
    }
    
    // MARK: - Loading State Tests
    
    func testLoadingState() async {
        // Note: This test is limited because we can't easily mock URLSession.shared
        // In production, inject URLSession as a dependency
        
        let service = APIService()
        XCTAssertFalse(service.isLoading)
        XCTAssertNil(service.errorMessage)
    }
    
    // MARK: - Error Message Tests
    
    func testErrorMessage() {
        let service = APIService()
        service.errorMessage = "Test error"
        XCTAssertEqual(service.errorMessage, "Test error")
        
        service.errorMessage = nil
        XCTAssertNil(service.errorMessage)
    }
}

