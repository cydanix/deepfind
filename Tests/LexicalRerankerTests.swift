import XCTest
@testable import DeepFind

final class LexicalRerankerTests: XCTestCase {
    
    var lexicalReranker: LexicalReranker!
    
    override func setUp() {
        super.setUp()
        lexicalReranker = LexicalReranker()
    }
    
    override func tearDown() {
        lexicalReranker = nil
        super.tearDown()
    }
    
    // MARK: - lexicalScore Tests
    
    func testLexicalScoreBasicTokenOverlap() {
        // Test basic token matching
        let score1 = lexicalReranker.lexicalScore(query: "hello world", text: "hello there world")
        XCTAssertGreaterThan(score1, 0, "Should have positive score for token overlap")
        
        // Test partial overlap
        let score2 = lexicalReranker.lexicalScore(query: "hello world", text: "hello there")
        XCTAssertGreaterThan(score2, 0, "Should have positive score for partial overlap")
        XCTAssertGreaterThan(score1, score2, "More token overlap should have higher score")
        
        // Test no overlap
        let score3 = lexicalReranker.lexicalScore(query: "hello world", text: "goodbye universe")
        XCTAssertLessThan(score3, score2, "No token overlap should have lower score")
        XCTAssertLessThan(score3, 0, "No overlap should result in negative score due to length penalty")
    }
    
    func testLexicalScoreCaseInsensitive() {
        // Test case insensitive matching
        let score1 = lexicalReranker.lexicalScore(query: "Hello World", text: "hello world")
        let score2 = lexicalReranker.lexicalScore(query: "hello world", text: "HELLO WORLD")
        let score3 = lexicalReranker.lexicalScore(query: "HeLLo WoRLd", text: "hello world")
        
        XCTAssertEqual(score1, score2, accuracy: 0.01, "Should match case insensitively")
        XCTAssertEqual(score2, score3, accuracy: 0.01, "Should match case insensitively")
        XCTAssertEqual(score1, score3, accuracy: 0.01, "Should match case insensitively")
        XCTAssertGreaterThan(score1, 2.0, "Should have token overlap plus phrase bonus")
    }
    
    func testLexicalScorePhraseBonus() {
        // Test phrase bonus for exact substring match
        let scoreWithPhrase = lexicalReranker.lexicalScore(query: "hello world", text: "say hello world today")
        let scoreWithoutPhrase = lexicalReranker.lexicalScore(query: "hello world", text: "say hello there world today")
        
        // Both should have token overlap, but phrase bonus adds 2.0 more
        XCTAssertGreaterThan(scoreWithPhrase, scoreWithoutPhrase, "Phrase bonus should increase score")
        XCTAssertEqual(scoreWithPhrase - scoreWithoutPhrase, 2.0, accuracy: 0.1, "Phrase bonus should be approximately 2.0")
    }
    
    func testLexicalScoreIDTokenEmphasis() {
        // Test ID token emphasis with digits
        let scoreWithID1 = lexicalReranker.lexicalScore(query: "user123", text: "user123 is active")
        let scoreWithoutID = lexicalReranker.lexicalScore(query: "user", text: "user is active")
        
        // ID token should get 1.5x bonus
        XCTAssertGreaterThan(scoreWithID1, scoreWithoutID, "ID tokens should get emphasis bonus")
        
        // Test with all uppercase (ID tokens)
        let scoreWithID2 = lexicalReranker.lexicalScore(query: "API", text: "the API works")
        let scoreRegular = lexicalReranker.lexicalScore(query: "api", text: "the api works")
        
        XCTAssertGreaterThan(scoreWithID2, scoreRegular, "Uppercase tokens should get ID emphasis")
    }
    
    func testLexicalScoreLengthPenalty() {
        // Test that longer texts get slight penalty
        let shortText = "hello world"
        let longText = "hello world " + String(repeating: "extra ", count: 50)
        
        let shortScore = lexicalReranker.lexicalScore(query: "hello world", text: shortText)
        let longScore = lexicalReranker.lexicalScore(query: "hello world", text: longText)
        
        XCTAssertGreaterThan(shortScore, longScore, "Longer text should have lower score due to length penalty")
    }
    
    func testLexicalScoreEmptyInputs() {
        // Test empty query
        let score1 = lexicalReranker.lexicalScore(query: "", text: "some text")
        XCTAssertEqual(score1, 0.0, "Empty query should return 0")
        
        // Test empty text
        let score2 = lexicalReranker.lexicalScore(query: "hello", text: "")
        XCTAssertEqual(score2, 0.0, "Empty text should return 0")
        
        // Test both empty
        let score3 = lexicalReranker.lexicalScore(query: "", text: "")
        XCTAssertEqual(score3, 0.0, "Both empty should return 0")
    }
    
