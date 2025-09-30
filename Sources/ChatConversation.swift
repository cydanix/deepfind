import Foundation

/// Represents a chat conversation with an index
struct ChatConversation: Identifiable, Codable, Equatable {
    let id: String
    let indexId: String
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date
    var title: String
    
    init(id: String = UUID().uuidString, indexId: String, messages: [ChatMessage] = [], title: String = "New Chat") {
        self.id = id
        self.indexId = indexId
        self.messages = messages
        self.createdAt = Date()
        self.updatedAt = Date()
        self.title = title
    }
    
    /// Get a display title based on the first user message or default
    var displayTitle: String {
        if !title.isEmpty && title != "New Chat" {
            return title
        }
        
        // Use first user message as title (truncated)
        if let firstUserMessage = messages.first(where: { $0.isUser }) {
            let maxLength = 40
            if firstUserMessage.content.count > maxLength {
                return String(firstUserMessage.content.prefix(maxLength)) + "..."
            }
            return firstUserMessage.content
        }
        
        return "New Chat"
    }
    
    /// Number of messages in the conversation
    var messageCount: Int {
        return messages.count
    }
    
    /// Add a message to the conversation
    mutating func addMessage(_ message: ChatMessage) {
        messages.append(message)
        updatedAt = Date()
    }
    
    /// Update the title
    mutating func updateTitle(_ newTitle: String) {
        title = newTitle
        updatedAt = Date()
    }
}
