import Foundation
import SwiftData

@Model
public final class ReadingProgress {
    public var book: Book?
    public var currentPage: Int           // NOW stores absolute page number (1-500)
    public var currentChapter: String?    // For reference/display only
    public var currentChapterIndex: Int?  // Spine index (0-indexed) for reliable restore
    public var currentSubPage: Int?       // Page within chapter (0-indexed)
    public var currentCFI: String?        // EPUB location (Content Fragment Identifier)
    public var totalPages: Int?
    public var percentComplete: Double
    public var lastReadDate: Date
    
    // Per-page reading time tracking for AI gating
    public var pageReadingTimes: [PageReadingRecord] = []
    
    public init(currentPage: Int = 0, currentChapter: String? = nil, currentChapterIndex: Int? = nil, currentSubPage: Int? = nil, currentCFI: String? = nil, totalPages: Int? = nil, percentComplete: Double = 0, lastReadDate: Date = Date()) {
        self.currentPage = currentPage
        self.currentChapter = currentChapter
        self.currentChapterIndex = currentChapterIndex
        self.currentSubPage = currentSubPage
        self.currentCFI = currentCFI
        self.totalPages = totalPages
        self.percentComplete = percentComplete
        self.lastReadDate = lastReadDate
    }
}

public struct PageReadingRecord: Codable {
    public let pageIdentifier: String  // Page number or CFI
    public let totalSecondsSpent: Int
    public var hasUnlockedAI: Bool { totalSecondsSpent >= 20 }
    
    public init(pageIdentifier: String, totalSecondsSpent: Int) {
        self.pageIdentifier = pageIdentifier
        self.totalSecondsSpent = totalSecondsSpent
    }
}
