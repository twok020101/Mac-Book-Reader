# BookReader macOS App - Task Breakdown

## Planning Phase
- [/] Research and architecture design
- [x] Create implementation plan
- [x] Get user approval on plan

## Core Infrastructure
- [x] Set up Xcode project with Swift/SwiftUI
- [/] Configure Swift Package Manager dependencies
- [/] Set up SwiftData models for persistence
- [/] Implement Keychain wrapper for API key storage

## Document Parsing
- [x] Integrate EPUBKit for EPUB parsing
- [x] Implement PDFKit integration for PDF support
- [x] Create unified document model abstraction

## Library View (Book Selector)
- [x] Design library grid/list UI
- [x] Implement book import functionality
- [x] Add collection/folder management
- [x] Implement search by title
- [ ] Add tag support (if time permits)

## Reader View
- [x] Create paginated reader with page-turning animations
- [x] Implement paper texture/sepia/night mode themes
- [x] Add typography controls (font, size, line spacing, margins)
- [x] Implement reading progress tracking
- [x] Add time-on-page tracking for AI gating

## Focus Mode
- [x] Implement fullscreen reader mode
- [x] Research and implement notification suppression (within app limits)

## Notes System
- [x] Create notes data model
- [x] Implement collapsible notes panel with keyboard shortcut
- [x] Build notes viewer organized by book
- [x] Add note creation/editing for plain text

## Gemini AI Integration
- [x] Implement API key input and secure storage
- [x] Create Gemini API service layer
- [x] Implement text selection for AI queries
- [x] Add 2-minute reading gate for current/future page queries
- [x] Build AI chat interface

## Polish & Testing
- [ ] Test EPUB and PDF rendering
- [ ] Test reading progress persistence
- [ ] Test AI integration flow
- [ ] UI/UX polish and animations
