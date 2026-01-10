# BookReader for macOS

A native macOS EPUB/PDF reader with Gemini AI integration, designed to provide an immersive reading experience while encouraging genuine study and deep focus.

![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Native-green)

## Overview

BookReader is a thoughtfully designed reading app that combines the beauty of traditional book reading with modern AI assistance. Unlike typical ebook readers, it emphasizes focused, distraction-free reading while providing intelligent AI support that encourages learning rather than passive consumption.

## ✨ Key Features

### 📚 Immersive Reading Experience
- **Focus Mode**: Fullscreen reading with minimal UI distractions
- **Beautiful Themes**: Light, Sepia, and Dark modes with authentic paper textures
- **Page-Turn Animations**: Realistic page curl effects for a book-like feel
- **Typography Controls**: Customizable fonts, sizes, and line spacing
- **Keyboard Navigation**: Arrow keys, space bar, and custom shortcuts for seamless reading

### 🤖 Intelligent AI Integration (Gemini)
- **Study-First Approach**: AI gating system that encourages genuine reading before AI assistance
- **2-Minute Rule**: Unlocks AI questions after spending 2 minutes on current page
- **Instant Historical Access**: Ask about previously read content anytime
- **Context-Aware**: AI receives full book context for relevant responses
- **Bring Your Own Key**: Secure Gemini API key storage in macOS Keychain

### 📝 Notes & Annotations
- **Quick Notes**: Press `⌘+N` to jot down thoughts instantly
- **Text Selection**: Reference specific passages in your notes
- **Organized by Book**: All notes accessible and grouped by book
- **Persistent**: Notes sync with reading progress
- **Searchable**: Find notes across your entire library

### 📖 Library Management
- **Beautiful Grid View**: Apple Books-inspired library interface
- **Collections & Folders**: Organize books into custom collections
- **Drag & Drop Import**: Easy EPUB and PDF file import
- **Smart Search**: Filter by title, author, or tags
- **Reading Progress**: Automatic bookmark and progress tracking

### 🔐 Privacy & Security
- **Sandboxed App**: macOS app sandbox for security
- **Keychain Integration**: API keys stored securely
- **Local-First**: All books and notes stored on your Mac
- **No Telemetry**: Your reading data stays private

## 🛠 Tech Stack

| Component | Technology |
|-----------|-----------|
| **Platform** | macOS 13 Ventura+ |
| **Language** | Swift 5.9+ |
| **UI Framework** | SwiftUI |
| **Data Persistence** | SwiftData |
| **EPUB Parsing** | EPUBKit |
| **PDF Rendering** | PDFKit (Apple) |
| **AI Integration** | Google Gemini API |
| **Secure Storage** | Keychain Services |
| **Package Manager** | Swift Package Manager |

## 🚀 Getting Started

