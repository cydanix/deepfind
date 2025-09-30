import Foundation
import Combine
import CryptoKit

/// Handles indexing of selected folders for RAG search
@MainActor
class FolderIndexer: ObservableObject {
    @Published var isIndexing: Bool = false
    @Published var indexingProgress: Double = 0.0
    @Published var indexedFolderPath: String? = nil
    @Published var indexedFileCount: Int = 0
    @Published var lastIndexingDate: Date? = nil
    @Published var currentIndexName: String? = nil
    
    static let shared = FolderIndexer()
    
    private let meilisearchManager = MeilisearchManager.shared
    private let pdfParser = PdfParser.shared
    
    // Chunking parameters
    private let chunkSize = 1000 // characters
    private let overlapSize = 256 // characters (increased as requested)
    private let batchSize = 50 // Balanced batch size to avoid server overload
    private let maxRetries = 3 // Maximum retry attempts for failed batches
    
    private init() {}

    private func indexChunks(indexName: String, chunks: [DocumentChunk]) async throws {
        do {
            let _ = try await meilisearchManager.indexDocuments(indexUid: indexName, documents: chunks)
        } catch {
            Logger.log("Error indexing chunks: \(error.localizedDescription)", log: Logger.general)
            throw error
        }
    }

    private func calculateOverlapStart(document: PdfDocument, currentPageIndex: Int, currentPageOffset: Int, overlapSize: Int) -> (Int, Int) {
        var remainingOverlap = overlapSize
        var pageIdx = currentPageIndex
        var pageOff = currentPageOffset
        
        // Walk backwards through pages to find where overlap starts
        while remainingOverlap > 0 {
            if pageOff >= remainingOverlap {
                // Overlap fits within current page
                pageOff -= remainingOverlap
                remainingOverlap = 0
            } else {
                // Need to go to previous page
                remainingOverlap -= pageOff
                pageIdx -= 1
                
                if pageIdx < 0 {
                    // Hit beginning of document
                    return (0, 0)
                }
                
                // Skip empty pages when going backward
                while pageIdx >= 0 && document.page(at: pageIdx + 1)?.text.isEmpty ?? true {
                    pageIdx -= 1
                }
                
                if pageIdx < 0 {
                    return (0, 0)
                }
                
                pageOff = document.page(at: pageIdx + 1)?.text.count ?? 0
            }
        }
        
        return (pageIdx, pageOff)
    }

    /// Index pages using cross-page chunking with overlap
    /// - Parameters:
    ///   - document: PDF document to process
    ///   - indexName: Meilisearch index name
    /// - Returns: Array of document chunks ready for indexing
    private func indexPageList(document: PdfDocument, indexName: String) async throws {
        
        var chunks: [DocumentChunk] = []
        var chunkSeqNo = 0
        var pageIndex = 0
        var pageOffset = 0
        var chunk = ""
        var chunkStartPageIndex = 0
        var chunkStartPageOffset = 0

        while pageIndex < document.totalPages {
            let page = document.page(at: pageIndex + 1)
            
            // Skip empty pages
            if page == nil || page!.text.isEmpty {
                pageIndex += 1
                pageOffset = 0
                continue
            }
            let pageText = page!.text
            // Take characters from current page until we fill the chunk or reach end of page
            let availableInPage = pageText.count - pageOffset
            let neededForChunk = chunkSize - chunk.count
            
            let charsToTake = min(availableInPage, neededForChunk)
            
            let startIdx = pageText.index(pageText.startIndex, offsetBy: pageOffset)
            let endIdx = pageText.index(startIdx, offsetBy: charsToTake)
            chunk += String(pageText[startIdx..<endIdx])
            pageOffset += charsToTake
            
            // Move to next page if we've consumed all of current page
            if pageOffset >= pageText.count {
                pageIndex += 1
                pageOffset = 0
            }
            
            // If we have a complete chunk, index it
            if chunk.count >= chunkSize {
                chunks.append(DocumentChunk(id: UUID().uuidString, content: chunk, filePath: document.fileURL.path, pageNumber: pageIndex + 1, chunkNumber: chunkSeqNo))
                chunkSeqNo += 1
                
                if chunks.count >= 64 {
                    try await indexChunks(indexName: indexName, chunks: chunks)
                    chunks = []
                }

                // Prepare next chunk with overlap
                if overlapSize > 0 && chunk.count >= overlapSize {
                    // Keep the last overlapSize characters for the next chunk
                    let overlapStartIdx = chunk.index(chunk.endIndex, offsetBy: -overlapSize)
                    let overlap = String(chunk[overlapStartIdx...])
                    chunk = overlap
                    
                    // Calculate where this overlap starts in the page structure
                    let (startPageIdx, startPageOff) = calculateOverlapStart(
                        document: document,
                        currentPageIndex: pageIndex,
                        currentPageOffset: pageOffset,
                        overlapSize: overlapSize
                    )
                    chunkStartPageIndex = startPageIdx
                    chunkStartPageOffset = startPageOff
                } else {
                    // No overlap or chunk too small for overlap
                    chunk = ""
                    chunkStartPageIndex = pageIndex
                    chunkStartPageOffset = pageOffset
                }
            }
        }
        
        // Handle final chunk if there's remaining content
        if !chunk.isEmpty {
            let documentChunk = DocumentChunk(id: UUID().uuidString, content: chunk, filePath: document.fileURL.path, pageNumber: chunkStartPageIndex + 1, chunkNumber: chunkSeqNo)
            chunks.append(documentChunk)
            try await indexChunks(indexName: indexName, chunks: chunks)
        }
        
    }

