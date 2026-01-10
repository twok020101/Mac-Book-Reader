import Foundation
import EPUBKit
import Combine

public class EPUBParserService {
    @MainActor public static let shared = EPUBParserService()
    
    public init() {}
    
    public func parse(url: URL) -> EPUBDocument? {
        return EPUBDocument(url: url)
    }
    
    public func parseAsync(url: URL) async throws -> EPUBDocument {
        guard let document = EPUBDocument(url: url) else {
            throw EPUBParserError.invalidDocument
        }
        return document
    }
    
    public func cover(from document: EPUBDocument) -> Data? {
        if let coverURL = document.cover {
            return try? Data(contentsOf: coverURL)
        }
        return nil 
    }
}

public enum EPUBParserError: Error {
    case invalidDocument
}
