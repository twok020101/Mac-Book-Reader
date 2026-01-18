import Foundation
import EPUBKit
import SwiftData

@MainActor
public class ReaderViewModel: ObservableObject {
    @Published public var book: Book
    @Published public var currentChapterURL: URL?
    @Published public var totalSubPages: Int = 1 {
        didSet {
            //print("DEBUG: totalSubPages changed from \(oldValue) to \(totalSubPages)")
            // Track actual page count (replaces estimate from pre-calculation)
            let oldEstimate = chapterPageCounts[currentChapterIndex] ?? 0
            chapterPageCounts[currentChapterIndex] = totalSubPages
            //print("DEBUG: Chapter \(currentChapterIndex): \(oldEstimate) est → \(totalSubPages) actual, total absolute: \(totalAbsolutePages)")
        }
    }
    @Published public var currentSubPage: Int = 0 {
        didSet {
            //print("DEBUG: currentSubPage changed from \(oldValue) to \(currentSubPage)")
            if oldValue != currentSubPage {
                saveProgress()
                loadPageReadingTime() // Load accumulated time for this page
            }
        }
    }
    @Published public var pendingScrollToFragment: String?
    
    @Published public var currentChapterIndex: Int = 0 {
        didSet {
            if oldValue != currentChapterIndex {
                updateChapterURL()
                saveProgress()
            }
        }
    }
    @Published public var epubDocument: EPUBDocument?
    
    // MARK: - Absolute Page Tracking
    
    // Track page count for each chapter as they load
    private var chapterPageCounts: [Int: Int] = [:]  // [chapterIndex: pageCount]
    
    // Computed: absolute page number (1-indexed for user display)
    public var absolutePageNumber: Int {
        var absolute = 0
        // Sum pages from all previous chapters
        for i in 0..<currentChapterIndex {
            absolute += chapterPageCounts[i] ?? 0
        }
        // Add current page within chapter
        absolute += currentSubPage + 1  // +1 for 1-indexing
        return absolute
    }
    
    // Computed: total pages across entire book
    public var totalAbsolutePages: Int {
        return chapterPageCounts.values.reduce(0, +)
    }
    
    // Cached for chapter navigation
    private var contentBaseURL: URL?
    
    // Alias for ReaderToolbar compatibility
    public var currentPage: Int {
        get { currentChapterIndex }
        set { currentChapterIndex = newValue }
    }
    
    public var currentChapterTitle: String? {
        guard let document = epubDocument, currentChapterIndex < document.spine.items.count else { return nil }
        let item = document.spine.items[currentChapterIndex]
        // Attempt to find title from TOC matching this item's idref or content
        return findTitle(in: document.tableOfContents.subTable, for: item) ?? "Chapter \(currentChapterIndex + 1)"
    }
    

    
    // AI Gating and Time Tracking
    @Published public var timeOnCurrentPage: TimeInterval = 0
    private var timeTrackingTimer: Timer?
    
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    
    // UI State
    @Published public var showChapterList: Bool = true  // Open by default
    @Published public var showNotes: Bool = false
    
    // Text selection for notes
    @Published public var selectedText: String = ""
    
    // Pending navigation (for jump-to-location from notes)
    public var pendingChapterIndex: Int?
    public var pendingPageIndex: Int?
    
    // Reader tab selection (0 = Book, 1 = Notes)
    @Published public var selectedReaderTab: Int = 0
    
    // Notes list sheet (for viewing all notes in a separate sheet)
    @Published public var showNotesListSheet: Bool = false
    
    // SwiftData context for saving progress
    private let modelContext: ModelContext?
    
    public init(book: Book, modelContext: ModelContext? = nil) {
        self.book = book
        self.modelContext = modelContext
        // Load is deferred to onAppear/task
    }
    
    // Set pending navigation to be applied after book loads
    public func setPendingNavigation(chapterIndex: Int?, pageIndex: Int?) {
        self.pendingChapterIndex = chapterIndex
        self.pendingPageIndex = pageIndex
    }
    
