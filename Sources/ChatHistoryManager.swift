import Foundation
import Combine

/// Manages chat conversation history
@MainActor
class ChatHistoryManager: ObservableObject {
    @Published var conversations: [ChatConversation] = []
    @Published var selectedConversation: ChatConversation? = nil
    
    static let shared = ChatHistoryManager()
    
    private let storageKey = "chat_conversations"
    private let maxConversations = 100 // Keep last 100 conversations
    
    private init() {
        loadConversations()
    }
    
    // MARK: - Conversation Management
    
    /// Create a new conversation for an index
    func createConversation(for indexId: String) -> ChatConversation {
        let conversation = ChatConversation(indexId: indexId)
        conversations.insert(conversation, at: 0)
        saveConversations()
        return conversation
    }
    
    /// Update an existing conversation
    func updateConversation(_ conversation: ChatConversation) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
            
            // Move to top if it was updated
            if index != 0 {
                let conv = conversations.remove(at: index)
                conversations.insert(conv, at: 0)
            }
            
            // Update selected conversation if it's the same one
            if selectedConversation?.id == conversation.id {
                selectedConversation = conversation
            }
            
            saveConversations()
        }
    }
    
    /// Add a message to a conversation
    func addMessage(to conversationId: String, message: ChatMessage) {
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            var conversation = conversations[index]
            conversation.addMessage(message)
            updateConversation(conversation)
        }
    }
    
    /// Delete a conversation
    func deleteConversation(_ conversation: ChatConversation) {
        conversations.removeAll { $0.id == conversation.id }
        
        // Clear selection if deleted conversation was selected
        if selectedConversation?.id == conversation.id {
            selectedConversation = nil
        }
        
        saveConversations()
    }
    
    /// Delete all conversations for a specific index
    func deleteConversations(for indexId: String) {
        conversations.removeAll { $0.indexId == indexId }
        
        // Clear selection if it was for this index
        if selectedConversation?.indexId == indexId {
            selectedConversation = nil
        }
        
        saveConversations()
    }
    
    /// Select a conversation
    func selectConversation(_ conversation: ChatConversation) {
        selectedConversation = conversation
    }
    
    /// Deselect current conversation
    func deselectConversation() {
        selectedConversation = nil
    }
    
    /// Get conversations for a specific index
    func getConversations(for indexId: String) -> [ChatConversation] {
        return conversations.filter { $0.indexId == indexId }
    }
    
    /// Get recent conversations (limited to a number)
    func getRecentConversations(limit: Int = 10) -> [ChatConversation] {
        return Array(conversations.prefix(limit))
    }
    
    /// Rename a conversation
    func renameConversation(_ conversationId: String, to newTitle: String) {
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            var conversation = conversations[index]
            conversation.updateTitle(newTitle)
            updateConversation(conversation)
        }
    }
    
    // MARK: - Persistence
    
    private func saveConversations() {
        do {
            // Limit number of conversations stored
            let conversationsToSave = Array(conversations.prefix(maxConversations))
            let data = try JSONEncoder().encode(conversationsToSave)
            UserDefaults.standard.set(data, forKey: storageKey)
            Logger.log("Saved \(conversationsToSave.count) conversations", log: Logger.general)
        } catch {
            Logger.log("Failed to save conversations: \(error.localizedDescription)", log: Logger.general, type: .error)
        }
    }
    
    private func loadConversations() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            Logger.log("No saved conversations found", log: Logger.general)
            return
        }
        
        do {
            conversations = try JSONDecoder().decode([ChatConversation].self, from: data)
            Logger.log("Loaded \(conversations.count) conversations", log: Logger.general)
        } catch {
            Logger.log("Failed to load conversations: \(error.localizedDescription)", log: Logger.general, type: .error)
        }
    }
}
