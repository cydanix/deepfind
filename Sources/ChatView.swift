import SwiftUI

struct ChatView: View {
    let index: Index
    @ObservedObject var ragSearcher: RAGSearcher
    @ObservedObject var chatHistoryManager: ChatHistoryManager
    let conversation: ChatConversation?
    let onClose: () -> Void
    
    @State private var query: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var statusMessage: String = ""
    @State private var currentConversationId: String = ""
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                chatHeaderView
                
                // Chat area
                ChatAreaView(messages: messages, showEmptyState: true)
                
                // Input area
                chatInputArea
            }
        }
        .onAppear {
            Logger.log("ChatView appeared for index: \(index.displayName)", log: Logger.general)
            loadConversation()
        }
        .onChange(of: conversation?.id) {
            loadConversation()
        }
    }
    
    private func loadConversation() {
        if let existingConversation = conversation {
            // Load existing conversation
            messages = existingConversation.messages
            currentConversationId = existingConversation.id
            Logger.log("Loaded conversation with \(messages.count) messages", log: Logger.general)
        } else {
            // Don't create conversation yet - wait for first message
            currentConversationId = ""
            messages = []
            Logger.log("Ready for new conversation", log: Logger.general)
        }
    }
    
    // Header for chat mode
    private var chatHeaderView: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: onClose) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.caption)
                        Text("Back")
                            .font(.subheadline)
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(index.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.caption2)
                        Text("\(index.fileCount) files")
                            .font(.caption)
                    }
                    .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Placeholder to balance the back button
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                    Text("Back")
                        .font(.subheadline)
                }
                .opacity(0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.05))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.white.opacity(0.1)),
            alignment: .bottom
        )
    }
    
    // Input area for chat
    private var chatInputArea: some View {
        VStack(spacing: 12) {
            // Query suggestions
            if !query.isEmpty {
                let suggestions = ragSearcher.getSuggestions(for: query)
                if !suggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggestions.prefix(3), id: \.self) { suggestion in
                                Button(suggestion) {
                                    query = suggestion
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            
            // Main input area
            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    TextField("Ask a question about your documents...", text: $query, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .foregroundColor(.white)
                        .disabled(ragSearcher.isSearching)
                        .onSubmit {
                            Task {
                                await performSearch()
                            }
                        }
                        .background(Color.clear)
                        .lineLimit(1...4)
                    
                    Button {
                        Task {
                            await performSearch()
                        }
                    } label: {
                        if ragSearcher.isSearching {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(query.isEmpty ? .gray : .blue)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(query.isEmpty || ragSearcher.isSearching)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.blue.opacity(0.5), lineWidth: 2)
                )
                .cornerRadius(25)
                
                // Status indicator
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(.green.opacity(0.8))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.3), Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.white.opacity(0.1)),
            alignment: .top
        )
    }
    
    private func performSearch() async {
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return }
        
        // Create conversation on first message if it doesn't exist yet
        await MainActor.run {
            if currentConversationId.isEmpty {
                let newConversation = chatHistoryManager.createConversation(for: index.id)
                currentConversationId = newConversation.id
                Logger.log("Created new conversation on first message: \(currentConversationId)", log: Logger.general)
            }
        }
        
        // Add user message to chat
        let userMessage = ChatMessage(content: searchQuery, isUser: true)
        await MainActor.run {
            messages.append(userMessage)
            query = ""  // Clear input after sending
            
            // Save user message to conversation
            chatHistoryManager.addMessage(to: currentConversationId, message: userMessage)
        }
        
        do {
            // Search using the specific index ID
            let result = try await ragSearcher.search(query: searchQuery, indexId: index.id)
            
            // Add AI response to chat
            let aiMessage = ChatMessage(content: result, isUser: false)
            await MainActor.run {
                messages.append(aiMessage)
                statusMessage = "Search completed successfully"
                
                // Save AI message to conversation
                chatHistoryManager.addMessage(to: currentConversationId, message: aiMessage)
            }
            
        } catch {
            Logger.log("Search error: \(error)", log: Logger.general, type: .error)
            
            // Add error message to chat
            let errorMessage = ChatMessage(content: "I'm sorry, I encountered an error while searching: \(error.localizedDescription)", isUser: false)
            await MainActor.run {
                messages.append(errorMessage)
                statusMessage = ""
                
                // Save error message to conversation
                chatHistoryManager.addMessage(to: currentConversationId, message: errorMessage)
            }
        }
    }
}
