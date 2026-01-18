import SwiftUI
import SwiftData

public struct AIChatPanel: View {
    @Bindable var book: Book
    @ObservedObject var viewModel: ReaderViewModel
    @ObservedObject var geminiService = GeminiService.shared
    
    @State private var apiKeyInput: String = ""
    @State private var chatInput: String = ""
    @State private var isThinking = false
    @Environment(\.modelContext) private var modelContext
    
    public init(book: Book, viewModel: ReaderViewModel) {
        self.book = book
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if !geminiService.isConfigured {
                setupView
            } else {
                chatView
            }
        }
        .background(.regularMaterial)
    }
    
    var setupView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 48))
                .foregroundStyle(.purple)
            
            Text("Unlock AI Features")
                .font(.headline)
            
            Text("Enter your Gemini API Key to enable 'Ask Book' and implementation assistance.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            SecureField("API Key", text: $apiKeyInput)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            
            Button("Enable AI") {
                Task {
                    do {
                        try await geminiService.configure(apiKey: apiKeyInput)
                        apiKeyInput = "" // Clear input after success
                    } catch {
                        let errorMsg = AIChatMessage(role: .system, content: "Failed to save API key: \(error.localizedDescription)")
                        book.aiChatMessages.append(errorMsg)
                        modelContext.insert(errorMsg)
                        try? modelContext.save()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(apiKeyInput.isEmpty)
            
            Text("Your key is stored securely in the Keychain.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
    
    var chatView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Ask Document")
                    .font(.headline)
                Spacer()
                Button(action: { 
                    Task {
                        try? await geminiService.clearKey()
                    }
                }) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.bar)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if book.aiChatMessages.isEmpty {
                        Text("Ask questions about this book or the current page.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    
                    ForEach(book.aiChatMessages.sorted(by: { $0.createdAt < $1.createdAt })) { msg in
                        chatBubble(msg)
                    }
                    
                    if isThinking {
                         ProgressView()
                             .padding()
                             .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            
            Divider()
            
            HStack(alignment: .bottom) {
                TextEditor(text: $chatInput)
                    .frame(height: 60)
                    .padding(4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .padding(.bottom, 8)
                .disabled(chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking)
            }
            .padding()
        }
    }
    
    func chatBubble(_ msg: AIChatMessage) -> some View {
        HStack {
            if msg.role == .user { Spacer() }
            
            Text(msg.content)
                .padding(10)
                .background(msg.role == .user ? Color.blue : Color.gray.opacity(0.2))
                .foregroundStyle(msg.role == .user ? .white : .primary)
                .cornerRadius(12)
                .textSelection(.enabled)
            
            if msg.role == .assistant || msg.role == .system { Spacer() }
        }
    }
    
    func sendMessage() {
        let text = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Check if question is about current/future content
        let isAboutCurrentPage = text.lowercased().contains("this page") || 
                                 text.lowercased().contains("current page")
        
        // Time Gate check for current page
        if isAboutCurrentPage {
            let currentPageUnlocked = viewModel.hasUnlockedAI(for: viewModel.currentPageId)
            
            if !currentPageUnlocked {
                let remaining = max(0, Int(20 - viewModel.timeOnCurrentPage))
                let systemMsg = AIChatMessage(
                    role: .system, 
                    content: "🔒 Please read for \(remaining) more seconds to ask AI about this page.\n\n💡 You can ask about content from previous pages anytime!"
                )
                book.aiChatMessages.append(systemMsg)
                modelContext.insert(systemMsg)
                try? modelContext.save()
                chatInput = ""
                return
            }
        }
        
        let userMsg = AIChatMessage(role: .user, content: text)
        book.aiChatMessages.append(userMsg)
        modelContext.insert(userMsg)
        try? modelContext.save()
        
        chatInput = ""
        isThinking = true
        
        Task {
            do {
                // Build context from book and reading position
                let context = buildContext(for: text)
                
                // Build conversation history for context continuity
                let conversationHistory = buildConversationHistory()
                
                let fullPrompt = """
                Context: You are a helpful book reading assistant.
                Book: "\(viewModel.book.title)" by \(viewModel.book.author ?? "Unknown Author")
                Current Chapter: \(viewModel.currentChapterTitle ?? "Unknown Chapter")
                
                Instructions: Provide helpful, concise answers about the book content. Be educational and encourage genuine study.
                
                \(context)
                
                \(conversationHistory)
                
                User Question: \(text)
                """
                
                let response = try await geminiService.generateContent(prompt: fullPrompt)
                
                let assistantMsg = AIChatMessage(role: .assistant, content: response)
                book.aiChatMessages.append(assistantMsg)
                modelContext.insert(assistantMsg)
                try? modelContext.save()
            } catch let error as GeminiError {
                let errorMsg = AIChatMessage(role: .system, content: "❌ \(error.localizedDescription)")
                book.aiChatMessages.append(errorMsg)
                modelContext.insert(errorMsg)
                try? modelContext.save()
            } catch {
                let errorMsg = AIChatMessage(role: .system, content: "❌ Error: \(error.localizedDescription)")
                book.aiChatMessages.append(errorMsg)
                modelContext.insert(errorMsg)
                try? modelContext.save()
            }
            isThinking = false
        }
    }
    
    /// Build contextual information for AI prompt
    private func buildContext(for question: String) -> String {
        var context = ""
        
        // Add reading progress context
        let progress = viewModel.book.progress
        if let percentComplete = progress?.percentComplete {
            context += "Reading Progress: \(Int(percentComplete))% complete\n"
        }
        
        // Note: Full chapter content injection would require loading HTML
        // For now, we provide metadata. Future enhancement could extract current page text.
        
        return context
    }
    
    /// Build conversation history (last 5 exchanges for context)
    private func buildConversationHistory() -> String {
        // Only include actual user/assistant messages, not system messages
        let conversationMessages = book.aiChatMessages.filter { $0.role == .user || $0.role == .assistant }
        
        // Take last 5 exchanges (10 messages: 5 user + 5 assistant)
        let recentMessages = conversationMessages.sorted(by: { $0.createdAt < $1.createdAt }).suffix(10)
        
        guard !recentMessages.isEmpty else { return "" }
        
        var history = "Previous conversation:\n"
        for msg in recentMessages {
            let role = msg.role == .user ? "User" : "Assistant"
            history += "\(role): \(msg.content)\n"
        }
        
        return history
    }
}
