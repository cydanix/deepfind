import SwiftUI

struct HeaderView: View {
    @ObservedObject var folderIndexer: FolderIndexer
    let onSelectFolder: () -> Void
    let onReindexFolder: () async throws -> Void
    let onClearIndex: () async -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("DeepFind Chat")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            // Always visible knowledge base section
            KnowledgeBaseView(
                folderIndexer: folderIndexer,
                onSelectFolder: onSelectFolder,
                onReindexFolder: onReindexFolder,
                onClearIndex: onClearIndex
            )
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
}
