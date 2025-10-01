import Foundation

// MARK: - Data Models

/// Document chunk for Meilisearch indexing
public struct DocumentChunk: Codable {
    public let id: String
    public let content: String
    public let filePath: String
    public let pageNumber: Int
    public let chunkNumber: Int

    public init(
        id: String,
        content: String,
        filePath: String,
        pageNumber: Int,
        chunkNumber: Int
    ) {
        self.id = id
        self.content = content
        self.filePath = filePath
        self.pageNumber = pageNumber
        self.chunkNumber = chunkNumber
    }
}