### Prerequisites
- macOS 13 Ventura or later
- Xcode 15.0+
- Swift 5.9+
- Gemini API Key ([Get one here](https://makersuite.google.com/app/apikey))

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/BookReader.git
   cd BookReader
   ```

2. **Open the workspace in Xcode**
   ```bash
   open BookReader.xcworkspace
   ```

3. **Build and run**
   - Select the `BookReader` scheme
   - Press `⌘+R` to build and run
   - On first launch, you'll be prompted to enter your Gemini API key

### First-Time Setup

1. Launch the app
2. Enter your Gemini API key when prompted
3. Drag and drop EPUB or PDF files into the library
4. Start reading!

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘+N` | Toggle notes panel |
| `⌘+I` | Open AI chat |
| `⌘+Shift+F` | Enter Focus Mode |
| `Escape` | Exit Focus Mode |
| `←` / `→` | Previous/Next page |
| `Space` | Next page |

## 🏗 Project Architecture

```
BookReader/
├── BookReader.xcworkspace/              # Open this file in Xcode
├── BookReader.xcodeproj/                # App shell project
├── BookReader/                          # App target (minimal)
│   ├── Assets.xcassets/                # App-level assets (icons, colors)
│   ├── BookReaderApp.swift              # App entry point
│   ├── BookReader.entitlements          # App sandbox settings
│   └── BookReader.xctestplan            # Test configuration
├── BookReaderPackage/                   # 🚀 Primary development area
│   ├── Package.swift                   # Package configuration
│   ├── Sources/BookReaderFeature/       # Your feature code
│   │   ├── Models/                    # SwiftData models
│   │   ├── Services/                  # Business logic
│   │   ├── Views/                     # SwiftUI views
│   │   └── ViewModels/                # View models
│   └── Tests/BookReaderFeatureTests/    # Unit tests
└── BookReaderUITests/                   # UI automation tests
```

### Workspace + SPM Structure
- **App Shell**: `BookReader/` contains minimal app lifecycle code
- **Feature Code**: `BookReaderPackage/Sources/BookReaderFeature/` is where most development happens
- **Separation**: Business logic lives in the SPM package, app target just imports and displays it

### Buildable Folders (Xcode 16)
- Files added to the filesystem automatically appear in Xcode
- No need to manually add files to project targets
- Reduces project file conflicts in teams

### App Sandbox
The app is sandboxed by default with basic file access permissions. Modify `BookReader.entitlements` to add capabilities as needed.

## 🧑‍💻 Development Guide

### Code Organization
Most development happens in `BookReaderPackage/Sources/BookReaderFeature/`:

```
BookReaderFeature/
├── Models/
│   ├── Book.swift                   # SwiftData book model
│   ├── ReadingProgress.swift        # Progress tracking
│   ├── Note.swift                   # Notes model
│   └── Collection.swift             # Folder/Collection model
├── Services/
│   ├── BookImportService.swift      # Import EPUB/PDF
│   ├── EPUBParserService.swift      # EPUB parsing wrapper
│   ├── PDFService.swift             # PDF handling
│   ├── KeychainService.swift        # Secure key storage
│   ├── GeminiService.swift          # AI API integration
│   └── ReadingTimeTracker.swift     # Page time tracking for AI gating
├── Views/
│   ├── Library/                     # Library views
│   ├── Reader/                      # Reader views
│   ├── Notes/                       # Notes views
│   ├── AI/                          # AI integration views
│   └── Settings/                    # Settings views
└── ViewModels/                      # View models
```

### Public API Requirements
Types exposed to the app target need `public` access:
```swift
public struct SettingsView: View {
    public init() {}
    
    public var body: some View {
        // Your view code
    }
}
```

### Adding Dependencies
Edit `BookReaderPackage/Package.swift` to add SPM dependencies:
```swift
dependencies: [
    .package(url: "https://github.com/example/SomePackage", from: "1.0.0")
],
targets: [
    .target(
        name: "BookReaderFeature",
        dependencies: ["SomePackage"]
    ),
]
```

### Test Structure
- **Unit Tests**: `BookReaderPackage/Tests/BookReaderFeatureTests/` (Swift Testing framework)
- **UI Tests**: `BookReaderUITests/` (XCUITest framework)
- **Test Plan**: `BookReader.xctestplan` coordinates all tests

## 🎨 Theme System

BookReader includes three carefully crafted reading themes:

| Theme | Background | Text Color | Accent |
|-------|-----------|-----------|--------|
| **Light** | `#FFFFFF` | `#1A1A1A` | `#007AFF` |
| **Sepia** | `#F4ECD8` | `#5B4636` | `#8B7355` |
| **Dark** | `#1C1C1E` | `#E5E5E7` | `#0A84FF` |

## 🤖 AI Integration Details

### AI Gating Mechanism
To encourage genuine reading and study, BookReader implements a intelligent gating system:

1. **Current Page**: Must read for 2 minutes before asking AI about current or future content
2. **Previous Content**: Instant access to ask about any previously read pages
3. **Progress Tracking**: Reading time tracked per page automatically
4. **Visual Feedback**: Timer shows remaining time until AI unlocks for current page

### Context-Aware Queries
When you ask a question, the AI receives:
- Book title and author
- Current chapter/section
- Summary of previously read content
- Selected text (if any)

This ensures relevant, contextual responses without spoilers.

## 📚 Supported Formats

- **EPUB** (.epub) - Full support with EPUBKit
- **PDF** (.pdf) - Native rendering with PDFKit

## 🗺 Roadmap

### Future Features
- **iCloud Sync** - Sync books, progress, and notes across devices
- **Text-to-Speech** - Read aloud feature
- **Highlights** - Text highlighting with colors
- **Reading Statistics** - Time spent, pages read, reading streaks
- **OPDS Catalog Support** - Import from online book catalogs
- **Goodreads Integration** - Track reading on Goodreads
- **AI Notes** - AI-assisted note summarization and organization

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

[Your chosen license here]

## 🙏 Acknowledgments

- Built with SwiftUI and SwiftData
- EPUB parsing powered by [EPUBKit](https://github.com/witekbobrowski/EPUBKit)
- AI powered by Google Gemini
- Project scaffolded using [XcodeBuildMCP](https://github.com/cameroncooke/XcodeBuildMCP)

---

**Made with ❤️ for book lovers who value deep, focused reading**