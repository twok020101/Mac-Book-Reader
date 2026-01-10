# BookReader for macOS - Implementation Plan

A native macOS epub/PDF reader with Gemini AI integration, designed to provide an immersive reading experience while encouraging genuine study.

## Project Overview

| Aspect | Choice |
|--------|--------|
| **Platform** | macOS 13 Ventura+ |
| **Framework** | Swift 5.9+ / SwiftUI |
| **Persistence** | SwiftData |
| **EPUB Parsing** | EPUBKit |
| **PDF Rendering** | PDFKit (Apple) |
| **AI Integration** | google/generative-ai-swift or direct REST API |
| **Secure Storage** | Keychain Services |
| **Distribution** | Direct / Open Source |

---

## User Review Required

> [!IMPORTANT]
> **AI Gating Mechanism**: The plan implements a 2-minute reading timer per page before allowing AI questions about current/future content. Users can always ask about previously read content. Please confirm this matches your intent.

> [!NOTE]
> **Focus Mode**: Since macOS doesn't allow apps to programmatically enable Do Not Disturb, entering Focus Mode will display a friendly welcome screen with tips like "Put away your phone" and "Enable Do Not Disturb in System Settings". The app will then provide fullscreen immersive reading with minimal UI.

---

## Proposed Changes

### Project Structure

```
BookReader/
├── BookReader.xcodeproj
├── BookReader/
│   ├── App/
│   │   ├── BookReaderApp.swift          # App entry point
│   │   └── ContentView.swift            # Main navigation container
│   │
│   ├── Models/
│   │   ├── Book.swift                   # SwiftData book model
│   │   ├── ReadingProgress.swift        # Progress tracking
│   │   ├── Note.swift                   # Notes model
│   │   └── Collection.swift             # Folder/Collection model
│   │
│   ├── Services/
│   │   ├── BookImportService.swift      # Import EPUB/PDF
│   │   ├── EPUBParserService.swift      # EPUB parsing wrapper
│   │   ├── PDFService.swift             # PDF handling
│   │   ├── KeychainService.swift        # Secure key storage
│   │   ├── GeminiService.swift          # AI API integration
│   │   └── ReadingTimeTracker.swift     # Page time tracking for AI gating
│   │
│   ├── Views/
│   │   ├── Library/
│   │   │   ├── LibraryView.swift        # Main library grid
│   │   │   ├── BookCard.swift           # Book cover card
│   │   │   ├── CollectionSidebar.swift  # Folders/collections
│   │   │   └── ImportBookView.swift     # Import flow
│   │   │
│   │   ├── Reader/
│   │   │   ├── ReaderView.swift         # Main reader container
│   │   │   ├── EPUBPageView.swift       # EPUB content rendering
│   │   │   ├── PDFPageView.swift        # PDF page rendering
│   │   │   ├── PageTurnView.swift       # Animated page turning
│   │   │   ├── ReaderToolbar.swift      # Reading controls
│   │   │   └── ThemeSettings.swift      # Typography/theme panel
│   │   │
│   │   ├── Notes/
│   │   │   ├── NotesPanelView.swift     # Collapsible notes sidebar
│   │   │   ├── NoteEditorView.swift     # Note editing
│   │   │   └── NotesListView.swift      # Book-organized notes
│   │   │
│   │   ├── AI/
│   │   │   ├── AISetupView.swift        # API key input
│   │   │   ├── AIQueryView.swift        # Query interface
│   │   │   └── AIResponseView.swift     # Response display
│   │   │
│   │   └── Settings/
│   │       └── SettingsView.swift       # App preferences
│   │
│   ├── ViewModels/
│   │   ├── LibraryViewModel.swift
│   │   ├── ReaderViewModel.swift
│   │   ├── NotesViewModel.swift
│   │   └── AIViewModel.swift
│   │
│   ├── Utilities/
│   │   ├── Extensions/
│   │   └── Theme.swift                  # Color/typography definitions
│   │
│   └── Resources/
│       ├── Assets.xcassets
│       └── Textures/                    # Paper textures
│
└── BookReaderTests/
```

---

### Core Infrastructure

#### [NEW] [BookReaderApp.swift](file:///Users/twok/Projects/TP/Book-reader/BookReader/App/BookReaderApp.swift)
- SwiftUI app entry with `@main`
- SwiftData container setup
- First-launch API key prompt detection

#### [NEW] [KeychainService.swift](file:///Users/twok/Projects/TP/Book-reader/BookReader/Services/KeychainService.swift)
```swift
// Secure storage for Gemini API key
actor KeychainService {
    static let shared = KeychainService()
    
    func saveAPIKey(_ key: String) throws
    func getAPIKey() throws -> String?
    func deleteAPIKey() throws
}
```

