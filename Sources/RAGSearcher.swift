import Foundation
import Combine

/// Handles RAG-based search queries using indexed content and LLM
@MainActor
class RAGSearcher: ObservableObject {
    @Published var isSearching: Bool = false
    @Published var searchResults: [SearchResult] = []
    @Published var currentQuery: String = ""
    @Published var searchHistory: [SearchQuery] = []
    
    static let shared = RAGSearcher()
    
    private let folderIndexer = FolderIndexer.shared
    private let settingsStore = SettingsStore.shared
    private let meilisearchManager = MeilisearchManager.shared
    
    private init() {}
    
    /// Perform a RAG search query
    /// - Parameters:
    ///   - query: The user's question/query
    ///   - indexId: The index ID to search (optional, defaults to current folder indexer's index)
    /// - Returns: Generated response based on indexed content
    /// - Throws: SearchError if search fails
    func search(query: String, indexId: String? = nil) async throws -> String {
        Logger.log("Starting RAG search for query: \(query)", log: Logger.general)
        
        let indexName: String
        if let providedIndexId = indexId {
            indexName = providedIndexId
        } else if let currentIndexName = folderIndexer.getCurrentIndexName() {
            indexName = currentIndexName
        } else {
            throw SearchError.noIndexAvailable
        }
        
        isSearching = true
        currentQuery = query
        
        defer {
            isSearching = false
        }
        
        // Search Meilisearch for relevant document chunks
        let relevantChunks = try await findRelevantChunks(for: query, indexName: indexName)
        
        guard !relevantChunks.isEmpty else {
            throw SearchError.noRelevantContent
        }
        
        // Build context from relevant chunks
        let context = buildContext(from: relevantChunks)
        
        // Generate response using LLM
        let response = try await generateResponse(query: query, context: context)
        
        // Store in search history
        let searchQuery = SearchQuery(
            query: query,
            response: response,
            timestamp: Date(),
            resultCount: relevantChunks.count
        )
        searchHistory.append(searchQuery)
        
        // Keep only last 50 searches
        if searchHistory.count > 50 {
            searchHistory.removeFirst()
        }
        
        Logger.log("RAG search completed successfully with \(relevantChunks.count) relevant chunks", log: Logger.general)
        return response
    }
    
    /// Clear search history
    func clearHistory() {
        searchHistory.removeAll()
        Logger.log("Search history cleared", log: Logger.general)
    }
    
    /// Get search suggestions based on indexed content
    /// - Parameter partial: Partial query text
    /// - Returns: Array of suggested queries
    func getSuggestions(for partial: String) -> [String] {
        // TODO: Implement query suggestions based on indexed content
        // This could analyze common topics/entities in the indexed files
        
        // Dummy suggestions for now
        let baseSuggestions = [
            "What are the main topics discussed?",
            "Summarize the key points",
            "Find information about...",
            "Explain the concept of...",
            "List all references to..."
        ]
        
        if partial.isEmpty {
            return baseSuggestions
        }
        
        return baseSuggestions.filter { $0.localizedCaseInsensitiveContains(partial) }
    }
    
    // MARK: - Private Methods
    
