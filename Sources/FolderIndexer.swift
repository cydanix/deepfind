import Foundation
import Combine

/// Handles indexing of selected folders for RAG search
@MainActor
class FolderIndexer: ObservableObject {
    @Published var isIndexing: Bool = false
    @Published var indexingProgress: Double = 0.0
    @Published var indexedFolderPath: String? = nil
    @Published var indexedFileCount: Int = 0
    @Published var lastIndexingDate: Date? = nil
    
    static let shared = FolderIndexer()
    
    private init() {}
    
    /// Index the contents of a selected folder
    /// - Parameter folderPath: Path to the folder to index
    /// - Throws: IndexingError if indexing fails
    func indexFolder(at folderPath: String) async throws {
        Logger.log("Starting to index folder: \(folderPath)", log: Logger.general)
        
        isIndexing = true
        indexingProgress = 0.0
        
        defer {
            isIndexing = false
        }
        
        // TODO: Implement actual folder indexing logic
        // This should:
        // 1. Recursively scan the folder for supported file types
        // 2. Extract text content from files (txt, md, pdf, docx, etc.)
        // 3. Create embeddings for text chunks
        // 4. Store embeddings in a local vector database
        // 5. Create metadata index for quick retrieval
        
        // Dummy implementation for now
        let files = try await scanFolder(at: folderPath)
        let totalFiles = files.count
        
        for (index, file) in files.enumerated() {
            Logger.log("Processing file: \(file)", log: Logger.general)
            
            // Simulate processing time
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            
            // Update progress
            indexingProgress = Double(index + 1) / Double(totalFiles)
        }
        
        // Update state
        indexedFolderPath = folderPath
        indexedFileCount = totalFiles
        lastIndexingDate = Date()
        
        Logger.log("Finished indexing \(totalFiles) files from: \(folderPath)", log: Logger.general)
    }
    
    /// Check if a folder is currently indexed
    /// - Parameter folderPath: Path to check
    /// - Returns: True if the folder is indexed
    func isFolderIndexed(_ folderPath: String) -> Bool {
        return indexedFolderPath == folderPath
    }
    
    /// Clear the current index
    func clearIndex() {
        Logger.log("Clearing current index", log: Logger.general)
        indexedFolderPath = nil
        indexedFileCount = 0
        lastIndexingDate = nil
        indexingProgress = 0.0
    }
    
    /// Get indexing status summary
    func getIndexingSummary() -> String {
        guard let path = indexedFolderPath else {
            return "No folder indexed"
        }
        
        let folderName = URL(fileURLWithPath: path).lastPathComponent
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        let dateString = lastIndexingDate.map { dateFormatter.string(from: $0) } ?? "Unknown"
        
        return "\(folderName) (\(indexedFileCount) files) - \(dateString)"
    }
    
    // MARK: - Private Methods
    
    private func scanFolder(at path: String) async throws -> [String] {
        // TODO: Implement actual folder scanning
        // This should recursively find all supported file types
        
        // Dummy implementation
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: path) else {
            throw IndexingError.invalidPath(path)
        }
        
        var files: [String] = []
        let supportedExtensions = ["txt", "md", "pdf", "docx", "rtf", "html", "swift", "py", "js", "ts"]
        
        while let file = enumerator.nextObject() as? String {
            let fileURL = URL(fileURLWithPath: path).appendingPathComponent(file)
            let fileExtension = fileURL.pathExtension.lowercased()
            
            if supportedExtensions.contains(fileExtension) {
                files.append(fileURL.path)
            }
        }
        
        return files
    }
}

// MARK: - Error Types

enum IndexingError: LocalizedError {
    case invalidPath(String)
    case fileNotReadable(String)
    case indexingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidPath(let path):
            return "Invalid folder path: \(path)"
        case .fileNotReadable(let file):
            return "Cannot read file: \(file)"
        case .indexingFailed(let reason):
            return "Indexing failed: \(reason)"
        }
    }
}
