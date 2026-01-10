import SwiftUI
import SwiftData

public struct ReaderView: View {
    let book: Book
    @Binding var columnVisibility: NavigationSplitViewVisibility // Kept for compatibility with BookGridView call site
    
    @StateObject private var viewModel: ReaderViewModel
    @State private var showAIChat: Bool = false
    @State private var showFocusModeWelcome: Bool = false
    @State private var isInFocusMode: Bool = false
    @FocusState private var isReaderFocused: Bool
    @State private var showShortcutsPopover: Bool = false
    
    #if os(macOS)
    @State private var arrowKeyMonitor: Any?
    #endif
    
    
    public init(book: Book, columnVisibility: Binding<NavigationSplitViewVisibility>, initialChapterIndex: Int? = nil, initialPageIndex: Int? = nil) {
        self.book = book
        self._columnVisibility = columnVisibility
        let viewModel = ReaderViewModel(book: book)
        
        // Set pending navigation to be applied after book loads
        if initialChapterIndex != nil || initialPageIndex != nil {
            viewModel.setPendingNavigation(chapterIndex: initialChapterIndex, pageIndex: initialPageIndex)
        }
        
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    #if os(macOS)
    private func setupArrowKeyMonitor() {
        arrowKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            
            let modifiers = event.modifierFlags
            
            // Arrow keys (without modifiers)
            if modifiers.intersection([.command, .shift, .option, .control]).isEmpty {
                if event.keyCode == 123 { // Left arrow
                    DispatchQueue.main.async {
                        self.viewModel.previousPage()
                    }
                    return nil
                } else if event.keyCode == 124 { // Right arrow
                    DispatchQueue.main.async {
                        self.viewModel.nextPage()
                    }
                    return nil
                }
            }
            
            // Cmd+N (Toggle Notes)
            if modifiers.contains(.command) && !modifiers.contains(.shift) && event.keyCode == 45 { // N key
                DispatchQueue.main.async {
                    withAnimation { self.viewModel.showNotes.toggle() }
                    if self.viewModel.showNotes { self.viewModel.showChapterList = false }
                }
                return nil
            }
            
            // Cmd+I (AI Chat)
            if modifiers.contains(.command) && !modifiers.contains(.shift) && event.keyCode == 34 { // I key
                DispatchQueue.main.async {
                    self.showAIChat.toggle()
                }
                return nil
            }
            
            // Cmd+Shift+F (Focus Mode)
            if modifiers.contains(.command) && modifiers.contains(.shift) && event.keyCode == 3 { // F key
                DispatchQueue.main.async {
                    if self.isInFocusMode {
                        self.exitFocusMode()
                    } else {
                        self.showFocusModeWelcome = true
                    }
                }
                return nil
            }
            
            // Esc (Exit Focus Mode)
            if event.keyCode == 53 { // Esc key
                if self.isInFocusMode {
                    DispatchQueue.main.async {
                        self.exitFocusMode()
                    }
                    return nil
                }
            }
            
            return event
        }
    }
    #endif
    
    
    public var body: some View {
        readerContent
            .sheet(isPresented: $showFocusModeWelcome) {
                FocusModeWelcomeView(isPresented: $showFocusModeWelcome) {
                    enterFocusMode()
                }
            }
            .sheet(isPresented: $showAIChat) {
                AIChatPanel(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showNotesListSheet) {
                NavigationStack {
                    BookNotesView(book: book, viewModel: viewModel)
                }
                .frame(minWidth: 500, minHeight: 600)
            }
    }
    
    private var readerContent: some View {
        HStack(spacing: 0) {
            // Chapter List Sidebar (hidden in focus mode)
            if viewModel.showChapterList && !isInFocusMode {
                ChapterListSidePanel(viewModel: viewModel)
                    .frame(width: 250)
                    .transition(.move(edge: .leading))
                
                Divider()
            }
            
            // Main Content Area
            ZStack {
                Color(nsColor: .windowBackgroundColor) // Background
                
                if book.fileType == .epub {
                    EPUBPageView(viewModel: viewModel)
                } else {
                    Text("PDF Support Coming Soon")
                }
                
                // Reader Toolbar Overlay (hidden in focus mode)
                if !isInFocusMode {
                    VStack {
                        Spacer()
                        ReaderToolbar(viewModel: viewModel)
                            .padding(.bottom, 20)
                    }
                }
                
                // Info button for shortcuts (only in focus mode)
                if isInFocusMode {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: { showShortcutsPopover.toggle() }) {
                                Image(systemName: "info.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                            .padding(8)
                            .background(.black.opacity(0.3))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            .popover(isPresented: $showShortcutsPopover) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Keyboard Shortcuts")
                                        .font(.headline)
                                    
                                    Divider()
                                    
                                    ShortcutRow(key: "←/→", description: "Turn pages")
                                    ShortcutRow(key: "Cmd+N", description: "Toggle Notes")
                                    ShortcutRow(key: "Cmd+I", description: "Ask AI")
                                    ShortcutRow(key: "Cmd+Shift+F or Esc", description: "Exit Focus")
                                }
                                .padding()
                                .frame(width: 250)
                            }
                            .padding(.trailing, 20)
                            .padding(.top, 20)
                        }
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Notes Sidebar (accessible in focus mode for note-taking)
            if viewModel.showNotes {
                Divider()
                
                NotesSidePanel(book: book, viewModel: viewModel)
                    .frame(width: 300)
                    .transition(.move(edge: .trailing))
            }
        }
        .task {
            await viewModel.loadBook()
            viewModel.startTrackingTime()
            
            #if os(macOS)
            setupArrowKeyMonitor()
            #endif
        }
        .onDisappear {
            viewModel.stopTrackingTime()
            
            #if os(macOS)
            if let monitor = arrowKeyMonitor {
                NSEvent.removeMonitor(monitor)
                arrowKeyMonitor = nil
            }
            #endif
        }
        .toolbar {
            // Hide all toolbar items in focus mode
            if !isInFocusMode {
                // Top-left toolbar
                ToolbarItemGroup(placement: .navigation) {
                    Button(action: { 
                        withAnimation { viewModel.showChapterList.toggle() }
                        if viewModel.showChapterList { viewModel.showNotes = false }
                    }) {
                        Label("Table of Contents", systemImage: "list.bullet")
                    }
                    .help("Toggle Table of Contents")
                }
                
                // Top-right toolbar
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: { showAIChat.toggle() }) {
                        Label("AI Chat", systemImage: "sparkles")
                    }
                    .help("Chat with AI about this book (Cmd+I)")
                    
                    Button(action: { 
                        withAnimation { viewModel.showNotes.toggle() }
                        if viewModel.showNotes { viewModel.showChapterList = false }
                    }) {
                        Label("Notes", systemImage: "square.and.pencil")
                    }
                    .help("Toggle Notes (Cmd+N)")
                    
                    Button(action: { viewModel.showNotesListSheet = true }) {
                        Label("Notes List", systemImage: "list.bullet.rectangle")
                    }
                    .help("View all notes for this book")
                    
                    Button(action: { showFocusModeWelcome = true }) {
                        Label("Focus Mode", systemImage: "moon.stars.fill")
                    }
                    .help("Enter Focus Mode (Cmd+Shift+F)")
                }
            }
        }
    }
    
    // MARK: - Focus Mode Functions
    
    private func enterFocusMode() {
        withAnimation {
            isInFocusMode = true
            // Hide sidebars
            viewModel.showChapterList = false
            viewModel.showNotes = false
        }
        
        // Enter true immersive fullscreen (macOS)
        #if os(macOS)
        DispatchQueue.main.async {
            if let window = NSApp.keyWindow {
                // Hide title bar and toolbar
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.styleMask.insert(.fullSizeContentView)
                window.toolbar?.isVisible = false  // Hide the toolbar with back button
                
                // Set presentation options for immersive mode
                NSApp.presentationOptions = [.autoHideMenuBar, .autoHideDock, .fullScreen]
                
                // Toggle fullscreen if not already
                if !window.styleMask.contains(.fullScreen) {
                    window.toggleFullScreen(nil)
                }
            }
        }
        #endif
    }
    
    private func exitFocusMode() {
        withAnimation {
            isInFocusMode = false
        }
        
        // Exit fullscreen and restore window
        #if os(macOS)
        DispatchQueue.main.async {
            if let window = NSApp.keyWindow {
                // Restore title bar and toolbar
                window.titleVisibility = .visible
                window.titlebarAppearsTransparent = false
                window.toolbar?.isVisible = true  // Restore toolbar
                
                // Reset presentation options
                NSApp.presentationOptions = []
                
                // Exit fullscreen
                if window.styleMask.contains(.fullScreen) {
                    window.toggleFullScreen(nil)
                }
            }
        }
        #endif
    }
}

// MARK: - Helper View for Shortcuts

struct ShortcutRow: View {
    let key: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(key)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary)
                .cornerRadius(4)
                .frame(minWidth: 80, alignment: .leading)
            
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
