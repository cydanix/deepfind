import SwiftUI

struct InputAreaView: View {
    @Binding var query: String
    let statusMessage: String
    @ObservedObject var folderIndexer: FolderIndexer
    @ObservedObject var ragSearcher: RAGSearcher
    let onPerformSearch: () async -> Void
    
    var body: some View {
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
                                await onPerformSearch()
                            }
                        }
                        .background(Color.clear)
                        .lineLimit(1...4)
                    
                    Button {
                        Task {
                            await onPerformSearch()
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
}
