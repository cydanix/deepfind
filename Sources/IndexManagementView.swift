import SwiftUI

struct IndexManagementView: View {
    @ObservedObject var indexManager: IndexManager
    let onSelectIndexForChat: (Index) -> Void
    let onCreateIndex: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if indexManager.indexes.isEmpty {
                // Empty state
                VStack(spacing: 24) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 64))
                        .foregroundColor(.blue.opacity(0.6))
                    
                    Text("Welcome to DeepFind")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Create your first index to start searching and chatting with your documents")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                    
                    Button(action: onCreateIndex) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                            Text("Create Your First Index")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // List of indexes
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Indexes")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Select an index to start chatting with your documents")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 32)
                        .padding(.top, 32)
                        
                        LazyVStack(spacing: 16) {
                            ForEach(indexManager.indexes) { index in
                                IndexCardView(
                                    index: index,
                                    onChat: {
                                        onSelectIndexForChat(index)
                                    },
                                    onDelete: {
                                        Task {
                                            await indexManager.deleteIndex(index)
                                        }
                                    },
                                    onReindex: {
                                        Task {
                                            try? await indexManager.reindexIndex(index)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
    }
}

struct IndexCardView: View {
    let index: Index
    let onChat: () -> Void
    let onDelete: () -> Void
    let onReindex: () -> Void
    
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        HStack(spacing: 20) {
            // Index info
            VStack(alignment: .leading, spacing: 12) {
                Text(index.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.caption)
                        Text(index.folderPath)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundColor(.gray)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.caption)
                        Text("\(index.fileCount) files")
                            .font(.caption)
                    }
                    .foregroundColor(.gray)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("Last indexed: \(formatDate(index.lastIndexedAt))")
                        .font(.caption)
                }
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: onReindex) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                        Text("Reindex")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .frame(width: 80)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                
                Button(action: onChat) {
                    VStack(spacing: 4) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.title3)
                        Text("Chat")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 80)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.title3)
                        Text("Delete")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 80)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .confirmationDialog(
                    "Delete Index",
                    isPresented: $showingDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        onDelete()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Are you sure you want to delete the index '\(index.displayName)'? This action cannot be undone.")
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