---

### Data Models (SwiftData)

#### [NEW] [Book.swift](file:///Users/twok/Projects/TP/Book-reader/BookReader/Models/Book.swift)
```swift
@Model
final class Book {
    @Attribute(.unique) var id: UUID
    var title: String
    var author: String?
    var coverImageData: Data?
    var filePath: String        // Relative path in app sandbox
    var fileType: BookFileType  // .epub or .pdf
    var dateAdded: Date
    var lastOpened: Date?
    
    @Relationship(deleteRule: .cascade) var progress: ReadingProgress?
    @Relationship(deleteRule: .cascade) var notes: [Note]
    @Relationship var collection: Collection?
    var tags: [String]
}

enum BookFileType: String, Codable {
    case epub, pdf
}
```

#### [NEW] [ReadingProgress.swift](file:///Users/twok/Projects/TP/Book-reader/BookReader/Models/ReadingProgress.swift)
```swift
@Model
final class ReadingProgress {
    var book: Book?
    var currentPage: Int           // For PDF
    var currentChapter: String?    // For EPUB
    var currentCFI: String?        // EPUB location (Content Fragment Identifier)
    var totalPages: Int?
    var percentComplete: Double
    var lastReadDate: Date
    
    // Per-page reading time tracking for AI gating
    var pageReadingTimes: [PageReadingRecord]
}

struct PageReadingRecord: Codable {
    let pageIdentifier: String  // Page number or CFI
    let totalSecondsSpent: Int
    var hasUnlockedAI: Bool { totalSecondsSpent >= 120 }
}
```

#### [NEW] [Note.swift](file:///Users/twok/Projects/TP/Book-reader/BookReader/Models/Note.swift)
```swift
@Model
final class Note {
    @Attribute(.unique) var id: UUID
    var book: Book?
    var content: String
    var pageReference: String?   // Page number or chapter
    var selectedText: String?    // Text that was highlighted
    var createdAt: Date
    var updatedAt: Date
}
```

#### [NEW] [Collection.swift](file:///Users/twok/Projects/TP/Book-reader/BookReader/Models/Collection.swift)
```swift
@Model
final class Collection {
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String?            // SF Symbol name
    @Relationship var books: [Book]
    var createdAt: Date
}
```

---

### Library View

#### [NEW] [LibraryView.swift](file:///Users/twok/Projects/TP/Book-reader/BookReader/Views/Library/LibraryView.swift)
- Grid layout with book covers (similar to Apple Books)
- Sidebar with collections/folders
- Search bar filtering by title
- Drag-and-drop book import
- Right-click context menu for organization

```swift
struct LibraryView: View {
    @Query private var books: [Book]
    @State private var searchText = ""
    @State private var selectedCollection: Collection?
    
    var filteredBooks: [Book] {
        // Filter by search and collection
    }
    
    var body: some View {
        NavigationSplitView {
            CollectionSidebar(selection: $selectedCollection)
        } detail: {
            BookGridView(books: filteredBooks)
        }
    }
}
```

---

### Reader View

#### [NEW] [ReaderView.swift](file:///Users/twok/Projects/TP/Book-reader/BookReader/Views/Reader/ReaderView.swift)
**Key Features:**
- Fullscreen capability for Focus Mode
- Page-turn animation (curl effect for EPUB)
- Keyboard navigation (←/→ arrows, space for next page)
- Collapsible notes panel (⌘+N shortcut)
- Theme selector (light/sepia/dark)
- Typography controls

```swift
struct ReaderView: View {
    @StateObject var viewModel: ReaderViewModel
    @State private var showNotesPanel = false
    @State private var isFullscreen = false
    
    var body: some View {
        ZStack {
            // Background with paper texture
            BookContentView(viewModel: viewModel)
                .gesture(pageTurnGesture)
            
            // Collapsible notes overlay
            if showNotesPanel {
                NotesPanelView(book: viewModel.book)
                    .transition(.move(edge: .trailing))
            }
        }
        .onKeyPress(.rightArrow) { viewModel.nextPage() }
        .onKeyPress(.leftArrow) { viewModel.previousPage() }
        .keyboardShortcut("n", modifiers: .command) {
            showNotesPanel.toggle()
        }
    }
}
```

#### Page Turn Animation
- Uses SwiftUI `rotation3DEffect` for page curl
- Smooth spring animations
- Touch/trackpad swipe gestures
- Optional page-flip sound effect