    private func indexFile(filePath: String, indexName: String) async throws {
        do {
            Logger.log("Processing PDF: \(filePath)", log: Logger.general)

            let document = try await pdfParser.parsePdf(at: URL(fileURLWithPath: filePath))            
            try await indexPageList(document: document, indexName: indexName)

        } catch {
            Logger.log("Error indexing file: \(filePath) - \(error.localizedDescription)", log: Logger.general)
            throw error
        }
    }

    /// Index the contents of a selected folder
    /// - Parameters:
    ///   - folderPath: Path to the folder to index
    ///   - indexId: Optional custom index ID (defaults to UUID)
    ///   - onProgress: Optional progress callback
    /// - Throws: IndexingError if indexing fails
    func indexFolder(at folderPath: String, indexId: String? = nil, onProgress: ((Double) async -> Void)? = nil) async throws {
        Logger.log("Starting to index folder: \(folderPath)", log: Logger.general)
        
        isIndexing = true
        indexingProgress = 0.0
        
        defer {
            isIndexing = false
        }
        
        // Start Meilisearch if not running
        guard await meilisearchManager.start() else {
            throw IndexingError.meilisearchError("Failed to start Meilisearch server")
        }
        
        // Use provided index ID or create new one
        let indexName = indexId ?? createIndexName(for: folderPath)
        currentIndexName = indexName
        
        Logger.log("Using index name: \(indexName)", log: Logger.general)
        
        // Create or recreate the index
        do {
            let _ = try await meilisearchManager.createIndex(uid: indexName, primaryKey: "id")
            Logger.log("Created new index: \(indexName)", log: Logger.general)
        } catch {
            // Index might already exist, try to delete and recreate
            do {
                let _ = try await meilisearchManager.deleteIndex(uid: indexName)
                let _ = try await meilisearchManager.createIndex(uid: indexName, primaryKey: "id")
                Logger.log("Recreated index: \(indexName)", log: Logger.general)
            } catch {
                throw IndexingError.meilisearchError("Failed to create index: \(error.localizedDescription)")
            }
        }
        
        // Scan for PDF files
        let pdfFiles = try await scanPdfFiles(at: folderPath)
        let totalFiles = pdfFiles.count
        
        guard totalFiles > 0 else {
            Logger.log("No PDF files found in folder", log: Logger.general)
            throw IndexingError.indexingFailed("No PDF files found in the selected folder")
        }
        
        Logger.log("Found \(totalFiles) PDF files to process", log: Logger.general)

        var processedFiles = 0        
        // Process each PDF file
        for (fileIndex, pdfPath) in pdfFiles.enumerated() {
            try await indexFile(filePath: pdfPath, indexName: indexName)
            // Update progress (more granular progress tracking)
            let progress = Double(fileIndex + 1) / Double(totalFiles)
            indexingProgress = progress
            await onProgress?(progress)
            processedFiles += 1
        }

        // Update state
        indexedFolderPath = folderPath
        indexedFileCount = processedFiles
        lastIndexingDate = Date()
        
        Logger.log("Finished indexing \(processedFiles) PDF files from: \(folderPath)", log: Logger.general)
    }
    
    /// Check if a folder is currently indexed
    /// - Parameter folderPath: Path to check
    /// - Returns: True if the folder is indexed
    func isFolderIndexed(_ folderPath: String) -> Bool {
        return indexedFolderPath == folderPath
    }
    
    /// Clear the current index
    func clearIndex() async {
        Logger.log("Clearing current index", log: Logger.general)
        
        // Delete Meilisearch index if it exists
        if let indexName = currentIndexName {
            do {
                let _ = try await meilisearchManager.deleteIndex(uid: indexName)
                Logger.log("Deleted Meilisearch index: \(indexName)", log: Logger.general)
            } catch {
                Logger.log("Failed to delete Meilisearch index: \(error.localizedDescription)", log: Logger.general)
            }
        }
        
        indexedFolderPath = nil
        indexedFileCount = 0
        lastIndexingDate = nil
        indexingProgress = 0.0
        currentIndexName = nil
    }
    
    /// Get the current index name for the indexed folder
    /// - Returns: Current Meilisearch index name or nil
    func getCurrentIndexName() -> String? {
        return currentIndexName
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
    
    /// Create index name by hashing the folder path
    /// - Parameter folderPath: Full path to the folder
    /// - Returns: Hashed index name
    private func createIndexName(for folderPath: String) -> String {
        return UUID().uuidString
    }

    /// Scan folder recursively for PDF files only
    /// - Parameter path: Path to scan
    /// - Returns: Array of PDF file paths
    private func scanPdfFiles(at path: String) async throws -> [String] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: path) else {
            throw IndexingError.invalidPath(path)
        }
        
        var pdfFiles: [String] = []
        
        while let file = enumerator.nextObject() as? String {
            let fileURL = URL(fileURLWithPath: path).appendingPathComponent(file)
            
            // Only process PDF files
            if PdfParser.isPdfFile(fileURL) {
                pdfFiles.append(fileURL.path)
            }
        }
        
        return pdfFiles
    }
   
}

// MARK: - Error Types

enum IndexingError: LocalizedError {
    case invalidPath(String)
    case fileNotReadable(String)
    case indexingFailed(String)
    case meilisearchError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidPath(let path):
            return "Invalid folder path: \(path)"
        case .fileNotReadable(let file):
            return "Cannot read file: \(file)"
        case .indexingFailed(let reason):
            return "Indexing failed: \(reason)"
        case .meilisearchError(let error):
            return "Meilisearch error: \(error)"
        }
    }
}
