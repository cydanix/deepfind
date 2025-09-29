import Foundation

// MARK: - Data Models

/// Document chunk for Meilisearch indexing
public struct DocumentChunk: Codable {
    public let id: String
    public let content: String
    public let fileName: String
    public let filePath: String
    public let folderPath: String
    public let pageNumber: Int?
    public let chunkNumber: Int
    public let chunkSize: Int
    public let wordCount: Int
    public let createdAt: String
    public let fileType: String
    
    public init(
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


