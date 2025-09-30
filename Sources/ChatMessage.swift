import Foundation

// Chat message data model
struct ChatMessage: Identifiable, Equatable, Codable {
    let id: String
    let content: String
    let isUser: Bool
    let timestamp: Date
    
    init(id: String = UUID().uuidString, content: String, isUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
}
