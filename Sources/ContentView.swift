import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
                HeaderView(
                    folderIndexer: folderIndexer,
                    onSelectFolder: selectFolder,
                    onReindexFolder: reindexFolder,
                    onClearIndex: {
                        await folderIndexer.clearIndex()
                        clearResults()
                    }
                )
                
                // Chat area
                ChatAreaView(messages: messages, folderIndexer: folderIndexer)
                
                // Input area at bottom
                InputAreaView(
                    query: $query,
                    statusMessage: statusMessage,
                    folderIndexer: folderIndexer,
                    ragSearcher: ragSearcher,
                    onPerformSearch: performSearch
                )
            }
        }
        .overlay(WindowAccessor(isFullScreen: $isFullScreen).frame(width: 0, height: 0))
        .frame(minWidth: 600, minHeight: 700)
        .foregroundColor(.white)
        .onAppear {
            Logger.log("ContentView appeared", log: Logger.general)
        }
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
