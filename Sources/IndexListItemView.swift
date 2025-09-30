import SwiftUI

struct IndexListItemView: View {
    let index: Index
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                Text(index.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.caption2)
                    Text(index.folderName)
                        .font(.caption2)
                        .lineLimit(1)
                }
                .foregroundColor(.gray)
                
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.caption2)
                    Text("\(index.fileCount) files")
                        .font(.caption2)
                }
                .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