    func testLexicalScoreSpecialCharacters() {
        // Test that punctuation is handled correctly (should be ignored in tokenization)
        let score1 = lexicalReranker.lexicalScore(query: "hello world", text: "hello, world!")
        let score2 = lexicalReranker.lexicalScore(query: "hello world", text: "hello world")
        
        XCTAssertEqual(score1, score2, accuracy: 0.01, "Punctuation should not affect scoring")
        
        // Test underscores (should be preserved)
        let score3 = lexicalReranker.lexicalScore(query: "my_var", text: "use my_var here")
        XCTAssertGreaterThan(score3, 0, "Underscores should be preserved in tokens")
    }
    
    func testLexicalScoreUnicodeHandling() {
        // Test Unicode characters
        let score1 = lexicalReranker.lexicalScore(query: "café", text: "visit the café")
        XCTAssertGreaterThan(score1, 0, "Should handle Unicode letters correctly")
        
        let score2 = lexicalReranker.lexicalScore(query: "测试", text: "这是测试文本")
        XCTAssertGreaterThan(score2, 0, "Should handle CJK characters correctly")
    }
    
    func testLexicalScoreComplexScenario() {
        // Test a complex scenario with multiple features
        let query = "getUserID API123"
        let text = "The getUserID API123 function returns the user identifier from the database"
        
        let score = lexicalReranker.lexicalScore(query: query, text: text)
        
        // Should have:
        // - 2.0 for token overlap (getUserID, API123)
        // - 2.0 for phrase bonus (exact match)  
        // - 1.5 for ID token emphasis (API123)
        // - small length penalty
        
        XCTAssertGreaterThan(score, 4.0, "Complex scenario should have high score")
    }
    
    // MARK: - rerankLexical Tests
    
    func testRerankLexicalBasicOrdering() {
        // Create test documents
        let docs = [
            createTestDocument(id: "1", content: "this is about cats and dogs"),
            createTestDocument(id: "2", content: "information about dogs only"),
            createTestDocument(id: "3", content: "totally unrelated content")
        ]
        
        let reranked = lexicalReranker.rerankLexical(query: "dogs", docs: docs)
        
        // Document 2 should be first (only about dogs, higher relevance)
        // Document 1 should be second (mentions dogs among other things)  
        // Document 3 should be last (no match)
        XCTAssertEqual(reranked[0].id, "2", "Most relevant document should be first")
        XCTAssertEqual(reranked[1].id, "1", "Second most relevant document should be second")
        XCTAssertEqual(reranked[2].id, "3", "Least relevant document should be last")
    }
    
    func testRerankLexicalEmptyInput() {
        let emptyDocs: [MeilisearchDocumentChunk] = []
        let reranked = lexicalReranker.rerankLexical(query: "test", docs: emptyDocs)
        XCTAssertTrue(reranked.isEmpty, "Empty input should return empty result")
    }
    
    func testRerankLexicalSingleDocument() {
        let docs = [createTestDocument(id: "1", content: "single document")]
        let reranked = lexicalReranker.rerankLexical(query: "document", docs: docs)
        
        XCTAssertEqual(reranked.count, 1, "Should return single document")
        XCTAssertEqual(reranked[0].id, "1", "Should preserve document identity")
    }
    
    func testRerankLexicalWithPhraseBonus() {
        let docs = [
            createTestDocument(id: "1", content: "machine learning is powerful"),
            createTestDocument(id: "2", content: "machine and learning are separate"),
            createTestDocument(id: "3", content: "artificial intelligence and machine learning")
        ]
        
        let reranked = lexicalReranker.rerankLexical(query: "machine learning", docs: docs)
        
        // Document 1 and 3 should rank higher due to phrase bonus
        // Document 1 should be first (exact phrase at start)
        // Document 3 should be second (exact phrase at end)
        // Document 2 should be last (no phrase bonus)
        XCTAssertEqual(reranked[0].id, "1", "Document with phrase at start should rank highest")
        XCTAssertEqual(reranked[2].id, "2", "Document without phrase should rank lowest")
    }
    
    func testRerankLexicalPreservesAllDocuments() {
        let originalDocs = [
            createTestDocument(id: "1", content: "content one"),
            createTestDocument(id: "2", content: "content two"), 
            createTestDocument(id: "3", content: "content three")
        ]
        
        let reranked = lexicalReranker.rerankLexical(query: "content", docs: originalDocs)
        
        XCTAssertEqual(reranked.count, originalDocs.count, "Should preserve all documents")
        
        let originalIds = Set(originalDocs.map { $0.id })
        let rerankedIds = Set(reranked.map { $0.id })
        XCTAssertEqual(originalIds, rerankedIds, "Should preserve all document IDs")
    }
    
    // MARK: - Helper Methods
    
    private func createTestDocument(id: String, content: String) -> MeilisearchDocumentChunk {
        return MeilisearchDocumentChunk(
            id: id,
            content: content,
            fileName: "test.txt",
            filePath: "/test/\(id).txt",
            folderPath: "/test",
            pageNumber: nil,
            chunkNumber: 1,
            chunkSize: content.count,
            wordCount: content.split(separator: " ").count,
            fileType: "txt"
        )
    }
}
