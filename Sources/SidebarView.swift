import SwiftUI

struct SidebarView: View {
    @ObservedObject var indexManager: IndexManager
    @ObservedObject var chatHistoryManager: ChatHistoryManager
    let onCreateIndex: () -> Void
    let onSelectConversation: (ChatConversation) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Text("DeepFind")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Button(action: onCreateIndex) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.headline)
                        Text("New Index")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(indexManager.isIndexing)
            }
            .padding(16)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Combined scrollable content
            if indexManager.indexes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 36))
                        .foregroundColor(.gray)
                    
                    Text("No Indexes Yet")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text("Create an index to start searching your documents")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Indexes section
                        VStack(alignment: .leading, spacing: 4) {
                            Text("INDEXES")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 12)
                                .padding(.top, 8)
                            
                            LazyVStack(spacing: 8) {
                                ForEach(indexManager.indexes) { index in
                                    IndexListItemView(
                                        index: index,
                                        isSelected: indexManager.selectedIndex?.id == index.id && chatHistoryManager.selectedConversation == nil,
                                        onSelect: {
                                            chatHistoryManager.deselectConversation()
                                            indexManager.selectIndex(index)
                                        },
                                        onDelete: {
                                            Task {
                                                await indexManager.deleteIndex(index)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        
                        // Recent chats section
                        if !chatHistoryManager.conversations.isEmpty {
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.vertical, 8)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("RECENT CHATS")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 12)
                                
                                LazyVStack(spacing: 6) {
                                    ForEach(chatHistoryManager.getRecentConversations(limit: 15)) { conversation in
                                        if let index = indexManager.indexes.first(where: { $0.id == conversation.indexId }) {
                                            ChatHistoryItemView(
                                                conversation: conversation,
                                                indexName: index.displayName,
                                                isSelected: chatHistoryManager.selectedConversation?.id == conversation.id,
                                                onSelect: {
                                                    indexManager.deselectIndex()
                                                    onSelectConversation(conversation)
                                                },
                                                onDelete: {
                                                    chatHistoryManager.deleteConversation(conversation)
                                                }
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.bottom, 8)
                            }
                        }
                    }
                }
            }
            
            // Indexing progress indicator at bottom
            if indexManager.isIndexing {
                Divider()
                    .background(Color.white.opacity(0.1))
                
                VStack(spacing: 8) {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.blue)
                        Text("Indexing...")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(Int(indexManager.indexingProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    ProgressView(value: indexManager.indexingProgress)
                        .tint(.blue)
                }
                .padding(16)
            }
        }
        .frame(width: 260)
        .background(Color.black.opacity(0.3))
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(.white.opacity(0.1)),
            alignment: .trailing
        )
    }
}
