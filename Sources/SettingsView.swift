import SwiftUI
import Cocoa

struct SettingsView: View {
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var folderIndexer = FolderIndexer.shared
    
    // Reset confirmation state
    @State private var showingResetConfirmation = false
    
    // Delete confirmation states
    @State private var showingDeleteModelsConfirmation = false
    @State private var showingDeleteIndexesConfirmation = false
    @State private var showingDeleteConversationsConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Settings")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Manage storage and application settings")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 24)
                
                // Context Size
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Context Size")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack {
                            Text("\(settings.contextSize) tokens")
                                .font(.body)
                                .foregroundColor(.blue)
                                .frame(width: 100, alignment: .trailing)
                            
                            Slider(value: Binding(
                                get: { Double(settings.contextSize) },
                                set: { settings.contextSize = Int($0) }
                            ), in: 4000...25000, step: 1000)
                            
                            Text("4K - 25K")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Text("The larger the context size, the more document content will be used to generate answers. This results in better, more comprehensive responses but takes longer to process.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                }
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                
                // Storage Management
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Storage Management")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Delete downloaded AI models, indexes, or conversations from your system. This will free up disk space but you may need to re-download or re-create items when needed.")
                            .font(.body)
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 12) {
                            Button("Delete Models") {
                                showingDeleteModelsConfirmation = true
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                            
                            Button("Delete Indexes") {
                                showingDeleteIndexesConfirmation = true
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                            
                            Button("Delete Conversations") {
                                showingDeleteConversationsConfirmation = true
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                            
                            Spacer()
                        }
                    }
                    .padding()
                }
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                
                // Reset to Defaults
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Reset to Defaults")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("This will reset all settings to their default values, including search parameters and LLM settings. This action cannot be undone.")
                            .font(.body)
                            .foregroundColor(.gray)
                        
                        HStack {
                            Button("Reset All Settings") {
                                showingResetConfirmation = true
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                            
                            Spacer()
                        }
                    }
                    .padding()
                }
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .frame(minWidth: 600, minHeight: 400)
        .background(Color.black)
        .alert("Reset Settings", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetSettings()
            }
        } message: {
            Text("Are you sure you want to reset all settings to their default values? This will reset indexing parameters, search settings, and LLM configuration. This action cannot be undone.")
        }
        .alert("Delete All Models", isPresented: $showingDeleteModelsConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAllModels()
            }
        } message: {
            Text("Are you sure you want to delete all downloaded AI models? This will free up disk space but you'll need to re-download models when they're needed again. This action cannot be undone.")
        }
        .alert("Delete All Indexes", isPresented: $showingDeleteIndexesConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAllIndexes()
            }
        } message: {
            Text("Are you sure you want to delete all indexes? This will remove all indexed folder data and you'll need to re-index folders when needed again. This action cannot be undone.")
        }
        .alert("Delete All Conversations", isPresented: $showingDeleteConversationsConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAllConversations()
            }
        } message: {
            Text("Are you sure you want to delete all chat conversations? All conversation history will be permanently removed. This action cannot be undone.")
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Reset Settings
    
    private func resetSettings() {
        settings.resetToDefaults()
        Task {
            await folderIndexer.clearIndex()
        }
        Logger.log("Settings reset to defaults", log: Logger.general)
    }
    
    // MARK: - Storage Management
    
    private func deleteAllModels() {
        ModelStorage.shared.deleteAllModels()
        Logger.log("All models deleted by user", log: Logger.general)
    }
    
    private func deleteAllIndexes() {
        Task {
            await IndexManager.shared.deleteAllIndexes()
        }
        Logger.log("All indexes deleted by user", log: Logger.general)
    }
    
    private func deleteAllConversations() {
        Task {
            await ChatHistoryManager.shared.deleteAllConversations()
        }
        Logger.log("All conversations deleted by user", log: Logger.general)
    }
}
