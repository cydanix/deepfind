import XCTest
@testable import DeepFind

final class MeilisearchTests: XCTestCase {
    
    var meilisearchManager: MeilisearchManager!
    
    override func setUp() async throws {
        try await super.setUp()
        meilisearchManager = MeilisearchManager.shared
        
        // Start Meilisearch server once for all tests
        let started = await meilisearchManager.start()
        if !started {
            throw TestError.serverStartFailed
        }
    }
    
    override func tearDown() async throws {
        // Stop Meilisearch server after all tests
        await meilisearchManager.stop()
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func deleteTestIndexIfExists(_ indexUid: String) async throws {
        do {
            let deleteData = try await meilisearchManager.deleteIndex(uid: indexUid)
            // Properly wait for deletion task to complete
            _ = try await waitForTask(taskData: deleteData)
        } catch {
            // Ignore errors if index doesn't exist
        }
    }
    
    private func waitForTask(taskData: Data, timeout: TimeInterval = 10.0) async throws -> Bool {
        guard let taskResponse = try JSONSerialization.jsonObject(with: taskData) as? [String: Any],
              let taskId = taskResponse["taskUid"] as? Int else {
            throw TestError.invalidTaskResponse
        }
        
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            let taskData = try await meilisearchManager.getTask(taskId: taskId)
            guard let task = try JSONSerialization.jsonObject(with: taskData) as? [String: Any],
                  let status = task["status"] as? String else {
                throw TestError.invalidTaskStatus
            }
            
            switch status {
            case "succeeded":
                return true
            case "failed":
                let error = task["error"] as? [String: Any]
                throw TestError.taskFailed(error?["message"] as? String ?? "Unknown error")
            case "processing", "enqueued":
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                continue
            default:
                throw TestError.unknownTaskStatus(status)
            }
        }
        
        throw TestError.taskTimeout
    }
    
    // MARK: - Individual Tests
    
    func testCreateIndex() async throws {
        let testIndexUid = "test_index_\(Int(Date().timeIntervalSince1970 * 1000))_\(UUID().uuidString.prefix(8))"
        
        // Clean up any existing test index
        try await deleteTestIndexIfExists(testIndexUid)
        
        // Create index
        let createData = try await meilisearchManager.createIndex(uid: testIndexUid, primaryKey: "id")
        let createTaskSucceeded = try await waitForTask(taskData: createData)
        XCTAssertTrue(createTaskSucceeded, "Index creation task failed")
        
        // Verify index exists
        let indexData = try await meilisearchManager.getIndex(uid: testIndexUid)
        let indexInfo = try JSONSerialization.jsonObject(with: indexData) as? [String: Any]
        
        XCTAssertNotNil(indexInfo, "Failed to retrieve index information")
        XCTAssertEqual(indexInfo?["uid"] as? String, testIndexUid, "Index UID doesn't match")
        XCTAssertEqual(indexInfo?["primaryKey"] as? String, "id", "Primary key doesn't match")
        
        // Cleanup - delete the test index
        try await deleteTestIndexIfExists(testIndexUid)
    }
    
    func testAddDocuments() async throws {
        let testIndexUid = "test_index_\(Int(Date().timeIntervalSince1970 * 1000))_\(UUID().uuidString.prefix(8))"
        
        // Clean up and create test index
        try await deleteTestIndexIfExists(testIndexUid)
        let createData = try await meilisearchManager.createIndex(uid: testIndexUid, primaryKey: "id")
        let createTaskSucceeded = try await waitForTask(taskData: createData)
        XCTAssertTrue(createTaskSucceeded, "Index creation task failed")
        
        // Test documents
        let testDocuments = [
            TestDocument(
                id: "doc1",
                title: "Swift Programming Guide",
                content: "Learn Swift programming language with comprehensive examples and tutorials.",
                category: "Programming"
            ),
            TestDocument(
                id: "doc2", 
                title: "iOS Development Basics",
                content: "Introduction to iOS development using Xcode and UIKit framework.",
                category: "Mobile Development"
            ),
            TestDocument(
                id: "doc3",
                title: "Machine Learning Fundamentals",
                content: "Understanding the basics of machine learning algorithms and data science.",
                category: "AI"
            )
        ]
        
        // Add documents to index using the dedicated method
        let addData = try await meilisearchManager.indexDocuments(indexUid: testIndexUid, documents: testDocuments)
        let addTaskSucceeded = try await waitForTask(taskData: addData)
        XCTAssertTrue(addTaskSucceeded, "Document indexing task failed")

        // Cleanup - delete the test index
        try await deleteTestIndexIfExists(testIndexUid)
    }
    
