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
    private let overlapSize = 200 // characters
    private let batchSize = 50 // Balanced batch size to avoid server overload
    private let maxRetries = 3 // Maximum retry attempts for failed batches
    
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
        
        // Start Meilisearch if not running
        guard await meilisearchManager.start() else {
            throw IndexingError.meilisearchError("Failed to start Meilisearch server")
        }
        
        // Create index name from folder path hash
        let indexName = createIndexName(for: folderPath)
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
        var totalChunks = 0
        
        // Process each PDF file
        for (fileIndex, pdfPath) in pdfFiles.enumerated() {
            do {
                Logger.log("Processing PDF: \(URL(fileURLWithPath: pdfPath).lastPathComponent)", log: Logger.general)
                
                // Parse PDF
                let document = try await pdfParser.parsePdf(at: URL(fileURLWithPath: pdfPath))
                
                // Create chunks from PDF pages
                let chunks = createChunksFromPdf(document: document, folderPath: folderPath)
                
                // Index chunks in smaller batches with retry logic and better pacing
                Logger.log("Indexing \(chunks.count) chunks from \(document.fileName) in batches of \(batchSize)", log: Logger.general)
                
                for batchStart in stride(from: 0, to: chunks.count, by: batchSize) {
                    let batchEnd = min(batchStart + batchSize, chunks.count)
                    let batch = Array(chunks[batchStart..<batchEnd])
                    let batchNumber = (batchStart / batchSize) + 1
                    let totalBatches = Int(ceil(Double(chunks.count) / Double(batchSize)))
                    
                    // Retry logic for failed batches
                    var retryCount = 0
                    var batchSuccess = false
                    
                    while retryCount <= maxRetries && !batchSuccess {
                        let attemptNumber = retryCount + 1
                        let retryText = retryCount > 0 ? " (attempt \(attemptNumber)/\(maxRetries + 1))" : ""
                        
                        Logger.log("Indexing batch \(batchNumber)/\(totalBatches) (\(batch.count) chunks) for \(document.fileName)\(retryText)", log: Logger.general)
                        
                        do {
                            // Log first few document IDs for debugging
                            let sampleIds = batch.prefix(3).map { $0.id }.joined(separator: ", ")
                            Logger.log("Attempting to index batch with sample IDs: \(sampleIds)...", log: Logger.general)
                            
                            let response = try await meilisearchManager.indexDocuments(indexUid: indexName, documents: batch)
                            totalChunks += batch.count
                            batchSuccess = true
                            Logger.log("Successfully indexed batch \(batchNumber)/\(totalBatches) for \(document.fileName)\(retryText)", log: Logger.general)
                            
                            // Log Meilisearch response for debugging
                            if let responseString = String(data: response, encoding: .utf8) {
                                Logger.log("Meilisearch response: \(responseString)", log: Logger.general)
                            }
                            
                        } catch let error as MeilisearchError {
                            retryCount += 1
                            Logger.log("Failed to index batch \(batchNumber)/\(totalBatches) for \(document.fileName)\(retryText): Meilisearch error - \(error.localizedDescription)", log: Logger.general)
                            
                            // Log specific error details for debugging
                            switch error {
                            case .httpError(let status, let message):
                                Logger.log("HTTP \(status): \(message)", log: Logger.general)
                            case .networkError(let networkError):
                                Logger.log("Network error: \(networkError.localizedDescription)", log: Logger.general)
                                // Check if this is a timeout in the network error
                                if (networkError as NSError).code == NSURLErrorTimedOut {
                                    Logger.log("Timeout detected in Meilisearch request - server overwhelmed with batch size \(batchSize). Consider reducing batch size further.", log: Logger.general)
                                }
                            default:
                                Logger.log("Other Meilisearch error: \(error)", log: Logger.general)
                            }
                        } catch {
                            retryCount += 1
                            Logger.log("Failed to index batch \(batchNumber)/\(totalBatches) for \(document.fileName)\(retryText): General error - \(error.localizedDescription)", log: Logger.general)
                            
                            // Check for timeout errors and log suggestion
                            if (error as NSError).code == NSURLErrorTimedOut {
                                Logger.log("Timeout detected - server overwhelmed with batch size \(batchSize). Consider reducing batch size further in code.", log: Logger.general)
                            }
                            
                        if retryCount <= maxRetries {
                            // Reduced retry delay for faster recovery
                            let retryDelay = TimeInterval(Double(retryCount) * 0.5) // 0.5s, 1s, 1.5s
                            Logger.log("Retrying in \(retryDelay) seconds...", log: Logger.general)
                            try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                        }
                        }
                    }
                    
                    if !batchSuccess {
                        Logger.log("Failed to index batch \(batchNumber)/\(totalBatches) after \(maxRetries + 1) attempts. Continuing with next batch.", log: Logger.general)
                        
                        // Only delay after failures to avoid overwhelming the server
                        let failureDelay: UInt64 = 500_000_000 // 0.5 seconds after failure
                        try await Task.sleep(nanoseconds: failureDelay)
                    } else {
                        // Small delay after successful batches to prevent server overload
                        let successDelay: UInt64 = 50_000_000 // 50ms after success
                        try await Task.sleep(nanoseconds: successDelay)
                    }
                    
                    // Only pause every 200 batches for health check
                    if batchNumber % 200 == 0 && batchNumber < totalBatches {
                        Logger.log("Performing health check after batch \(batchNumber)", log: Logger.general)
                        
                        // Check Meilisearch health during long processing
                        let isHealthy = await meilisearchManager.healthCheck()
                        if !isHealthy {
                            Logger.log("Meilisearch health check failed after batch \(batchNumber). Waiting for recovery...", log: Logger.general)
                            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds additional wait
                        }
                        // No additional delay if health check passes
                    }
                }
                
                processedFiles += 1
                Logger.log("Processed \(chunks.count) chunks from \(document.fileName)", log: Logger.general)
                
            } catch {
                Logger.log("Failed to process PDF \(pdfPath): \(error.localizedDescription)", log: Logger.general)
                // Continue with other files
            }
            
            // Update progress (more granular progress tracking)
            let baseProgress = Double(fileIndex) / Double(totalFiles)
            let fileProgress = Double(processedFiles > fileIndex ? 1.0 : 0.0) / Double(totalFiles)
            indexingProgress = baseProgress + fileProgress
        }
        
        // Update state
        indexedFolderPath = folderPath
        indexedFileCount = processedFiles
        lastIndexingDate = Date()
        
        Logger.log("Finished indexing \(processedFiles) PDF files (\(totalChunks) total chunks) from: \(folderPath)", log: Logger.general)
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
        let data = Data(folderPath.utf8)
        let hash = SHA256.hash(data: data)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        return "kb_\(String(hashString.prefix(16)))" // Use first 16 chars of hash with prefix
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
    
    /// Create chunks from PDF document with overlap
    /// - Parameters:
    ///   - document: Parsed PDF document
    ///   - folderPath: Folder path for metadata
    /// - Returns: Array of document chunks ready for indexing
    private func createChunksFromPdf(document: PdfDocument, folderPath: String) -> [MeilisearchDocumentChunk] {
        var chunks: [MeilisearchDocumentChunk] = []
        
        // Process each page
        for pageNumber in 1...document.totalPages {
            guard let page = document.page(at: pageNumber) else { continue }
            
            // Skip pages with no meaningful content
            guard page.hasContent else { continue }
            
            let pageText = page.cleanedText
            
            // Create chunks from page text
            let pageChunks = createTextChunks(
                text: pageText,
                fileName: document.fileName,
                filePath: document.fileURL.path,
                folderPath: folderPath,
                pageNumber: pageNumber
            )
            
            chunks.append(contentsOf: pageChunks)
        }
        
        return chunks
    }
    
    /// Create overlapping text chunks from a text string
    /// - Parameters:
    ///   - text: Text to chunk
    ///   - fileName: Name of source file
    ///   - filePath: Path to source file
    ///   - folderPath: Folder path for metadata
    ///   - pageNumber: Page number for PDF context
    /// - Returns: Array of text chunks
    private func createTextChunks(
        text: String,
        fileName: String,
        filePath: String,
        folderPath: String,
        pageNumber: Int
    ) -> [MeilisearchDocumentChunk] {
        guard !text.isEmpty else { return [] }
        
        var chunks: [MeilisearchDocumentChunk] = []
        var startIndex = text.startIndex
        var chunkNumber = 1
        
        while startIndex < text.endIndex {
            let remainingText = String(text[startIndex...])
            let currentChunkSize = min(chunkSize, remainingText.count)
            let endIndex = text.index(startIndex, offsetBy: currentChunkSize, limitedBy: text.endIndex) ?? text.endIndex
            
            let chunkText = String(text[startIndex..<endIndex])
            let wordCount = PdfParser.countWords(in: chunkText)
            
            // Only create chunks with meaningful content
            if wordCount > 10 {
                // Create safe document ID by sanitizing filename and using full UUID
                let safeFileName = sanitizeFileName(fileName)
                let chunkId = "\(safeFileName)_p\(pageNumber)_c\(chunkNumber)_\(UUID().uuidString)"
                
                let cleanedContent = chunkText.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Validate document before creating
                guard !cleanedContent.isEmpty && !chunkId.isEmpty else {
                    Logger.log("Skipping invalid chunk: empty content or ID", log: Logger.general)
                    chunkNumber += 1
                    continue
                }
                
                let chunk = MeilisearchDocumentChunk(
                    id: chunkId,
                    content: cleanedContent,
                    fileName: fileName,
                    filePath: filePath,
                    folderPath: folderPath,
                    pageNumber: pageNumber,
                    chunkNumber: chunkNumber,
                    chunkSize: chunkText.count,
                    wordCount: wordCount
                )
                
                // Additional validation before adding to chunks
                if validateChunk(chunk) {
                    chunks.append(chunk)
                } else {
                    Logger.log("Skipping invalid chunk for \(fileName) page \(pageNumber) chunk \(chunkNumber)", log: Logger.general)
                }
            }
            
            // Move start index, accounting for overlap
            let nextStartOffset = max(currentChunkSize - overlapSize, 1)
            startIndex = text.index(startIndex, offsetBy: nextStartOffset, limitedBy: text.endIndex) ?? text.endIndex
            chunkNumber += 1
        }
        
        return chunks
    }
    
    /// Sanitize filename for safe use in document IDs
    /// - Parameter fileName: Original filename
    /// - Returns: Sanitized filename safe for Meilisearch IDs
    private func sanitizeFileName(_ fileName: String) -> String {
        // Remove file extension and replace problematic characters
        let nameWithoutExtension = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        
        // Replace problematic characters with underscores
        let sanitized = nameWithoutExtension
            .replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        
        // Ensure it's not empty and not too long
        let maxLength = 50
        if sanitized.isEmpty {
            return "doc"
        } else if sanitized.count > maxLength {
            return String(sanitized.prefix(maxLength))
        } else {
            return sanitized
        }
    }
    
    /// Validate a document chunk before indexing
    /// - Parameter chunk: Document chunk to validate
    /// - Returns: True if chunk is valid for Meilisearch
    private func validateChunk(_ chunk: MeilisearchDocumentChunk) -> Bool {
        // Check required fields are present and non-empty
        guard !chunk.id.isEmpty,
              !chunk.content.isEmpty,
              !chunk.fileName.isEmpty,
              !chunk.filePath.isEmpty,
              !chunk.folderPath.isEmpty,
              chunk.wordCount > 0,
              chunk.chunkSize > 0,
              chunk.chunkNumber > 0 else {
            Logger.log("Chunk validation failed: missing or empty required fields", log: Logger.general)
            return false
        }
        
        // Check ID length (Meilisearch has limits)
        if chunk.id.count > 512 {
            Logger.log("Chunk validation failed: ID too long (\(chunk.id.count) characters)", log: Logger.general)
            return false
        }
        
        // Check content size (reasonable limits)
        if chunk.content.count > 50000 { // 50KB limit per chunk
            Logger.log("Chunk validation failed: content too large (\(chunk.content.count) characters)", log: Logger.general)
            return false
        }
        
        // Check for potentially problematic content
        if chunk.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Logger.log("Chunk validation failed: content is only whitespace", log: Logger.general)
            return false
        }
        
        return true
    }
}

// MARK: - Data Models

/// Document chunk for Meilisearch indexing
struct MeilisearchDocumentChunk: Codable {
    let id: String
    let content: String
    let fileName: String
    let filePath: String
    let folderPath: String
    let pageNumber: Int?
    let chunkNumber: Int
    let chunkSize: Int
    let wordCount: Int
    let createdAt: String
    let fileType: String
    
    init(
        id: String,
        content: String,
        fileName: String,
        filePath: String,
        folderPath: String,
        pageNumber: Int? = nil,
        chunkNumber: Int,
        chunkSize: Int,
        wordCount: Int,
        fileType: String = "pdf"
    ) {
        self.id = id
        self.content = content
        self.fileName = fileName
        self.filePath = filePath
        self.folderPath = folderPath
        self.pageNumber = pageNumber
        self.chunkNumber = chunkNumber
        self.chunkSize = chunkSize
        self.wordCount = wordCount
        self.createdAt = ISO8601DateFormatter().string(from: Date())
        self.fileType = fileType
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
