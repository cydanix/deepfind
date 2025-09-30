import Foundation
import Combine

/// Manages multiple searchable indexes
@MainActor
class IndexManager: ObservableObject {
    @Published var indexes: [Index] = []
    @Published var selectedIndex: Index? = nil
    @Published var isIndexing: Bool = false
    @Published var indexingProgress: Double = 0.0
    
    static let shared = IndexManager()
    
    private let folderIndexer = FolderIndexer.shared
    private let meilisearchManager = MeilisearchManager.shared
    private let storageKey = "saved_indexes"
    
    private init() {
        loadIndexes()
    }
    
    // MARK: - Index Management
    
    /// Create a new index from a folder
    func createIndex(name: String, folderPath: String) async throws {
        Logger.log("Creating new index: \(name) for folder: \(folderPath)", log: Logger.general)
        
        isIndexing = true
        indexingProgress = 0.0
        
        defer {
            isIndexing = false
        }
        
        // Create unique index ID
        let indexId = UUID().uuidString
        
        // Use FolderIndexer to do the actual indexing work
        try await folderIndexer.indexFolder(at: folderPath, indexId: indexId, onProgress: { progress in
            await MainActor.run {
                self.indexingProgress = progress
            }
        })
        
        // Create and save the index
        let newIndex = Index(
            id: indexId,
            name: name,
            folderPath: folderPath,
            fileCount: folderIndexer.indexedFileCount
        )
        
        indexes.append(newIndex)
        saveIndexes()
        
        Logger.log("Index created successfully: \(name)", log: Logger.general)
    }
    
    /// Delete an index
    func deleteIndex(_ index: Index) async {
        Logger.log("Deleting index: \(index.displayName)", log: Logger.general)
        
        // Delete from Meilisearch
        do {
            let _ = try await meilisearchManager.deleteIndex(uid: index.id)
            Logger.log("Deleted Meilisearch index: \(index.id)", log: Logger.general)
        } catch {
            Logger.log("Failed to delete Meilisearch index: \(error.localizedDescription)", log: Logger.general)
        }
        
        // Delete associated conversations
        ChatHistoryManager.shared.deleteConversations(for: index.id)
        
        // Remove from local list
        indexes.removeAll { $0.id == index.id }
        
        // Clear selection if deleted index was selected
        if selectedIndex?.id == index.id {
            selectedIndex = nil
        }
        
        saveIndexes()
    }
    
    /// Reindex an existing index
    func reindexIndex(_ index: Index) async throws {
        Logger.log("Reindexing: \(index.displayName)", log: Logger.general)
        
        isIndexing = true
        indexingProgress = 0.0
        
        defer {
            isIndexing = false
        }
        
        // Delete old index from Meilisearch
        do {
            let _ = try await meilisearchManager.deleteIndex(uid: index.id)
        } catch {
            Logger.log("Failed to delete old index during reindex: \(error.localizedDescription)", log: Logger.general)
        }
        
        // Reindex the folder
        try await folderIndexer.indexFolder(at: index.folderPath, indexId: index.id, onProgress: { progress in
            await MainActor.run {
                self.indexingProgress = progress
            }
        })
        
        // Update index metadata
        if let indexIdx = indexes.firstIndex(where: { $0.id == index.id }) {
            let updatedIndex = Index(
                id: index.id,
                name: index.name,
                folderPath: index.folderPath,
                fileCount: folderIndexer.indexedFileCount,
                createdAt: index.createdAt,
                lastIndexedAt: Date()
            )
            indexes[indexIdx] = updatedIndex
            
            // Update selected index if it was the one being reindexed
            if selectedIndex?.id == index.id {
                selectedIndex = updatedIndex
            }
            
            saveIndexes()
        }
        
        Logger.log("Reindexing completed: \(index.displayName)", log: Logger.general)
    }
    
    /// Select an index for chatting
    func selectIndex(_ index: Index) {
        Logger.log("Selected index: \(index.displayName)", log: Logger.general)
        selectedIndex = index
    }
    
    /// Deselect current index
    func deselectIndex() {
        selectedIndex = nil
    }
    
    // MARK: - Persistence
    
    private func saveIndexes() {
        do {
            let data = try JSONEncoder().encode(indexes)
            UserDefaults.standard.set(data, forKey: storageKey)
            Logger.log("Saved \(indexes.count) indexes", log: Logger.general)
        } catch {
            Logger.log("Failed to save indexes: \(error.localizedDescription)", log: Logger.general, type: .error)
        }
    }
    
    private func loadIndexes() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            Logger.log("No saved indexes found", log: Logger.general)
            return
        }
        
        do {
            indexes = try JSONDecoder().decode([Index].self, from: data)
            Logger.log("Loaded \(indexes.count) indexes", log: Logger.general)
        } catch {
            Logger.log("Failed to load indexes: \(error.localizedDescription)", log: Logger.general, type: .error)
        }
    }
}