    func testSearchDocuments() async throws {
        let testIndexUid = "test_index_\(Int(Date().timeIntervalSince1970 * 1000))_\(UUID().uuidString.prefix(8))"
        
        // Clean up, create index, and add documents
        try await deleteTestIndexIfExists(testIndexUid)
        let createData = try await meilisearchManager.createIndex(uid: testIndexUid, primaryKey: "id")
        let createTaskSucceeded = try await waitForTask(taskData: createData)
        XCTAssertTrue(createTaskSucceeded, "Index creation task failed")
        
        let testDocuments = [
            TestDocument(
                id: "doc1",
                title: "Swift Programming Guide",
                content: "Learn Swift programming language with comprehensive examples and tutorials.",
                category: "Programming"
            ),
            TestDocument(
                id: "doc2",
                title: "iOS Development Basics", 
                content: "Introduction to iOS development using Xcode and UIKit framework.",
                category: "Mobile Development"
            )
        ]
        
        let addData = try await meilisearchManager.indexDocuments(indexUid: testIndexUid, documents: testDocuments)
        let addTaskSucceeded = try await waitForTask(taskData: addData)
        XCTAssertTrue(addTaskSucceeded, "Document indexing task failed")
        
        // Test search functionality
        let searchOptions = SearchOptions(limit: 10, attributesToRetrieve: ["id", "title", "content"])
        
        // Search for "Swift"
        let swiftSearchData = try await meilisearchManager.search(indexUid: testIndexUid, query: "Swift", options: searchOptions)
        let swiftSearchResponse = try JSONSerialization.jsonObject(with: swiftSearchData) as? [String: Any]
        let swiftResults = swiftSearchResponse?["hits"] as? [[String: Any]]
        
        XCTAssertNotNil(swiftResults, "Failed to get search results for 'Swift'")
        XCTAssertEqual(swiftResults?.count, 1, "Expected 1 result for 'Swift' search")
        XCTAssertEqual(swiftResults?.first?["id"] as? String, "doc1", "Wrong document returned for 'Swift' search")
        
        // Search for "development"
        let devSearchData = try await meilisearchManager.search(indexUid: testIndexUid, query: "development", options: searchOptions)
        let devSearchResponse = try JSONSerialization.jsonObject(with: devSearchData) as? [String: Any]
        let devResults = devSearchResponse?["hits"] as? [[String: Any]]
        
        XCTAssertNotNil(devResults, "Failed to get search results for 'development'")
        XCTAssertGreaterThanOrEqual(devResults?.count ?? 0, 1, "Expected at least 1 result for 'development' search")
        
        // Search for non-existent term
        let emptySearchData = try await meilisearchManager.search(indexUid: testIndexUid, query: "nonexistent", options: searchOptions)
        let emptySearchResponse = try JSONSerialization.jsonObject(with: emptySearchData) as? [String: Any]
        let emptyResults = emptySearchResponse?["hits"] as? [[String: Any]]
        
        XCTAssertNotNil(emptyResults, "Failed to get search results for 'nonexistent'")
        XCTAssertEqual(emptyResults?.count, 0, "Expected 0 results for 'nonexistent' search")
        
        // Cleanup - delete the test index
        try await deleteTestIndexIfExists(testIndexUid)
    }
    
    func testDeleteIndex() async throws {
        let testIndexUid = "test_index_\(Int(Date().timeIntervalSince1970 * 1000))_\(UUID().uuidString.prefix(8))"
        
        // Create test index
        try await deleteTestIndexIfExists(testIndexUid)
        let createData = try await meilisearchManager.createIndex(uid: testIndexUid, primaryKey: "id")
        let createTaskSucceeded = try await waitForTask(taskData: createData)
        XCTAssertTrue(createTaskSucceeded, "Index creation task failed")
        
        // Verify index exists
        let _ = try await meilisearchManager.getIndex(uid: testIndexUid)
        
        // Delete the index
        let deleteData = try await meilisearchManager.deleteIndex(uid: testIndexUid)
        let deleteTaskSucceeded = try await waitForTask(taskData: deleteData)
        XCTAssertTrue(deleteTaskSucceeded, "Index deletion task failed")
        
        // Verify index no longer exists
        do {
            let _ = try await meilisearchManager.getIndex(uid: testIndexUid)
            XCTFail("Index should have been deleted but still exists")
        } catch {
            // Expected to throw error since index should not exist
            XCTAssertTrue(true, "Index successfully deleted")
        }
    }
    
    // MARK: - Integration Test
    
