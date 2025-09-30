import Foundation

/// Represents a searchable index created from a folder
struct Index: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let folderPath: String
    let fileCount: Int
    let createdAt: Date
    let lastIndexedAt: Date
    
    init(id: String = UUID().uuidString, name: String, folderPath: String, fileCount: Int, createdAt: Date = Date(), lastIndexedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.folderPath = folderPath
        self.fileCount = fileCount
        self.createdAt = createdAt
        self.lastIndexedAt = lastIndexedAt
    }
    
    var folderName: String {
        URL(fileURLWithPath: folderPath).lastPathComponent
    }
    
    var displayName: String {
        name.isEmpty ? folderName : name
    }
}
