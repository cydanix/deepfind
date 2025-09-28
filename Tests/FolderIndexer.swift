import XCTest
@testable import DeepFind

final class FolderIndexerTests: XCTestCase {
    
    var meilisearchManager: MeilisearchManager!
    var folderIndexer: FolderIndexer!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        
        meilisearchManager = MeilisearchManager.shared
        folderIndexer = FolderIndexer.shared
        
        // Start Meilisearch server
        let started = await meilisearchManager.start()
        if !started {
            throw TestError.serverStartFailed
        }
    }
    
    @MainActor
    override func tearDown() async throws {
        // Clear any index that might have been created
        await folderIndexer.clearIndex()
        
        // Stop Meilisearch server
        await meilisearchManager.stop()
        
        try await super.tearDown()
    }
    
    // MARK: - Tests
    
    @MainActor
    func testIndexTestDataFolder() async throws {
        // Get the path to the Tests/Data folder
        let currentPath = FileManager.default.currentDirectoryPath
        let testDataPath = "\(currentPath)/Tests/Data"
        
        // Verify the test data folder exists
        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: testDataPath), "Tests/Data folder should exist")
        
        // Verify emma.pdf exists
        let emmaPdfPath = "\(testDataPath)/emma.pdf"
        XCTAssertTrue(fileManager.fileExists(atPath: emmaPdfPath), "emma.pdf should exist in Tests/Data")
        
        // Initial state should be not indexed
        XCTAssertFalse(folderIndexer.isFolderIndexed(testDataPath), "Folder should not be indexed initially")
        XCTAssertNil(folderIndexer.indexedFolderPath, "No folder should be indexed initially")
        XCTAssertEqual(folderIndexer.indexedFileCount, 0, "File count should be 0 initially")
        
        // Index the test data folder
        try await folderIndexer.indexFolder(at: testDataPath)
        
        // Verify indexing completed successfully
        XCTAssertTrue(folderIndexer.isFolderIndexed(testDataPath), "Folder should be indexed after indexing")
        XCTAssertEqual(folderIndexer.indexedFolderPath, testDataPath, "Indexed folder path should match")
        XCTAssertGreaterThan(folderIndexer.indexedFileCount, 0, "Should have indexed at least one file")
        XCTAssertNotNil(folderIndexer.lastIndexingDate, "Should have a last indexing date")
        XCTAssertNotNil(folderIndexer.getCurrentIndexName(), "Should have a current index name")
        
        // Verify the index was created in Meilisearch
        if let indexName = folderIndexer.getCurrentIndexName() {
            // Try to get the index - this will throw if it doesn't exist
            let indexData = try await meilisearchManager.getIndex(uid: indexName)
            let indexInfo = try JSONSerialization.jsonObject(with: indexData) as? [String: Any]
            XCTAssertNotNil(indexInfo, "Index should exist in Meilisearch")
            XCTAssertEqual(indexInfo?["uid"] as? String, indexName, "Index UID should match")
        }
        
        // Test indexing summary
        let summary = folderIndexer.getIndexingSummary()
        XCTAssertFalse(summary.isEmpty, "Indexing summary should not be empty")
        XCTAssertTrue(summary.contains("Data"), "Summary should contain folder name")
    }
}