    /// Find relevant document chunks using Meilisearch full-text search with multi-search strategy
    /// - Parameters:
    ///   - query: User query
    ///   - indexName: Meilisearch index name to search
    /// - Returns: Array of relevant document chunks
    private func findRelevantChunks(for query: String, indexName: String) async throws -> [DocumentChunk] {
        Logger.log("Searching Meilisearch index '\(indexName)' for query: \(query)", log: Logger.general)
        
        // Check Meilisearch server health first
        let isHealthy = await meilisearchManager.healthCheck()
        if !isHealthy {
            throw SearchError.searchFailed("Meilisearch server is not healthy")
        }
        
        let keywords = KeywordsExtractor().getQueryKeywords(query)
        Logger.log("Extracted keywords: \(keywords)", log: Logger.general)
        
        // Use dictionary to store unique chunks by ID to avoid duplicates
        var uniqueChunks: [String: DocumentChunk] = [:]
        let chunksLimit = 100
        
        do {
            // First search with full query (get more results initially)
            let initialSearchOptions = SearchOptions(
                limit: 50,
                attributesToRetrieve: ["id", "content", "filePath", "pageNumber", "chunkNumber"],
                attributesToHighlight: ["content"],
                highlightPreTag: "<mark>",
                highlightPostTag: "</mark>"
            )
            
            let initialSearchData = try await meilisearchManager.search(
                indexUid: indexName,
                query: query,
                options: initialSearchOptions
            )
            
            let initialResults = try parseSearchResults(from: initialSearchData)
            
            // Add initial results to unique chunks
            for chunk in initialResults {
                uniqueChunks[chunk.id] = chunk
            }
            
            Logger.log("Initial search found \(initialResults.count) chunks", log: Logger.general)
            
            // If we have keywords, search with phrase combinations
            if !keywords.isEmpty {
                let phraseSearchOptions = SearchOptions(
                    limit: 10,
                    attributesToRetrieve: ["id", "content", "filePath", "pageNumber", "chunkNumber"],
                    attributesToHighlight: ["content"],
                    highlightPreTag: "<mark>",
                    highlightPostTag: "</mark>"
                )
                
                // Search with phrases of different lengths (1 to 3 words)
                for phraseLength in 1...5 {
                    guard uniqueChunks.count < chunksLimit else { break }
                    
                    let maxStartIndex = keywords.count - phraseLength
                    for startIndex in stride(from: maxStartIndex, through: 0, by: -1) {
                        guard uniqueChunks.count < chunksLimit else { break }
                        
                        let phrase = keywords[startIndex..<startIndex + phraseLength].joined(separator: " ")
                        
                        do {
                            let phraseSearchData = try await meilisearchManager.search(
                                indexUid: indexName,
                                query: phrase,
                                options: phraseSearchOptions
                            )
                            
                            let phraseResults = try parseSearchResults(from: phraseSearchData)
                            
                            for chunk in phraseResults {
                                if uniqueChunks.count >= chunksLimit {
                                    break
                                }
                                
                                // Only add if not already in unique chunks
                                if uniqueChunks[chunk.id] == nil {
                                    uniqueChunks[chunk.id] = chunk
                                }
                            }
                            
                            Logger.log("Phrase '\(phrase)' found \(phraseResults.count) additional chunks", log: Logger.general)
                            
                        } catch {
                            Logger.log("Phrase search failed for '\(phrase)': \(error.localizedDescription)", log: Logger.general)
                            // Continue with other phrases even if one fails
                        }
                    }
                }
            }
            
            Logger.log("Total unique chunks collected: \(uniqueChunks.count)", log: Logger.general)

            // Rerank all collected results
            let reranker = LexicalReranker()
            let rerankedResults = reranker.rerankLexical(query: query, docs: Array(uniqueChunks.values))
            
            Logger.log("Found and reranked \(rerankedResults.count) relevant chunks", log: Logger.general)
            return rerankedResults
            
        } catch {
            Logger.log("Multi-search failed: \(error.localizedDescription)", log: Logger.general)
            throw SearchError.searchFailed("Multi-search failed: \(error.localizedDescription)")
        }
    }
    