    public func loadBook() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        // 1. Resolve Book File URL
        let fileURL: URL
        if book.filePath.hasPrefix("/") {
            fileURL = URL(fileURLWithPath: book.filePath)
        } else {
            // Assume relative to Documents
            guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                errorMessage = "Could not find documents directory."
                isLoading = false
                return
            }
            fileURL = docsURL.appendingPathComponent(book.filePath)
            // Log for debugging
            //print("Resolved relative path '\(book.filePath)' to: \(fileURL.path)")
        }
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            errorMessage = "Book file not found at: \(fileURL.path)"
            isLoading = false
            return
        }
        
        // 2. Setup Cache Directory
        let tempDir = FileManager.default.temporaryDirectory
        // Use a consistent directory per book
        let bookDir = tempDir.appendingPathComponent(book.id.uuidString)
        
        do {
            // 3. Unzip if necessary
            // We check if the directory exists and has content.
            // For simplicity in this fix, we create if missing.
            var isDir: ObjCBool = false
            if !FileManager.default.fileExists(atPath: bookDir.path, isDirectory: &isDir) {
                try FileManager.default.createDirectory(at: bookDir, withIntermediateDirectories: true)
                try await unzip(fileURL: fileURL, destinationURL: bookDir)
            }
            
            // 4. Parse EPUB
            guard let document = EPUBDocument(url: fileURL) else {
                errorMessage = "Failed to parse EPUB."
                isLoading = false
                return
            }
            self.epubDocument = document
            
            // 5. Set Initial Chapter
            // Find and cache content base URL (directory containing .opf)
            self.contentBaseURL = try findContentBaseURL(in: bookDir) ?? bookDir
            //print("Content Base URL: \(self.contentBaseURL?.path ?? "nil")")
            
            if let firstSpineItem = document.spine.items.first {
                //print("First Spine Item IDRef: \(firstSpineItem.idref)")
                if let resource = document.manifest.items[firstSpineItem.idref] {
                    //print("Resource found in manifest: \(resource.path)")
                    self.currentChapterIndex = 0
                    self.currentChapterURL = contentBaseURL?.appendingPathComponent(resource.path)
                } else {
                     //print("Resource NOT found in manifest, using idref as path: \(firstSpineItem.idref)")
                     self.currentChapterIndex = 0
                     self.currentChapterURL = contentBaseURL?.appendingPathComponent(firstSpineItem.idref)
                }
                //print("Final Chapter URL: \(self.currentChapterURL?.path ?? "N/A")")
            } else {
                //print("No spine items found in document.")
                errorMessage = "No chapters found in this book."
            }
            
        } catch {
            //print("Error loading book: \(error)")
            errorMessage = "Failed to load book: \(error.localizedDescription)"
        }
        
        // Pre-calculate page counts for all chapters to enable absolute page tracking
        await preCalculateAllPageCounts()
        
        isLoading = false
        
        // Apply pending navigation if set (after book and page counts loaded)
        if let chapterIndex = pendingChapterIndex {
            currentChapterIndex = chapterIndex
            pendingChapterIndex = nil
            //print("DEBUG: Applied pending chapter navigation to \(chapterIndex)")
        } else if let progress = book.progress {
            // Restore reading progress using chapter-relative position (more reliable)
            // Fallback to absolute page conversion if chapter-relative not available (old data)
            if let savedChapter = progress.currentChapterIndex,
               let savedSubPage = progress.currentSubPage {
                //print("DEBUG: Restoring progress from chapter \(savedChapter), subPage \(savedSubPage)")
                currentChapterIndex = savedChapter
                pendingPageIndex = savedSubPage
                //print("DEBUG: ✅ Restored to chapter \(savedChapter), pending page \(savedSubPage)")
            } else {
                // Fallback for old data without chapter-relative info
                let absolutePage = progress.currentPage
                //print("DEBUG: Restoring from absolute page (legacy): \(absolutePage)")
                let (chapter, page) = chapterAndPage(from: absolutePage)
                currentChapterIndex = chapter
                pendingPageIndex = page
                //print("DEBUG: ✅ Fallback restored to chapter \(chapter), pending page \(page)")
            }
        }
    }
    
    // MARK: - Page Count Pre-Calculation
    
    /// Pre-calculate page counts for all chapters to enable absolute page tracking
    private func preCalculateAllPageCounts() async {
        guard let document = epubDocument, let baseURL = contentBaseURL else {
            //print("DEBUG: Cannot pre-calculate - no document or baseURL")
            return
        }
        
        //print("DEBUG: Pre-calculating page counts for \(document.spine.items.count) chapters...")
        
        for (index, spineItem) in document.spine.items.enumerated() {
            // Find resource in manifest
            if let resource = document.manifest.items.values.first(where: { $0.id == spineItem.idref }) {
                let chapterURL = baseURL.appendingPathComponent(resource.path)
                
                // Read HTML content
                if let htmlContent = try? String(contentsOf: chapterURL, encoding: .utf8) {
                    // Estimate pages based on content length
                    // Average: ~2000 chars per page (adjustable)
                    let estimatedPages = max(1, htmlContent.count / 2000)
                    chapterPageCounts[index] = estimatedPages
                    
                    //print("DEBUG: Chapter \(index) estimated: \(estimatedPages) pages (\(htmlContent.count) chars)")
                } else {
                    // Fallback: assume 1 page
                    chapterPageCounts[index] = 1
                    //print("DEBUG: Chapter \(index) fallback: 1 page (couldn't read content)")
                }
            } else {
                chapterPageCounts[index] = 1
                //print("DEBUG: Chapter \(index) fallback: 1 page (resource not found)")
            }
        }
        
        //print("DEBUG: Pre-calculation complete. Total estimated pages: \(totalAbsolutePages)")
    }
    
    // MARK: - Absolute Page Conversion Helpers
    
    /// Convert absolute page number (1-indexed) to (chapterIndex, subPage)
    private func chapterAndPage(from absolutePage: Int) -> (chapter: Int, page: Int) {
        var remainingPages = absolutePage
        
        for chapterIdx in 0..<(epubDocument?.spine.items.count ?? 0) {
            let pagesInChapter = chapterPageCounts[chapterIdx] ?? 1
            
            if remainingPages <= pagesInChapter {
                // Found the chapter - convert to 0-indexed page
                return (chapterIdx, remainingPages - 1)
            }
            
            remainingPages -= pagesInChapter
        }
        
        // Fallback: last chapter, last page
        let lastChapter = max(0, (epubDocument?.spine.items.count ?? 1) - 1)
        let lastPage = max(0, (chapterPageCounts[lastChapter] ?? 1) - 1)
        return (lastChapter, lastPage)
    }
    
    private func findContentBaseURL(in root: URL) throws -> URL? {
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey]
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles])
        
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension.lowercased() == "opf" {
                return url.deletingLastPathComponent()
            }
        }
        return nil
    }
    
    private func unzip(fileURL: URL, destinationURL: URL) async throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        task.arguments = ["-o", "-q", fileURL.path, "-d", destinationURL.path]
        
        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            throw NSError(domain: "UnzipError", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Unzip failed"])
        }
    }

    // MARK: - Navigation
    
    public func nextPage() {
        //print("DEBUG: nextPage() invoked. Current State -> subPage: \(currentSubPage), totalSubPages: \(totalSubPages), chapter: \(currentChapterIndex)")
        
        // Save current page time before navigating
        resetTimeTracking()
        
        if currentSubPage < totalSubPages - 1 {
            currentSubPage += 1
            //print("DEBUG: Condition (current < total - 1) TRUE. Incrementing subPage to \(currentSubPage)")
        } else {
            //print("DEBUG: Condition (current < total - 1) FALSE. SubPage is \(currentSubPage), Total is \(totalSubPages). Moving to next chapter logic.")
            // Next Chapter Logic
             if let document = epubDocument, currentChapterIndex < document.spine.items.count - 1 {
                currentChapterIndex += 1
                currentSubPage = 0
                //print("DEBUG: Moving to next chapter index: \(currentChapterIndex)")
            } else {
                //print("DEBUG: No more chapters available (current: \(currentChapterIndex), total: \(epubDocument?.spine.items.count ?? 0)).")
            }
        }
    }
    
    public func previousPage() {
        //print("DEBUG: previousPage() called. currentSubPage: \(currentSubPage), totalSubPages: \(totalSubPages)")
        
        // Save current page time before navigating
        resetTimeTracking()
        
        if currentSubPage > 0 {
            currentSubPage -= 1
             //print("DEBUG: Decrementing subPage to \(currentSubPage)")
        } else {
             // Previous Chapter Logic
             if currentChapterIndex > 0 {
                currentChapterIndex -= 1
                currentSubPage = 0 // Should ideally go to last page of chapter
                //print("DEBUG: Moving to previous chapter: \(currentChapterIndex)")
            }
        }
    }
    
    public func spineIndex(for item: EPUBTableOfContents) -> (index: Int?, fragment: String?) {
        guard let document = epubDocument, let itemPath = item.item else { 
            //print("DEBUG: spineIndex - no item path for '\(item.label)'")
            return (nil, nil)
        }
        
        // Split path and fragment (e.g., "chapter1.html#section1" -> "chapter1.html", "section1")
        let components = itemPath.components(separatedBy: "#")
        let tocPath = components.first ?? itemPath
        let fragment = components.count > 1 ? components.last : nil
        
        //print("DEBUG: spineIndex - looking for path '\(tocPath)' (fragment: \(fragment ?? "none"))")
        
        // Iterate spine items to find matching path
        for (index, spineItem) in document.spine.items.enumerated() {
            if let manifestItem = document.manifest.items[spineItem.idref] {
                let manifestPath = manifestItem.path
                
                // Try multiple matching strategies:
                // 1. Exact match
                // 2. Manifest ends with TOC path (e.g., "OEBPS/text/ch1.html" ends with "ch1.html")
                // 3. TOC ends with manifest path
                // 4. Filename-only match (last component)
                
                let tocFilename = (tocPath as NSString).lastPathComponent
                let manifestFilename = (manifestPath as NSString).lastPathComponent
                
                if manifestPath == tocPath ||
                   manifestPath.hasSuffix(tocPath) ||
                   tocPath.hasSuffix(manifestPath) ||
                   manifestFilename == tocFilename {
                    //print("DEBUG: spineIndex - MATCHED at index \(index): '\(manifestPath)' ~ '\(tocPath)'")
                    return (index, fragment)
                }
            }
        }
        
        //print("DEBUG: spineIndex - NO MATCH found for '\(tocPath)'")
        return (nil, nil)
    }

    public func findTitle(in items: [EPUBTableOfContents]?, for spineItem: EPUBSpineItem) -> String? {
         guard let items = items, let document = epubDocument else { return nil }
         // Resolve path for spine item
         guard let manifestItem = document.manifest.items[spineItem.idref] else { return nil }
         let spinePath = manifestItem.path
         
         for item in items {
             // Check current item
             if let itemPath = item.item {
                 let path = itemPath.components(separatedBy: "#").first ?? itemPath
                 if path == spinePath {
                     return item.label
                 }
             }
             
             // Check children
             if let title = findTitle(in: item.subTable, for: spineItem) { return title }
         }
         return nil
    }
    
    public func jumpToChapter(index: Int, fragment: String?) {
        guard let document = epubDocument, index < document.spine.items.count else { return }
        //print("DEBUG: jumpToChapter - index: \(index), fragment: \(fragment ?? "nil")")
        currentChapterIndex = index
        currentSubPage = 0
        
        // Store fragment for scrolling after chapter loads
        if let fragment = fragment {
            pendingScrollToFragment = fragment
        }
    }
    
    public func isCurrentChapter(_ item: EPUBTableOfContents) -> Bool {
        return spineIndex(for: item).index == currentChapterIndex
    }
    
    // MARK: - Chapter URL Resolution
    
    private func updateChapterURL() {
        guard let document = epubDocument,
              let baseURL = contentBaseURL,
              currentChapterIndex < document.spine.items.count else {
            //print("DEBUG: Cannot update chapter URL - missing document, baseURL, or invalid index")
            return
        }
        
        let spineItem = document.spine.items[currentChapterIndex]
        
        if let resource = document.manifest.items[spineItem.idref] {
            currentChapterURL = baseURL.appendingPathComponent(resource.path)
            //print("DEBUG: Updated chapter URL to: \(currentChapterURL?.lastPathComponent ?? "nil")")
        } else {
            currentChapterURL = baseURL.appendingPathComponent(spineItem.idref)
            //print("DEBUG: Using idref as chapter URL: \(currentChapterURL?.lastPathComponent ?? "nil")")
        }
        
        // Reset pagination for new chapter
        totalSubPages = 1
        currentSubPage = 0
    }
    
    // MARK: - Time Tracking
    
    public func startTrackingTime() {
        stopTrackingTime()
        timeTrackingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.timeOnCurrentPage += 1
            }
        }
    }
    
    public func stopTrackingTime() {
        // Save accumulated time before stopping
        if timeOnCurrentPage > 0 {
            saveCurrentPageReadingTime()
        }
        timeTrackingTimer?.invalidate()
        timeTrackingTimer = nil
    }
    
    public func resetTimeTracking() {
        // Save time before reset
        if timeOnCurrentPage > 0 {
            saveCurrentPageReadingTime()
        }
        timeOnCurrentPage = 0
    }
    
    /// Save the current page's reading time to persistence
    private func saveCurrentPageReadingTime() {
        guard let progress = book.progress, timeOnCurrentPage > 0 else { return }
        
        let pageId = currentPageId
        
        if let index = progress.pageReadingTimes.firstIndex(where: { $0.pageIdentifier == pageId }) {
            // Update existing record
            let existing = progress.pageReadingTimes[index]
            progress.pageReadingTimes[index] = PageReadingRecord(
                pageIdentifier: pageId,
                totalSecondsSpent: existing.totalSecondsSpent + Int(timeOnCurrentPage)
            )
        } else {
            // Create new record
            progress.pageReadingTimes.append(
                PageReadingRecord(
                    pageIdentifier: pageId,
                    totalSecondsSpent: Int(timeOnCurrentPage)
                )
            )
        }
        
        // Save to database
        if let context = modelContext {
            try? context.save()
        }
    }
    
    /// Get current page identifier
    public var currentPageId: String {
        "\(currentChapterIndex)-\(currentSubPage)"
    }
    
    /// Check if AI is unlocked for a specific page
    public func hasUnlockedAI(for pageId: String) -> Bool {
        guard let progress = book.progress else { return false }
        return progress.pageReadingTimes
            .first(where: { $0.pageIdentifier == pageId })?
            .hasUnlockedAI ?? false
    }
    
    /// Check if a page has been read (for gating purposes)
    public func hasReadPage(chapterIndex: Int, subPage: Int) -> Bool {
        let pageId = "\(chapterIndex)-\(subPage)"
        
        // A page is "read" if it's before current position OR unlocked by time
        let isBeforeCurrent = (chapterIndex < currentChapterIndex) ||
                              (chapterIndex == currentChapterIndex && subPage < currentSubPage)
        
        return isBeforeCurrent || hasUnlockedAI(for: pageId)
    }
    
    /// Load accumulated reading time for current page
    private func loadPageReadingTime() {
        guard let progress = book.progress else {
            timeOnCurrentPage = 0
            return
        }
        
        let pageId = currentPageId
        let existingTime = progress.pageReadingTimes
            .first(where: { $0.pageIdentifier == pageId })?
            .totalSecondsSpent ?? 0
        
        timeOnCurrentPage = TimeInterval(existingTime)
    }
    
    
    // MARK: - Reading Progress
    
    private func saveProgress() {
        //print("DEBUG: saveProgress() called - currentSubPage: \(currentSubPage), currentChapter: \(currentChapterTitle ?? "nil")")
        
        // Create or update reading progress
        if book.progress == nil {
            //print("DEBUG: Creating new ReadingProgress")
            let progress = ReadingProgress()
            book.progress = progress
            
            // Insert into context if available
            if let context = modelContext {
                context.insert(progress)
                //print("DEBUG: Inserted progress into context")
            } else {
                //print("DEBUG: WARNING - No modelContext available")
            }
        }
        
        guard let progress = book.progress else {
            //print("DEBUG: ERROR - Failed to get progress object")
            return
        }
        
        // Save current position using both absolute and chapter-relative
        progress.currentPage = absolutePageNumber  // Store absolute page (1-500)
        progress.currentChapter = currentChapterTitle  // Keep for reference
        progress.currentChapterIndex = currentChapterIndex  // Reliable spine index
        progress.currentSubPage = currentSubPage  // Reliable sub-page within chapter
        progress.lastReadDate = Date()
        
        //print("DEBUG: Saved - Absolute: \(absolutePageNumber), Ch: \(currentChapterIndex), SubPage: \(currentSubPage), Total: \(totalAbsolutePages)")
        
        // Calculate percent complete using absolute pages
        if totalAbsolutePages > 0 {
            progress.percentComplete = (Double(absolutePageNumber) / Double(totalAbsolutePages)) * 100
        }
        
        // Try to save context
        if let context = modelContext {
            do {
                try context.save()
                //print("DEBUG: Successfully saved progress - Chapter: \(currentChapterTitle ?? "Unknown"), Page: \(currentSubPage), %: \(progress.percentComplete)")
            } catch {
                //print("DEBUG: ERROR saving context: \(error)")
            }
        }
    }
    
    // MARK: - Text Selection Management
    
    public func clearSelection() {
        selectedText = ""
    }
}
