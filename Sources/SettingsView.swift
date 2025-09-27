import SwiftUI
import Cocoa

struct SettingsView: View {
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var folderIndexer = FolderIndexer.shared
    
    // Reset confirmation state
    @State private var showingResetConfirmation = false
    
    // Delete models confirmation state
    @State private var showingDeleteModelsConfirmation = false
    
    var body: some View {
        TabView {
            // Indexing Settings Tab
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Document Processing")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Chunk Size:")
                                    Spacer()
                                    Text("\(settings.maxChunkSize) characters")
                                        .foregroundColor(.gray)
                                }
                                
                                Slider(value: Binding(
                                    get: { Double(settings.maxChunkSize) },
                                    set: { settings.updateChunkSize(Int($0)) }
                                ), in: 100...5000, step: 100)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Chunk Overlap:")
                                    Spacer()
                                    Text("\(settings.chunkOverlap) characters")
                                        .foregroundColor(.gray)
                                }
                                
                                Slider(value: Binding(
                                    get: { Double(settings.chunkOverlap) },
                                    set: { newValue in settings.chunkOverlap = Int(newValue) }
                                ), in: 0...500, step: 25)
                            }
                            
                            Toggle("Auto-refresh index when folder changes", isOn: Binding(
                                get: { settings.autoRefreshIndex },
                                set: { newValue in settings.autoRefreshIndex = newValue }
                            ))
                            
                            Text("Configure how documents are processed for indexing. Smaller chunks provide more precise search results but may miss broader context.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                    }
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Search Settings")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Max Search Results:")
                                    Spacer()
                                    Text("\(settings.maxSearchResults)")
                                        .foregroundColor(.gray)
                                }
                                
                                Slider(value: Binding(
                                    get: { Double(settings.maxSearchResults) },
                                    set: { newValue in settings.maxSearchResults = Int(newValue) }
                                ), in: 1...20, step: 1)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Similarity Threshold:")
                                    Spacer()
                                    Text("\(String(format: "%.2f", settings.similarityThreshold))")
                                        .foregroundColor(.gray)
                                }
                                
                                Slider(value: Binding(
                                    get: { settings.similarityThreshold },
                                    set: { settings.updateSimilarityThreshold($0) }
                                ), in: 0.0...1.0, step: 0.05)
                            }
                            
                            Toggle("Show search suggestions", isOn: Binding(
                                get: { settings.showSearchSuggestions },
                                set: { newValue in settings.showSearchSuggestions = newValue }
                            ))
                            
                            Toggle("Enable contextual search", isOn: Binding(
                                get: { settings.enableContextualSearch },
                                set: { newValue in settings.enableContextualSearch = newValue }
                            ))
                            
                            Text("Control search behavior and result quality. Higher similarity threshold means more precise matches.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                    }
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("LLM Settings")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Max Context Length:")
                                    Spacer()
                                    Text("\(settings.maxContextLength) tokens")
                                        .foregroundColor(.gray)
                                }
                                
                                Slider(value: Binding(
                                    get: { Double(settings.maxContextLength) },
                                    set: { newValue in settings.maxContextLength = Int(newValue) }
                                ), in: 1000...8000, step: 500)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Temperature:")
                                    Spacer()
                                    Text("\(String(format: "%.2f", settings.temperature))")
                                        .foregroundColor(.gray)
                                }
                                
                                Slider(value: Binding(
                                    get: { settings.temperature },
                                    set: { settings.updateTemperature($0) }
                                ), in: 0.0...2.0, step: 0.1)
                            }
                            
                            Text("Control how the LLM processes your questions. Higher temperature produces more creative but potentially less accurate responses.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                    }
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Current Index Status")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            if let _ = folderIndexer.indexedFolderPath {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(folderIndexer.getIndexingSummary())
                                        .font(.body)
                                        .foregroundColor(.white)
                                    
                                    HStack {
                                        Button("Clear Index") {
                                            folderIndexer.clearIndex()
                                        }
                                        .buttonStyle(.bordered)
                                        .foregroundColor(.red)
                                        
                                        Spacer()
                                    }
                                }
                            } else {
                                Text("No folder currently indexed")
                                    .font(.body)
                                    .foregroundColor(.gray)
                            }
                            
                            Text("View and manage your current document index.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                    }
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
                .padding()
            }
            .background(Color.black)
            .tabItem {
                Label("Indexing", systemImage: "folder")
            }
            
            // Model Management Tab
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Supported File Types")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                                ForEach(settings.getSupportedFileTypes(), id: \.self) { fileType in
                                    Text(".\(fileType)")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.3))
                                        .cornerRadius(4)
                                }
                            }
                            
                            Text("These file types can be indexed and searched. More file types may be added in future updates.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                    }
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Storage Management")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Delete all downloaded AI models and indexes from your system. This will free up disk space but you'll need to re-download models and re-index folders when needed.")
                                .font(.body)
                                .foregroundColor(.gray)
                            
                            HStack {
                                Button("Delete All Models") {
                                    showingDeleteModelsConfirmation = true
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
                .padding()
            }
            .background(Color.black)
            .tabItem {
                Label("Management", systemImage: "gear")
            }
        }
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
            Button("Delete All", role: .destructive) {
                deleteAllModels()
            }
        } message: {
            Text("Are you sure you want to delete all downloaded AI models and indexes? This will free up disk space but you'll need to re-download models and re-index folders when they're needed again. This action cannot be undone.")
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Reset Settings
    
    private func resetSettings() {
        settings.resetToDefaults()
        folderIndexer.clearIndex()
        Logger.log("Settings reset to defaults", log: Logger.general)
    }
    
    // MARK: - Model Management
    
    private func deleteAllModels() {
        ModelStorage.shared.deleteAllModels()
        folderIndexer.clearIndex()
        Logger.log("All models and indexes deleted by user", log: Logger.general)
    }
}