    /// Parse Meilisearch search results JSON into document chunks
    /// - Parameter data: Raw JSON data from Meilisearch
    /// - Returns: Array of parsed document chunks
    private func parseSearchResults(from data: Data) throws -> [DocumentChunk] {
        // Separate struct for search results that matches what Meilisearch actually returns
        struct SearchResultChunk: Codable {
            let id: String
            let content: String
            let filePath: String
            let pageNumber: Int?
            let chunkNumber: Int
            // Note: _formatted is ignored as we don't need it
            
            private enum CodingKeys: String, CodingKey {
                case id, content, filePath, pageNumber, chunkNumber
            }
        }

        struct MeilisearchSearchResponse: Codable {
            let hits: [SearchResultChunk]
            let query: String
            let processingTimeMs: Int
            let limit: Int
            let offset: Int
            let estimatedTotalHits: Int
        }
        
        // Log the raw response for debugging (truncated)
        if let responseString = String(data: data, encoding: .utf8) {
            let truncated = responseString.count > 500 ? String(responseString.prefix(500)) + "..." : responseString
            Logger.log("Meilisearch raw response: \(truncated)", log: Logger.general)
        } else {
            Logger.log("Failed to convert Meilisearch response to string, data size: \(data.count) bytes", log: Logger.general)
        }
        
        // Check if data is empty
        guard !data.isEmpty else {
            throw SearchError.searchFailed("Empty response from Meilisearch")
        }
        
        let decoder = JSONDecoder()
        do {
            let response = try decoder.decode(MeilisearchSearchResponse.self, from: data)
            Logger.log("Successfully parsed Meilisearch response with \(response.hits.count) hits", log: Logger.general)
            
            // Convert search results to DocumentChunk format
            let documentChunks = response.hits.map { hit in
                DocumentChunk(
                    id: hit.id,
                    content: hit.content,
                    filePath: hit.filePath,
                    pageNumber: hit.pageNumber ?? 0,
                    chunkNumber: hit.chunkNumber
                )
            }
            
            return documentChunks
        } catch {
            Logger.log("Failed to decode Meilisearch response: \(error.localizedDescription)", log: Logger.general)
            throw SearchError.searchFailed("Failed to parse Meilisearch response: \(error.localizedDescription)")
        }
    }

    private func countWords(in text: String) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }

    private func estimateTokenCount(text: String) -> Int {
        let wordCount = countWords(in: text)
        return Int(1.1 * max((1.3 * Double(wordCount)), Double(text.count) / 4))
    }

    /// Build context string from relevant document chunks
    /// - Parameter chunks: Array of relevant document chunks
    /// - Returns: Formatted context string for LLM
    private func buildContext(from chunks: [DocumentChunk]) -> String {
        let separator = "\n\n---\n\n"
        var contextParts: [String] = []

        let maxContextSize = settingsStore.contextSize
        var totalTokenCount = 0
        for chunk in chunks {
            let source = "FilePath: \(chunk.filePath) (Page: \(chunk.pageNumber)) (ID: \(chunk.id)) (SeqNo: \(chunk.chunkNumber))"
            totalTokenCount += estimateTokenCount(text: chunk.content)
            if totalTokenCount > maxContextSize {
                break
            }
            contextParts.append("From \(source):\n\(chunk.content)")
        }

        return contextParts.joined(separator: separator)
    }
    
    private func generateResponse(query: String, context: String) async throws -> String {
        // TODO: Use actual LLM to generate response
        // This should send the context and query to the LLM and return the response
        
        let llm = LLMFactory.createLLM()
        let isReady = try await llm.isReady()
        
        guard isReady else {
            throw SearchError.llmNotReady
        }
        
        let prompt = """
        Based on the following context from the user's documents, please answer their question:
        
        Context:
        \(context)
        
        Question: \(query)
        
        Please provide a helpful and accurate answer based only on the information in the context above.
        """
        
        return try await llm.process(prompt: prompt, text: "")
    }
}

// MARK: - Data Models

struct SearchResult {
    let query: String
    let answer: String
    let sources: [DocumentChunk]
    let timestamp: Date
}

struct SearchQuery {
    let query: String
    let response: String
    let timestamp: Date
    let resultCount: Int
}

// MARK: - Error Types

enum SearchError: LocalizedError {
    case noIndexAvailable
    case noRelevantContent
    case llmNotReady
    case searchFailed(String)
    case invalidQuery
    
    var errorDescription: String? {
        switch self {
        case .noIndexAvailable:
            return "No folder has been indexed yet. Please select and index a folder first."
        case .noRelevantContent:
            return "No relevant content found for your query. Try rephrasing your question."
        case .llmNotReady:
            return "LLM is not ready. Please check your model setup."
        case .searchFailed(let reason):
            return "Search failed: \(reason)"
        case .invalidQuery:
            return "Invalid query. Please enter a valid question."
        }
    }
}
