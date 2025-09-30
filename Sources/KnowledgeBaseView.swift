import SwiftUI

struct KnowledgeBaseView: View {
    @ObservedObject var folderIndexer: FolderIndexer
    let onSelectFolder: () -> Void
    let onReindexFolder: () async throws -> Void
    let onClearIndex: () async -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            if folderIndexer.indexedFolderPath != nil {
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
                            onSelectFolder()
                        } label: {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.bordered)
                        .disabled(folderIndexer.isIndexing)
                        
                        Button {
                            Task {
                                try await onReindexFolder()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(folderIndexer.isIndexing)
                        
                        Button {
                            Task {
                                await onClearIndex()
                            }
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
                        onSelectFolder()
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
}
