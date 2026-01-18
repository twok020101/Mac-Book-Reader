import Foundation
import GoogleGenerativeAI

@MainActor
public class GeminiService: ObservableObject {
    public static let shared = GeminiService()
    
    @Published public var isConfigured: Bool = false
    @Published public var isInitializing: Bool = false
    private var model: GenerativeModel?
    private let keychainService = KeychainService.shared
    
    private init() {
        // Initialization is handled explicitly by calling initialize()
    }
    
    /// Initialize the service by loading API key from keychain
    public func initialize() async {
        guard !isInitializing else { return }
        isInitializing = true
        
        do {
            if let key = try await keychainService.getAPIKey(), !key.isEmpty {
                self.model = GenerativeModel(name: "gemini-3-flash-preview", apiKey: key)
                self.isConfigured = true
            }
        } catch {
            print("Failed to load API key from keychain: \(error)")
        }
        
        isInitializing = false
    }
    
    public func configure(apiKey: String) async throws {
        guard !apiKey.isEmpty else {
            throw GeminiError.invalidAPIKey
        }
        
        do {
            try await keychainService.saveAPIKey(apiKey)
            self.model = GenerativeModel(name: "gemini-3-flash-preview", apiKey: apiKey)
            self.isConfigured = true
        } catch {
            throw GeminiError.keychainError(error)
        }
    }
    
    public func generateContent(prompt: String) async throws -> String {
        guard let model = model else {
            throw GeminiError.notConfigured
        }
        
        let response = try await model.generateContent(prompt)
        
        // Better error handling for response
        guard let text = response.text, !text.isEmpty else {
            // Check if blocked by safety filters
            if !response.candidates.isEmpty {
                throw GeminiError.contentFiltered
            }
            throw GeminiError.invalidResponse
        }
        
        return text
    }
    
    public func getApiKey() async throws -> String? {
        return try await keychainService.getAPIKey()
    }
    
    public func clearKey() async throws {
        try await keychainService.deleteAPIKey()
        self.model = nil
        self.isConfigured = false
    }
}

public enum GeminiError: Error, LocalizedError {
    case notConfigured
    case invalidResponse
    case contentFiltered
    case keychainError(Error)
    case invalidAPIKey
    
    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI is not configured. Please enter your API key."
        case .invalidResponse:
            return "Received an invalid response from AI."
        case .contentFiltered:
            return "Response was blocked by safety filters. Try rephrasing your question."
        case .keychainError(let error):
            return "Failed to save API key: \(error.localizedDescription)"
        case .invalidAPIKey:
            return "API key cannot be empty."
        }
    }
}
