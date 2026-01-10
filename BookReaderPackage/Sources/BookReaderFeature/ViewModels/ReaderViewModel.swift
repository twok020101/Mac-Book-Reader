import Foundation
import EPUBKit

@MainActor
public class ReaderViewModel: ObservableObject {
    @Published public var book: Book
    @Published public var currentChapterURL: URL?
    @Published public var totalSubPages: Int = 1 {
        didSet {
            print("DEBUG: totalSubPages changed from \(oldValue) to \(totalSubPages)")
        }
    }
    @Published public var currentSubPage: Int = 0
    @Published public var pendingScrollToFragment: String?
    
    @Published public var currentChapterIndex: Int = 0 {
        didSet {
            if oldValue != currentChapterIndex {
                updateChapterURL()
            }
        }
    }
    @Published public var epubDocument: EPUBDocument?
    
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
    private var pendingChapterIndex: Int?
    private var pendingPageIndex: Int?
    
    // Reader tab selection (0 = Book, 1 = Notes)
    @Published public var selectedReaderTab: Int = 0
    
    // Notes list sheet (for viewing all notes in a separate sheet)
    @Published public var showNotesListSheet: Bool = false
    
    public init(book: Book) {
        self.book = book
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
            print("Resolved relative path '\(book.filePath)' to: \(fileURL.path)")
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
            print("Content Base URL: \(self.contentBaseURL?.path ?? "nil")")
            
            if let firstSpineItem = document.spine.items.first {
                print("First Spine Item IDRef: \(firstSpineItem.idref)")
                if let resource = document.manifest.items[firstSpineItem.idref] {
                    print("Resource found in manifest: \(resource.path)")
                    self.currentChapterIndex = 0
                    self.currentChapterURL = contentBaseURL?.appendingPathComponent(resource.path)
                } else {
                     print("Resource NOT found in manifest, using idref as path: \(firstSpineItem.idref)")
                     self.currentChapterIndex = 0
                     self.currentChapterURL = contentBaseURL?.appendingPathComponent(firstSpineItem.idref)
                }
                print("Final Chapter URL: \(self.currentChapterURL?.path ?? "N/A")")
            } else {
                print("No spine items found in document.")
                errorMessage = "No chapters found in this book."
            }
            
        } catch {
            print("Error loading book: \(error)")
            errorMessage = "Failed to load book: \(error.localizedDescription)"
        }
        
        isLoading = false
        
        // Apply pending navigation if set (after book loads)
        if let chapterIndex = pendingChapterIndex {
            currentChapterIndex = chapterIndex
            pendingChapterIndex = nil
            print("DEBUG: Applied pending chapter navigation to \(chapterIndex)")
        }
        if let pageIndex = pendingPageIndex {
            currentSubPage = pageIndex
            pendingPageIndex = nil
            print("DEBUG: Applied pending page navigation to \(pageIndex)")
        }
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
        print("DEBUG: nextPage() invoked. Current State -> subPage: \(currentSubPage), totalSubPages: \(totalSubPages), chapter: \(currentChapterIndex)")
        
        if currentSubPage < totalSubPages - 1 {
            currentSubPage += 1
            print("DEBUG: Condition (current < total - 1) TRUE. Incrementing subPage to \(currentSubPage)")
        } else {
            print("DEBUG: Condition (current < total - 1) FALSE. SubPage is \(currentSubPage), Total is \(totalSubPages). Moving to next chapter logic.")
            // Next Chapter Logic
             if let document = epubDocument, currentChapterIndex < document.spine.items.count - 1 {
                currentChapterIndex += 1
                currentSubPage = 0
                print("DEBUG: Moving to next chapter index: \(currentChapterIndex)")
            } else {
                print("DEBUG: No more chapters available (current: \(currentChapterIndex), total: \(epubDocument?.spine.items.count ?? 0)).")
            }
        }
    }
    
    public func previousPage() {
        print("DEBUG: previousPage() called. currentSubPage: \(currentSubPage), totalSubPages: \(totalSubPages)")
        
        if currentSubPage > 0 {
            currentSubPage -= 1
             print("DEBUG: Decrementing subPage to \(currentSubPage)")
        } else {
             // Previous Chapter Logic
             if currentChapterIndex > 0 {
                currentChapterIndex -= 1
                currentSubPage = 0 // Should ideally go to last page of chapter
                print("DEBUG: Moving to previous chapter: \(currentChapterIndex)")
            }
        }
    }
    
    public func spineIndex(for item: EPUBTableOfContents) -> (index: Int?, fragment: String?) {
        guard let document = epubDocument, let itemPath = item.item else { 
            print("DEBUG: spineIndex - no item path for '\(item.label)'")
            return (nil, nil)
        }
        
        // Split path and fragment (e.g., "chapter1.html#section1" -> "chapter1.html", "section1")
        let components = itemPath.components(separatedBy: "#")
        let tocPath = components.first ?? itemPath
        let fragment = components.count > 1 ? components.last : nil
        
        print("DEBUG: spineIndex - looking for path '\(tocPath)' (fragment: \(fragment ?? "none"))")
        
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
                    print("DEBUG: spineIndex - MATCHED at index \(index): '\(manifestPath)' ~ '\(tocPath)'")
                    return (index, fragment)
                }
            }
        }
        
        print("DEBUG: spineIndex - NO MATCH found for '\(tocPath)'")
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
        print("DEBUG: jumpToChapter - index: \(index), fragment: \(fragment ?? "nil")")
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
            print("DEBUG: Cannot update chapter URL - missing document, baseURL, or invalid index")
            return
        }
        
        let spineItem = document.spine.items[currentChapterIndex]
        
        if let resource = document.manifest.items[spineItem.idref] {
            currentChapterURL = baseURL.appendingPathComponent(resource.path)
            print("DEBUG: Updated chapter URL to: \(currentChapterURL?.lastPathComponent ?? "nil")")
        } else {
            currentChapterURL = baseURL.appendingPathComponent(spineItem.idref)
            print("DEBUG: Using idref as chapter URL: \(currentChapterURL?.lastPathComponent ?? "nil")")
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
        timeTrackingTimer?.invalidate()
        timeTrackingTimer = nil
    }
    
    public func resetTimeTracking() {
        timeOnCurrentPage = 0
    }
    
    // MARK: - Text Selection Management
    
    public func clearSelection() {
        selectedText = ""
    }
}