#### Theme System
| Theme | Background | Text | Accent |
|-------|-----------|------|--------|
| Light | #FFFFFF | #1A1A1A | #007AFF |
| Sepia | #F4ECD8 | #5B4636 | #8B7355 |
| Dark | #1C1C1E | #E5E5E7 | #0A84FF |

---

### Focus Mode

#### Implementation Approach

**Focus Mode Welcome Screen**
When entering Focus Mode, display a calming overlay with:
- 📱 "Put your phone away or on silent"
- 🔕 "Enable Do Not Disturb in System Settings"
- ☕ "Grab a drink and get comfortable"
- 📖 "Happy reading!"
- [Enter Focus Mode] button

**Technical Implementation:**
1. **Fullscreen Mode**: Use `.presentationMode` for immersive reading
2. **Hide Toolbar**: Minimal chrome, hover to reveal controls
3. **Disable App Notifications**: Suppress any in-app alerts during reading
4. **Menu Bar Item**: Optional reading timer in menu bar
5. **Keyboard Shortcut**: ⌘+Shift+F to toggle

#### [NEW] [FocusModeWelcomeView.swift](file:///Users/twok/Projects/TP/Book-reader/BookReader/Views/Reader/FocusModeWelcomeView.swift)
```swift
struct FocusModeWelcomeView: View {
    @Binding var isPresented: Bool
    var onEnter: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Prepare for Deep Reading")
                .font(.largeTitle.bold())
            
            VStack(alignment: .leading, spacing: 16) {
                TipRow(icon: "iphone.slash", text: "Put your phone away or on silent")
                TipRow(icon: "bell.slash", text: "Enable Do Not Disturb in System Settings")
                TipRow(icon: "cup.and.saucer", text: "Grab a drink and get comfortable")
                TipRow(icon: "book", text: "Happy reading!")
            }
            
            Button("Enter Focus Mode") {
                onEnter()
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
```

```swift
extension ReaderView {
    func enterFocusMode() {
        NSApp.presentationOptions = [
            .autoHideDock,
            .autoHideMenuBar,
            .fullScreen
        ]
        isFullscreen = true
    }
}
```

---

### Gemini AI Integration

#### [NEW] [GeminiService.swift](file:///Users/twok/Projects/TP/Book-reader/BookReader/Services/GeminiService.swift)
```swift
actor GeminiService {
    private var apiKey: String?
    
    func configure(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func askQuestion(
        question: String,
        context: BookContext,
        selectedText: String?
    ) async throws -> String {
        // Build prompt with book context
        // Call Gemini API
        // Return response
    }
}

struct BookContext {
    let bookTitle: String
    let author: String?
    let currentChapter: String?
    let previousContent: String?  // Summary of what's been read
}
```

#### AI Gating Logic
```swift
class ReadingTimeTracker: ObservableObject {
    @Published private(set) var currentPageTime: TimeInterval = 0
    private var timer: Timer?
    
    var canAskAboutCurrentPage: Bool {
        currentPageTime >= 120  // 2 minutes
    }
    
    func startTracking(for pageId: String) { ... }
    func pauseTracking() { ... }
    
    func canAskAboutContent(pageId: String, currentPageId: String) -> Bool {
        // Allow if asking about previous pages
        // Block if asking about current/future until 2 min spent
    }
}
```

#### AI Query Flow
1. User selects text or opens AI panel
2. System checks reading time for current page
3. If < 2 min on current page:
   - Allow questions about previous content
   - Show "Read for X more seconds to unlock AI for this page"
4. If ≥ 2 min: Allow full access
5. Query sent to Gemini with book context
6. Response displayed in chat-style interface

---

### Notes System

#### Keyboard Shortcut: ⌘+N
```swift
.keyboardShortcut("n", modifiers: .command)
```

#### [NEW] [NotesPanelView.swift](file:///Users/twok/Projects/TP/Book-reader/BookReader/Views/Notes/NotesPanelView.swift)
- Slides in from right edge
- Shows notes for current book
- Quick-add note with current page reference
- Edit/delete existing notes

#### [NEW] [NotesListView.swift](file:///Users/twok/Projects/TP/Book-reader/BookReader/Views/Notes/NotesListView.swift)
- Main app view for all notes
- Organized by book (expandable sections)
- Search across all notes

---

### Dependencies (Swift Package Manager)

| Package | Purpose | URL |
|---------|---------|-----|
| EPUBKit | EPUB parsing | `https://github.com/witekbobrowski/EPUBKit.git` |
| GoogleGenerativeAI | Gemini API (if not deprecated) | `https://github.com/google/generative-ai-swift` |

