import SwiftUI
import AppKit

struct CreateIndexView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var indexManager: IndexManager
    
    @State private var indexName: String = ""
    @State private var selectedFolderPath: String = ""
    @State private var errorMessage: String = ""
    @State private var isCreating: Bool = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            Text("Create New Index")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Form
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Index Name")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextField("My Documents", text: $indexName)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Folder Path")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack {
                        Text(selectedFolderPath.isEmpty ? "No folder selected" : selectedFolderPath)
                            .font(.body)
                            .foregroundColor(selectedFolderPath.isEmpty ? .gray : .white)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                        
                        Button("Browse...") {
                            selectFolder()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                if !errorMessage.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text(errorMessage)
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                }
            }
            .padding(.horizontal, 24)
            
            // Actions
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                
                Button("Create Index") {
                    createIndex()
                }
                .buttonStyle(.borderedProminent)
                .disabled(indexName.isEmpty || selectedFolderPath.isEmpty || isCreating)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 32)
        .frame(width: 500)
        .background(Color.black)
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
                selectedFolderPath = url.path
                
                // If index name is empty, suggest folder name
                if indexName.isEmpty {
                    indexName = url.lastPathComponent
                }
            }
        }
    }
    
    private func createIndex() {
        errorMessage = ""
        isCreating = true
        
        Task {
            do {
                try await indexManager.createIndex(name: indexName, folderPath: selectedFolderPath)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}
