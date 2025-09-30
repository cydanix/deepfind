import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var indexManager = IndexManager.shared
    @StateObject private var chatHistoryManager = ChatHistoryManager.shared
    @StateObject private var ragSearcher = RAGSearcher.shared
    @StateObject private var settings = SettingsStore.shared
    
    @State private var isFullScreen: Bool = false
    @State private var showingCreateIndex: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            // Left sidebar
            SidebarView(
                indexManager: indexManager,
                chatHistoryManager: chatHistoryManager,
                onCreateIndex: {
                    showingCreateIndex = true
                },
                onSelectConversation: { conversation in
                    chatHistoryManager.selectConversation(conversation)
                }
            )
            
            // Main content area
            Group {
                if let selectedConversation = chatHistoryManager.selectedConversation {
                    // Show chat view for selected conversation
                    if let index = indexManager.indexes.first(where: { $0.id == selectedConversation.indexId }) {
                        ChatView(
                            index: index,
                            ragSearcher: ragSearcher,
                            chatHistoryManager: chatHistoryManager,
                            conversation: selectedConversation,
                            onClose: {
                                chatHistoryManager.deselectConversation()
                            }
                        )
                        .id(selectedConversation.id)  // Force new view instance when conversation changes
                    }
                } else if let selectedIndex = indexManager.selectedIndex {
                    // Show chat view for selected index (new conversation)
                    ChatView(
                        index: selectedIndex,
                        ragSearcher: ragSearcher,
                        chatHistoryManager: chatHistoryManager,
                        conversation: nil,
                        onClose: {
                            indexManager.deselectIndex()
                        }
                    )
                    .id(selectedIndex.id)  // Force new view instance when index changes
                } else {
                    // Show index management view
                    IndexManagementView(
                        indexManager: indexManager,
                        onSelectIndexForChat: { index in
                            indexManager.selectIndex(index)
                        },
                        onCreateIndex: {
                            showingCreateIndex = true
                        }
                    )
                }
            }
        }
        .overlay(WindowAccessor(isFullScreen: $isFullScreen).frame(width: 0, height: 0))
        .frame(minWidth: 900, minHeight: 700)
        .foregroundColor(.white)
        .sheet(isPresented: $showingCreateIndex) {
            CreateIndexView(indexManager: indexManager)
        }
        .onAppear {
            Logger.log("ContentView appeared", log: Logger.general)
        }
    }
}