    func testCompleteWorkflow() async throws {
        let testIndexUid = "test_index_\(Int(Date().timeIntervalSince1970 * 1000))_\(UUID().uuidString.prefix(8))"
        
        // 1. Create index
        try await deleteTestIndexIfExists(testIndexUid)
        let createData = try await meilisearchManager.createIndex(uid: testIndexUid, primaryKey: "id")
        let createTaskSucceeded = try await waitForTask(taskData: createData)
        XCTAssertTrue(createTaskSucceeded, "Index creation task failed")
        
        // 2. Add documents with text
        let testDocuments = [
            TestArticle(
                id: "article1",
                title: "The Future of Artificial Intelligence",
                content: "Artificial intelligence is rapidly transforming industries across the globe. From healthcare to finance, AI technologies are creating new possibilities.",
                author: "John Doe",
                tags: ["AI", "Technology", "Innovation"]
            ),
            TestArticle(
                id: "article2",
                title: "Sustainable Energy Solutions",
                content: "Renewable energy sources like solar and wind power are becoming increasingly important for combating climate change and ensuring energy security.",
                author: "Jane Smith", 
                tags: ["Energy", "Environment", "Sustainability"]
            ),
            TestArticle(
                id: "article3",
                title: "Modern Web Development Trends",
                content: "Web development continues to evolve with new frameworks, tools, and best practices emerging regularly to improve developer productivity.",
                author: "Bob Johnson",
                tags: ["Web", "Development", "Programming"]
            )
        ]
        
        let addData = try await meilisearchManager.indexDocuments(indexUid: testIndexUid, documents: testDocuments)
        let addTaskSucceeded = try await waitForTask(taskData: addData)
        XCTAssertTrue(addTaskSucceeded, "Document indexing task failed")
        
        // 3. Search and find documents
        let searchOptions = SearchOptions(
            limit: 10,
            attributesToRetrieve: ["id", "title", "content", "author"],
            attributesToHighlight: ["title", "content"]
        )
        
        // Search for "artificial intelligence"
        let aiSearchData = try await meilisearchManager.search(indexUid: testIndexUid, query: "artificial intelligence", options: searchOptions)
        let aiSearchResponse = try JSONSerialization.jsonObject(with: aiSearchData) as? [String: Any]
        let aiResults = aiSearchResponse?["hits"] as? [[String: Any]]
        
        XCTAssertNotNil(aiResults, "Failed to get search results for 'artificial intelligence'")
        XCTAssertEqual(aiResults?.count, 1, "Expected 1 result for 'artificial intelligence' search")
        XCTAssertEqual(aiResults?.first?["id"] as? String, "article1", "Wrong document returned for AI search")
        
        // Search for "development"
        let devSearchData = try await meilisearchManager.search(indexUid: testIndexUid, query: "development", options: searchOptions)
        let devSearchResponse = try JSONSerialization.jsonObject(with: devSearchData) as? [String: Any]
        let devResults = devSearchResponse?["hits"] as? [[String: Any]]
        
        XCTAssertNotNil(devResults, "Failed to get search results for 'development'")
        XCTAssertEqual(devResults?.count, 1, "Expected 1 result for 'development' search")
        XCTAssertEqual(devResults?.first?["id"] as? String, "article3", "Wrong document returned for development search")
        
        // Search for "energy"
        let energySearchData = try await meilisearchManager.search(indexUid: testIndexUid, query: "energy", options: searchOptions)
        let energySearchResponse = try JSONSerialization.jsonObject(with: energySearchData) as? [String: Any]
        let energyResults = energySearchResponse?["hits"] as? [[String: Any]]
        
        XCTAssertNotNil(energyResults, "Failed to get search results for 'energy'")
        XCTAssertEqual(energyResults?.count, 1, "Expected 1 result for 'energy' search")
        XCTAssertEqual(energyResults?.first?["id"] as? String, "article2", "Wrong document returned for energy search")
        
        // 4. Delete index
        let deleteData = try await meilisearchManager.deleteIndex(uid: testIndexUid)
        let deleteTaskSucceeded = try await waitForTask(taskData: deleteData)
        XCTAssertTrue(deleteTaskSucceeded, "Index deletion task failed")
        
        // Verify index is deleted
        do {
            let _ = try await meilisearchManager.getIndex(uid: testIndexUid)
            XCTFail("Index should have been deleted but still exists")
        } catch {
            // Expected to throw error since index should not exist
            XCTAssertTrue(true, "Complete workflow test completed successfully")
        }
    }
}

// MARK: - Test Document Types

struct TestDocument: Codable {
    let id: String
    let title: String
    let content: String
    let category: String
}

struct TestArticle: Codable {
    let id: String
    let title: String
    let content: String
    let author: String
    let tags: [String]
}

// MARK: - Test Error Types

enum TestError: LocalizedError {
    case invalidTaskResponse
    case invalidTaskStatus
    case taskFailed(String)
    case unknownTaskStatus(String)
    case taskTimeout
    case serverStartFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidTaskResponse:
            return "Invalid task response from Meilisearch"
        case .invalidTaskStatus:
            return "Invalid task status in response"
        case .taskFailed(let message):
            return "Task failed: \(message)"
        case .unknownTaskStatus(let status):
            return "Unknown task status: \(status)"
        case .taskTimeout:
            return "Task timed out"
        case .serverStartFailed:
            return "Failed to start Meilisearch server"
        }
    }
}