> [!NOTE]
> If the Google SDK is deprecated, we'll use direct REST API calls to `https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent`

---

## Execution Phases

### Phase 1: Foundation (Est. 3-4 days)
- [ ] Xcode project setup
- [ ] SwiftData models
- [ ] Keychain service
- [ ] Basic app navigation

### Phase 2: Library (Est. 2-3 days)
- [ ] Book import (EPUB + PDF)
- [ ] Library grid view
- [ ] Collections/folders
- [ ] Search functionality

### Phase 3: Reader Core (Est. 4-5 days)
- [ ] EPUB rendering
- [ ] PDF rendering
- [ ] Page navigation
- [ ] Progress persistence
- [ ] Reading time tracking

### Phase 4: Reader Polish (Est. 2-3 days)
- [ ] Page-turn animations
- [ ] Theme system (light/sepia/dark)
- [ ] Typography controls
- [ ] Paper texture backgrounds

### Phase 5: Focus Mode (Est. 1 day)
- [ ] Fullscreen mode
- [ ] Hide UI elements
- [ ] Keyboard shortcuts

### Phase 6: Notes (Est. 2 days)
- [ ] Notes CRUD
- [ ] Collapsible panel
- [ ] Notes list view

### Phase 7: AI Integration (Est. 2-3 days)
- [ ] API key setup flow
- [ ] Gemini service
- [ ] Reading gate logic
- [ ] Query UI

---

## Verification Plan

### Manual Testing

Since this is a new macOS GUI application with no existing tests, verification will be primarily manual with some unit tests for core logic.

#### 1. Build Verification
```bash
# From project root
xcodebuild -project BookReader.xcodeproj -scheme BookReader -configuration Debug build
```

#### 2. EPUB Import & Reading Test
1. Launch app
2. Drag an EPUB file into the library
3. Verify cover image extracted and displayed
4. Click to open book
5. Navigate pages with arrow keys
6. Verify page-turn animation works
7. Close and reopen - verify progress saved

#### 3. PDF Import & Reading Test
1. Drag a PDF file into the library
2. Open and navigate
3. Verify smooth rendering
4. Test zoom if implemented

#### 4. Focus Mode Test
1. Open a book
2. Press ⌘+Shift+F
3. Verify fullscreen, dock/menu bar hidden
4. Press Escape to exit
5. Verify UI restored

#### 5. Notes Test
1. While reading, press ⌘+N
2. Verify notes panel slides in
3. Add a note
4. Close panel, reopen - verify note persists
5. Go to Notes view - verify organized by book

#### 6. AI Integration Test
1. First launch - verify API key prompt appears
2. Enter valid Gemini key
3. Open book, immediately try to ask about current page
4. Verify "wait X seconds" message appears
5. Wait 2 minutes, try again
6. Verify AI responds
7. Ask about previous page content - should work immediately

#### Unit Tests (Phase 1)
```swift
// KeychainServiceTests.swift
func testSaveAndRetrieveAPIKey() async throws {
    let service = KeychainService.shared
    try await service.saveAPIKey("test-key-123")
    let retrieved = try await service.getAPIKey()
    XCTAssertEqual(retrieved, "test-key-123")
}

// ReadingTimeTrackerTests.swift
func testAIGatingLogic() {
    let tracker = ReadingTimeTracker()
    tracker.recordTime(for: "page-1", seconds: 60)
    tracker.recordTime(for: "page-2", seconds: 30)
    
    XCTAssertTrue(tracker.canAskAbout(page: "page-1", currentPage: "page-2"))
    XCTAssertFalse(tracker.canAskAbout(page: "page-2", currentPage: "page-2"))
    
    tracker.recordTime(for: "page-2", seconds: 100)  // Total 130s
    XCTAssertTrue(tracker.canAskAbout(page: "page-2", currentPage: "page-2"))
}
```

Run unit tests:
```bash
xcodebuild test -project BookReader.xcodeproj -scheme BookReader -destination 'platform=macOS'
```

---

## Additional Features (Nice-to-Have)

These could be added in future iterations:

1. **iCloud Sync** - Sync books, progress, and notes across devices
2. **Text-to-Speech** - Read aloud feature using AVSpeechSynthesizer
3. **Highlights** - Text highlighting with colors
4. **Reading Statistics** - Time spent, pages read, reading streaks
5. **OPDS Catalog Support** - Import from online book catalogs
6. **Goodreads Integration** - Track reading on Goodreads
7. **AI Notes** - Let AI help summarize/organize notes (future scope per your request)
