import SwiftUI
import AppKit
import UniformTypeIdentifiers

// Chat message data model
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    
    init(content: String, isUser: Bool) {
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
    }
}

struct ContentView: View {
    @StateObject private var folderIndexer = FolderIndexer.shared
    @StateObject private var ragSearcher = RAGSearcher.shared
    @StateObject private var settings = SettingsStore.shared
    
    @State private var query: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var statusMessage: String = ""
    @State private var isFullScreen: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with knowledge base info
                headerView
                
                // Chat area
                chatArea
                
                // Input area at bottom
                inputArea
            }
        }
        .overlay(WindowAccessor(isFullScreen: $isFullScreen).frame(width: 0, height: 0))
        .frame(minWidth: 600, minHeight: 700)
        .foregroundColor(.white)
        .onAppear {
            Logger.log("ContentView appeared", log: Logger.general)
        }
    }
    
    // Header view with knowledge base controls
    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("DeepFind Chat")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            // Always visible knowledge base section
            knowledgeBaseView
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(Color.white.opacity(0.05))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.white.opacity(0.1)),
            alignment: .bottom
        )
    }
    
    // Knowledge base controls - always visible
    private var knowledgeBaseView: some View {
        VStack(spacing: 16) {
            if let folderPath = folderIndexer.indexedFolderPath {
                // When folder is selected - compact view
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Knowledge Base: Ready")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        Text(folderIndexer.getIndexingSummary())
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Button {
                            selectFolder()
                        } label: {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.bordered)
                        .disabled(folderIndexer.isIndexing)
                        
                        Button {
                            Task {
                                try await reindexFolder()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(folderIndexer.isIndexing)
                        
                        Button {
                            folderIndexer.clearIndex()
                            clearResults()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.bordered)
                        .disabled(folderIndexer.isIndexing)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
                
                if folderIndexer.isIndexing {
                    HStack {
                        ProgressView(value: folderIndexer.indexingProgress)
                            .frame(maxWidth: .infinity)
                        Text("\(Int(folderIndexer.indexingProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 16)
                }
            } else {
                // When no folder is selected - prominent call-to-action
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                        
                        Text("Set Up Knowledge Base")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Choose a folder containing documents to create your searchable knowledge base")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: {
                        selectFolder()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "folder")
                                .font(.headline)
                            Text("Select Documents Folder")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .disabled(folderIndexer.isIndexing)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.blue.opacity(0.1))
                        .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                )
            }
        }
    }
    
    // Chat messages area
    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if messages.isEmpty {
                        VStack(spacing: 20) {
                            if folderIndexer.indexedFolderPath != nil {
                                VStack(spacing: 16) {
                                    Image(systemName: "bubble.left.and.bubble.right")
                                        .font(.system(size: 48))
                                        .foregroundColor(.blue.opacity(0.6))
                                    
                                    Text("Ready to Chat!")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                    
                                    Text("Your knowledge base is ready. Ask any question about your documents below.")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                                
                                // Sample questions
                                VStack(spacing: 8) {
                                    Text("Try asking:")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    VStack(spacing: 6) {
                                        Text("• \"Summarize the main points\"")
                                        Text("• \"What are the key findings?\"")
                                        Text("• \"Explain the methodology\"")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.gray.opacity(0.8))
                                }
                            } else {
                                VStack(spacing: 16) {
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 32))
                                        .foregroundColor(.blue.opacity(0.6))
                                    
                                    Text("Set up your knowledge base above to start chatting")
                                        .font(.title3)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 100)
                            }
                        }
                    } else {
                        ForEach(messages) { message in
                            chatMessageView(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .onChange(of: messages.count) {
                if let lastMessage = messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // Individual chat message view
    private func chatMessageView(message: ChatMessage) -> some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)
                
                Text(message.content)
                    .padding(12)
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .textSelection(.enabled)
                    .contextMenu {
                        Button("Copy") {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(message.content, forType: .string)
                        }
                        
                        if #available(macOS 13.0, *) {
                            ShareLink("Share", item: message.content)
                        }
                    }
            } else {
                Text(message.content)
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .textSelection(.enabled)
                    .contextMenu {
                        Button("Copy") {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(message.content, forType: .string)
                        }
                        
                        if #available(macOS 13.0, *) {
                            ShareLink("Share", item: message.content)
                        }
                    }
                
                Spacer(minLength: 60)
            }
        }
    }
    
    // Input area at bottom - highly visible
    private var inputArea: some View {
        VStack(spacing: 12) {
            // Query suggestions
            if !query.isEmpty && folderIndexer.indexedFolderPath != nil {
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
            
            // Main input area with enhanced visibility
            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    TextField("Ask a question about your documents...", text: $query, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .foregroundColor(.white)
                        .disabled(folderIndexer.indexedFolderPath == nil || ragSearcher.isSearching)
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
                                .foregroundColor(query.isEmpty || folderIndexer.indexedFolderPath == nil ? .gray : .blue)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(query.isEmpty || folderIndexer.indexedFolderPath == nil || ragSearcher.isSearching)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(
                            folderIndexer.indexedFolderPath != nil ? Color.blue.opacity(0.5) : Color.gray.opacity(0.3), 
                            lineWidth: 2
                        )
                )
                .cornerRadius(25)
                
                // Status indicator
                if folderIndexer.indexedFolderPath == nil {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.caption)
                        Text("Set up your knowledge base above to start asking questions")
                            .font(.caption)
                    }
                    .foregroundColor(.gray.opacity(0.7))
                } else if !statusMessage.isEmpty {
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

    private func selectFolder() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Select Folder to Index"
        openPanel.message = "Choose a folder containing documents you want to search"
        
        openPanel.begin { result in
            if result == .OK, let url = openPanel.url {
                Task {
                    do {
                        Logger.log("Selected folder: \(url.path)", log: Logger.general)
                        try await self.folderIndexer.indexFolder(at: url.path)
                        await MainActor.run {
                            self.statusMessage = "Folder indexed successfully"
                        }
                    } catch {
                        await MainActor.run {
                            Logger.log("Indexing error: \(error)", log: Logger.general, type: .error)
                            // Add error message to chat if there are already messages
                            if !self.messages.isEmpty {
                                let errorMessage = ChatMessage(content: "Failed to index folder: \(error.localizedDescription)", isUser: false)
                                self.messages.append(errorMessage)
                            }
                            self.statusMessage = "Indexing failed"
                        }
                    }
                }
            }
        }
    }
    
    private func reindexFolder() async throws {
        guard let folderPath = folderIndexer.indexedFolderPath else { return }
        
        try await folderIndexer.indexFolder(at: folderPath)
        statusMessage = "Folder re-indexed successfully"
    }
    
    private func performSearch() async {
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return }
        
        // Add user message to chat
        let userMessage = ChatMessage(content: searchQuery, isUser: true)
        await MainActor.run {
            messages.append(userMessage)
            query = ""  // Clear input after sending
        }
        
        do {
            let result = try await ragSearcher.search(query: searchQuery)
            
            // Add AI response to chat
            let aiMessage = ChatMessage(content: result, isUser: false)
            await MainActor.run {
                messages.append(aiMessage)
                statusMessage = "Search completed successfully"
            }
            
        } catch {
            Logger.log("Search error: \(error)", log: Logger.general, type: .error)
            
            // Add error message to chat
            let errorMessage = ChatMessage(content: "I'm sorry, I encountered an error while searching: \(error.localizedDescription)", isUser: false)
            await MainActor.run {
                messages.append(errorMessage)
                statusMessage = ""
            }
        }
    }
    
    private func clearResults() {
        query = ""
        messages = []
        statusMessage = ""
    }
}

// Helper to access NSWindow and observe full screen changes
private struct WindowAccessor: NSViewRepresentable {
    @Binding var isFullScreen: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                context.coordinator.observe(window: window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            context.coordinator.observe(window: window)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isFullScreen: $isFullScreen)
    }

    class Coordinator: NSObject, NSWindowDelegate {
        var isFullScreen: Binding<Bool>
        private var observedWindow: NSWindow?

        init(isFullScreen: Binding<Bool>) {
            self.isFullScreen = isFullScreen
        }

        func observe(window: NSWindow) {
            if observedWindow !== window {
                observedWindow?.delegate = nil
                observedWindow = window
                window.delegate = self
                isFullScreen.wrappedValue = (window.styleMask.contains(.fullScreen))
            }
        }

        func windowDidEnterFullScreen(_ notification: Notification) {
            isFullScreen.wrappedValue = true
        }
        func windowDidExitFullScreen(_ notification: Notification) {
            isFullScreen.wrappedValue = false
        }
    }
}
