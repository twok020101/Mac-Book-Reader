import SwiftUI
import SwiftData

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    
    enum MessageRole {
        case user
        case assistant
        case system
    }
}

public struct AIChatPanel: View {
    @ObservedObject var viewModel: ReaderViewModel
    @ObservedObject var geminiService = GeminiService.shared
    
    @State private var apiKeyInput: String = ""
    @State private var chatInput: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var isThinking = false
    
    public init(viewModel: ReaderViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack {
            if !geminiService.isConfigured {
                setupView
            } else {
                chatView
            }
        }
        .frame(width: 320)
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
                geminiService.configure(apiKey: apiKeyInput)
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
                Button(action: { geminiService.clearKey() }) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.bar)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if messages.isEmpty {
                        Text("Ask questions about this book or the current page.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    
                    ForEach(messages) { msg in
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
    
    func chatBubble(_ msg: ChatMessage) -> some View {
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
        
        let isPageSpecific = text.lowercased().contains("this page") || text.lowercased().contains("curren page")
        
        // Time Gate check
        if isPageSpecific {
            let timeOnPage = viewModel.timeOnCurrentPage
            if timeOnPage < 120 { // 2 minutes
                let remaining = Int(120 - timeOnPage)
                messages.append(ChatMessage(role: .system, content: "🔒 Please read the page for \(remaining) more seconds before asking AI about it."))
                chatInput = ""
                return
            }
        }
        
        messages.append(ChatMessage(role: .user, content: text))
        chatInput = ""
        isThinking = true
        
        Task {
            do {
                // TODO: Inject context (book content or current page text)
                // For now, simple prompt
                let fullPrompt = "Context: You are a helpful book reading assistant. User is reading '\(viewModel.book.title)'.\n\nUser: \(text)"
                
                let response = try await geminiService.generateContent(prompt: fullPrompt)
                messages.append(ChatMessage(role: .assistant, content: response))
            } catch {
                messages.append(ChatMessage(role: .system, content: "Error: \(error.localizedDescription)"))
            }
            isThinking = false
        }
    }
}
