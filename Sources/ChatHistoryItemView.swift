import SwiftUI

struct ChatHistoryItemView: View {
    let conversation: ChatConversation
    let indexName: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.displayTitle)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.caption2)
                        Text(indexName)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .foregroundColor(.gray.opacity(0.8))
                    
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.caption2)
                        Text("\(conversation.messageCount) messages")
                            .font(.caption2)
                    }
                    .foregroundColor(.gray.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Delete button
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .confirmationDialog(
                    "Delete Chat",
                    isPresented: $showingDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        onDelete()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Are you sure you want to delete this chat? This action cannot be undone.")
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.green.opacity(0.2) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
