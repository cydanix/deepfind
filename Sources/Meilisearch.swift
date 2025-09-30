import Foundation
import Network

/// Manages the lifecycle of a local Meilisearch instance
/// 
/// This class interfaces with the bundled Meilisearch server binary.
/// Meilisearch is open-source software licensed under the MIT License.
/// See THIRD-PARTY-LICENSES file for full attribution and license details.
class MeilisearchManager {
    
    // MARK: - Singleton
    
    static let shared = MeilisearchManager()
    
    // MARK: - Properties
    
    private(set) var isRunning: Bool = false
    private(set) var isStarting: Bool = false
    private let lock = NSLock()
    
    private var process: Process?
    private var port: Int = 0
    private var masterKey: String = ""
    private let binaryPath: String
    private let dataPath: String
    
    // HTTP client for making requests
    private var urlSession: URLSession
    
    // MARK: - Initialization
    
    private init() {
        // Check if running in local development mode
        let isLocalRun = ProcessInfo.processInfo.environment["LOCAL_RUN"] == "1"
        
        if isLocalRun {
            // Local development: use workspace paths
            let workspaceURL = FileManager.default.currentDirectoryPath
            self.binaryPath = "\(workspaceURL)/External/meilisearch"
            self.dataPath = "\(workspaceURL)/Temp/meilisearch_data"
        } else {
            // Production app: use bundle and application support paths
            guard let bundlePath = Bundle.main.resourcePath else {
                fatalError("Unable to find app bundle resource path")
            }
            self.binaryPath = "\(bundlePath)/meilisearch"
            
            // Use Application Support directory for data storage
            let fileManager = FileManager.default
            guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, 
                                                      in: .userDomainMask).first else {
                fatalError("Unable to find Application Support directory")
            }
            
            let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "DeepFind"
            let appDataURL = appSupportURL.appendingPathComponent(appName)
            self.dataPath = appDataURL.appendingPathComponent("meilisearch_data").path
        }
        
        // Configure URL session with reasonable timeout to prevent hangs
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30   // 30 seconds for individual requests
        config.timeoutIntervalForResource = 120 // 2 minutes for complete operations
        self.urlSession = URLSession(configuration: config)
        
        // Use a fixed master key for consistency across sessions
        // In production, this should be more secure, but for development/testing, a fixed key is easier
        self.masterKey = "deepfind_master_key_for_local_development_only_12345"
        
        Logger.log("MeilisearchManager initialized - Mode: \(isLocalRun ? "Local Development" : "Production App"), Binary: \(binaryPath), Data: \(dataPath)", log: Logger.general)
    }
    
    deinit {
        stopSync()
    }
    
    // MARK: - Thread-safe property setters
    
    private func setIsRunning(_ value: Bool) {
        lock.lock()
        defer { lock.unlock() }
        isRunning = value
    }
    
    private func setIsStarting(_ value: Bool) {
        lock.lock()
        defer { lock.unlock() }
        isStarting = value
    }
    
    // MARK: - Public Interface
    
    /// Start the Meilisearch server on a free port
    /// - Returns: True if started successfully, false otherwise
    func start() async -> Bool {
        guard !isRunning && !isStarting else {
            Logger.log("Meilisearch is already running or starting", log: Logger.general)
            return isRunning
        }
        
        setIsStarting(true)
        defer { setIsStarting(false) }
        
        do {
            // Find a free port
            guard let freePort = await findFreePort() else {
                Logger.log("Failed to find a free port for Meilisearch", log: Logger.general)
                return false
            }
            
            self.port = freePort
            Logger.log("Found free port: \(port)", log: Logger.general)
            
            // Create data directory if it doesn't exist
            try createDataDirectoryIfNeeded()
            
            // Start the Meilisearch process
            guard try startMeilisearchProcess() else {
                Logger.log("Failed to start Meilisearch process", log: Logger.general)
                return false
            }
            
            // Wait for Meilisearch to be ready
            if await waitForMeilisearchReady() {
                setIsRunning(true)
                Logger.log("Meilisearch started successfully on port \(port)", log: Logger.general)
                return true
            } else {
                Logger.log("Meilisearch failed to become ready", log: Logger.general)
                await stop()
                return false
            }
            
        } catch {
            Logger.log("Error starting Meilisearch: \(error)", log: Logger.general)
            await stop()
            return false
        }
    }
    
    /// Stop the Meilisearch server
    func stop() async {
        await performStop()
    }
    
    /// Synchronous stop for deinit
    private func stopSync() {
        performStopSync()
    }
    
    /// Public synchronous stop for app termination to ensure graceful shutdown
    func stopSyncForTermination() {
        performStopSync()
    }
    
    /// Shared stop implementation (async version)
    private func performStop() async {
        guard isRunning || process != nil else {
            Logger.log("Meilisearch is not running", log: Logger.general)
            return
        }
        
        Logger.log("Stopping Meilisearch server", log: Logger.general)
        
        if let process = process {
            process.terminate()
            
            // Wait up to 5 seconds for graceful shutdown
            for _ in 0..<50 {
                if !process.isRunning {
                    break
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            
            // Force kill if still running
            if process.isRunning {
                Logger.log("Force killing Meilisearch process", log: Logger.general)
                process.interrupt()
            }
            
            self.process = nil
        }
        
        setIsRunning(false)
        port = 0
        Logger.log("Meilisearch stopped", log: Logger.general)
    }
    
    /// Shared stop implementation (synchronous version)
    private func performStopSync() {
        guard isRunning || process != nil else {
            Logger.log("Meilisearch is not running", log: Logger.general)
            return
        }
        
        Logger.log("Stopping Meilisearch server (sync)", log: Logger.general)
        
        if let process = process {
            // Send SIGTERM for graceful shutdown
            Logger.log("Sending SIGTERM to Meilisearch process (PID: \(process.processIdentifier))", log: Logger.general)
            process.terminate()
            
            // Wait up to 5 seconds for graceful shutdown
            let startTime = Date()
            while process.isRunning && Date().timeIntervalSince(startTime) < 5.0 {
                Thread.sleep(forTimeInterval: 0.1) // 0.1 seconds
            }
            
            // Force kill if still running after 5 seconds
            if process.isRunning {
                Logger.log("Graceful shutdown timeout, force killing Meilisearch process", log: Logger.general)
                process.interrupt() // SIGKILL
                
                // Give it another moment
                Thread.sleep(forTimeInterval: 0.5)
                
                if process.isRunning {
                    Logger.log("Warning: Meilisearch process may still be running after force kill", log: Logger.general)
                } else {
                    Logger.log("Meilisearch process terminated after force kill", log: Logger.general)
                }
            } else {
                Logger.log("Meilisearch process terminated gracefully", log: Logger.general)
            }
            
            self.process = nil
        }
        
        setIsRunning(false)
        port = 0
        Logger.log("Meilisearch stopped (sync)", log: Logger.general)
    }
    
    /// Get the current server URL
    var serverURL: URL? {
        guard isRunning, port > 0 else { return nil }
        return URL(string: "http://localhost:\(port)")
    }
    
    /// Get the master key for authentication
    var apiKey: String {
        return masterKey
    }
    
    // MARK: - HTTP Client Methods
    
    /// Send a GET request to Meilisearch
    /// - Parameter path: API endpoint path
    /// - Returns: Response data
    func get(_ path: String) async throws -> Data {
        return try await makeRequest(path: path, method: "GET", body: nil)
    }
    
    /// Send a POST request to Meilisearch
    /// - Parameters:
    ///   - path: API endpoint path
    ///   - body: Request body data
    /// - Returns: Response data
    func post(_ path: String, body: Data? = nil) async throws -> Data {
        return try await makeRequest(path: path, method: "POST", body: body)
    }
    
    /// Send a PUT request to Meilisearch
    /// - Parameters:
    ///   - path: API endpoint path
    ///   - body: Request body data
    /// - Returns: Response data
    func put(_ path: String, body: Data? = nil) async throws -> Data {
        return try await makeRequest(path: path, method: "PUT", body: body)
    }
    
    /// Send a DELETE request to Meilisearch
    /// - Parameter path: API endpoint path
    /// - Returns: Response data
    func delete(_ path: String) async throws -> Data {
        return try await makeRequest(path: path, method: "DELETE", body: nil)
    }
    
    /// Check if Meilisearch server is healthy
    func healthCheck() async -> Bool {
        do {
            let _ = try await get("/health")
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Index Management
    
    /// Create a new index
    /// - Parameters:
    ///   - uid: Unique identifier for the index
    ///   - primaryKey: Optional primary key field name
    /// - Returns: Index creation task response data
    func createIndex(uid: String, primaryKey: String? = nil) async throws -> Data {
        var body: [String: Any] = ["uid": uid]
        if let primaryKey = primaryKey {
            body["primaryKey"] = primaryKey
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        return try await post("/indexes", body: jsonData)
    }
    
    /// Delete an index
    /// - Parameter uid: Unique identifier of the index to delete
    /// - Returns: Index deletion task response data
    func deleteIndex(uid: String) async throws -> Data {
        return try await delete("/indexes/\(uid)")
    }
    
    /// Get all indexes
    /// - Returns: List of all indexes
    func getIndexes() async throws -> Data {
        return try await get("/indexes")
    }
    
    /// Get a specific index
    /// - Parameter uid: Unique identifier of the index
    /// - Returns: Index information
    func getIndex(uid: String) async throws -> Data {
        return try await get("/indexes/\(uid)")
    }
    
    // MARK: - Document Management
    
    /// Add or update documents in an index
    /// - Parameters:
    ///   - indexUid: Unique identifier of the index
    ///   - documents: Array of documents to add/update
    ///   - primaryKey: Optional primary key for the documents
    /// - Returns: Document indexing task response data
    func indexDocuments<T: Encodable>(indexUid: String, documents: [T], primaryKey: String? = nil) async throws -> Data {
        var urlPath = "/indexes/\(indexUid)/documents"
        if let primaryKey = primaryKey {
            urlPath += "?primaryKey=\(primaryKey)"
        }
        
        let jsonData = try JSONEncoder().encode(documents)
        return try await post(urlPath, body: jsonData)
    }
    
    /// Add or update a single document in an index
    /// - Parameters:
    ///   - indexUid: Unique identifier of the index
    ///   - document: Document to add/update
    ///   - primaryKey: Optional primary key for the document
    /// - Returns: Document indexing task response data
    func indexDocument<T: Encodable>(indexUid: String, document: T, primaryKey: String? = nil) async throws -> Data {
        return try await indexDocuments(indexUid: indexUid, documents: [document], primaryKey: primaryKey)
    }
    
    /// Get all documents from an index
    /// - Parameters:
    ///   - indexUid: Unique identifier of the index
    ///   - limit: Maximum number of documents to return (default: 20)
    ///   - offset: Number of documents to skip (default: 0)
    /// - Returns: Documents data
    func getDocuments(indexUid: String, limit: Int = 20, offset: Int = 0) async throws -> Data {
        return try await get("/indexes/\(indexUid)/documents?limit=\(limit)&offset=\(offset)")
    }
    
    /// Get a specific document by ID
    /// - Parameters:
    ///   - indexUid: Unique identifier of the index
    ///   - documentId: ID of the document to retrieve
    /// - Returns: Document data
    func getDocument(indexUid: String, documentId: String) async throws -> Data {
        return try await get("/indexes/\(indexUid)/documents/\(documentId)")
    }
    
    /// Delete a specific document by ID
    /// - Parameters:
    ///   - indexUid: Unique identifier of the index
    ///   - documentId: ID of the document to delete
    /// - Returns: Document deletion task response data
    func deleteDocument(indexUid: String, documentId: String) async throws -> Data {
        return try await delete("/indexes/\(indexUid)/documents/\(documentId)")
    }
    
    /// Delete multiple documents by IDs
    /// - Parameters:
    ///   - indexUid: Unique identifier of the index
    ///   - documentIds: Array of document IDs to delete
    /// - Returns: Document deletion task response data
    func deleteDocuments(indexUid: String, documentIds: [String]) async throws -> Data {
        let jsonData = try JSONEncoder().encode(documentIds)
        return try await post("/indexes/\(indexUid)/documents/delete-batch", body: jsonData)
    }
    
    /// Delete all documents from an index
    /// - Parameter indexUid: Unique identifier of the index
    /// - Returns: Document deletion task response data
    func deleteAllDocuments(indexUid: String) async throws -> Data {
        return try await delete("/indexes/\(indexUid)/documents")
    }
    
    // MARK: - Search Operations
    
    /// Search for documents in an index
    /// - Parameters:
    ///   - indexUid: Unique identifier of the index
    ///   - query: Search query string
    ///   - options: Additional search options
    /// - Returns: Search results data
    func search(indexUid: String, query: String, options: SearchOptions? = nil) async throws -> Data {
        var searchBody: [String: Any] = ["q": query]
        
        if let options = options {
            if let limit = options.limit {
                searchBody["limit"] = limit
            }
            if let offset = options.offset {
                searchBody["offset"] = offset
            }
            if let attributesToRetrieve = options.attributesToRetrieve {
                searchBody["attributesToRetrieve"] = attributesToRetrieve
            }
            if let attributesToCrop = options.attributesToCrop {
                searchBody["attributesToCrop"] = attributesToCrop
            }
            if let cropLength = options.cropLength {
                searchBody["cropLength"] = cropLength
            }
            if let attributesToHighlight = options.attributesToHighlight {
                searchBody["attributesToHighlight"] = attributesToHighlight
            }
            if let filter = options.filter {
                searchBody["filter"] = filter
            }
            if let sort = options.sort {
                searchBody["sort"] = sort
            }
            if let facets = options.facets {
                searchBody["facets"] = facets
            }
            if let highlightPreTag = options.highlightPreTag {
                searchBody["highlightPreTag"] = highlightPreTag
            }
            if let highlightPostTag = options.highlightPostTag {
                searchBody["highlightPostTag"] = highlightPostTag
            }
            if let cropMarker = options.cropMarker {
                searchBody["cropMarker"] = cropMarker
            }
            if let showMatchesPosition = options.showMatchesPosition {
                searchBody["showMatchesPosition"] = showMatchesPosition
            }
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: searchBody)
        return try await post("/indexes/\(indexUid)/search", body: jsonData)
    }
    
    // MARK: - Task Management
    
    /// Get information about a specific task
    /// - Parameter taskId: ID of the task
    /// - Returns: Task information
    func getTask(taskId: Int) async throws -> Data {
        return try await get("/tasks/\(taskId)")
    }
    
    /// Get all tasks
    /// - Returns: List of all tasks
    func getTasks() async throws -> Data {
        return try await get("/tasks")
    }
    
    // MARK: - Private Methods

    private func findFreePort(startingFrom: Int = 52000) async -> Int? {
        for port in startingFrom..<(startingFrom + 100) {
            if await isPortFree(port) {
                return port
            }
        }
        return nil
    }
    
    private func isPortFree(_ port: Int) async -> Bool {
        return await Task {
            let sockfd = socket(AF_INET, SOCK_STREAM, 0)
            guard sockfd >= 0 else { return false }
            
            defer { close(sockfd) }
            
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = in_port_t(port).bigEndian
            addr.sin_addr.s_addr = inet_addr("127.0.0.1")
            
            let result = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(sockfd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            
            return result == 0
        }.value
    }
    
    private func createDataDirectoryIfNeeded() throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: dataPath) {
            try fileManager.createDirectory(atPath: dataPath, withIntermediateDirectories: true)
            Logger.log("Created Meilisearch data directory: \(dataPath)", log: Logger.general)
        }
    }
    
    private func startMeilisearchProcess() throws -> Bool {
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            Logger.log("Meilisearch binary not found at: \(binaryPath)", log: Logger.general)
            return false
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = [
            "--http-addr", "localhost:\(port)",
            "--db-path", dataPath,
            "--master-key", masterKey,
            "--no-analytics"
        ]
        
        // Set the current directory to a writable location
        // This prevents Meilisearch from trying to write to the app bundle
        process.currentDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        
        // Inherit environment from parent process
        process.environment = ProcessInfo.processInfo.environment
        
        Logger.log("Starting Meilisearch with arguments: \(process.arguments!.joined(separator: " "))", log: Logger.general)
        Logger.log("Using master key: \(masterKey)", log: Logger.general)
        Logger.log("Current directory: \(process.currentDirectoryURL?.path ?? "none")", log: Logger.general)
        
        // Redirect output to log files to prevent pipe hanging
        let logDir = "/tmp" // Use /tmp instead of /var/log for better permissions
        let stdoutLogPath = "\(logDir)/meilisearch_stdout.log"
        let stderrLogPath = "\(logDir)/meilisearch_stderr.log"
        
        // Create log files if they don't exist
        FileManager.default.createFile(atPath: stdoutLogPath, contents: nil, attributes: nil)
        FileManager.default.createFile(atPath: stderrLogPath, contents: nil, attributes: nil)
        
        process.standardOutput = FileHandle(forWritingAtPath: stdoutLogPath)
        process.standardError = FileHandle(forWritingAtPath: stderrLogPath)
        
        Logger.log("Meilisearch output will be logged to \(stdoutLogPath) and \(stderrLogPath)", log: Logger.general)
        
        try process.run()
        
        self.process = process
        Logger.log("Meilisearch process started with PID: \(process.processIdentifier)", log: Logger.general)
        
        return true
    }
    
    private func waitForMeilisearchReady(maxAttempts: Int = 30) async -> Bool {
        for attempt in 1...maxAttempts {
            do {
                // Try to connect to the health endpoint (no auth required)
                let data = try await getHealthCheck()
                let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                Logger.log("Meilisearch health check successful on attempt \(attempt). Response: \(responseString)", log: Logger.general)
                return true
            } catch let error as MeilisearchError {
                Logger.log("Meilisearch health check failed on attempt \(attempt): \(error.localizedDescription)", log: Logger.general)
                if attempt == maxAttempts {
                    Logger.log("Meilisearch failed to become ready after \(maxAttempts) attempts", log: Logger.general)
                } else {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                }
            } catch {
                Logger.log("Meilisearch health check failed on attempt \(attempt) with error: \(error)", log: Logger.general)
                if attempt == maxAttempts {
                    Logger.log("Meilisearch failed to become ready after \(maxAttempts) attempts", log: Logger.general)
                } else {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                }
            }
        }
        return false
    }
    
    /// Health check without authentication for server readiness check
    private func getHealthCheck() async throws -> Data {
        // Build URL directly without depending on isRunning flag
        guard port > 0 else {
            throw MeilisearchError.serverNotRunning
        }
        
        guard let url = URL(string: "http://localhost:\(port)/health") else {
            throw MeilisearchError.invalidResponse
        }
        
        Logger.log("Health check URL: \(url.absoluteString)", log: Logger.general)
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // No authentication for health check
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw MeilisearchError.invalidResponse
            }
            
            Logger.log("Health check HTTP status: \(httpResponse.statusCode)", log: Logger.general)
            
            guard 200...299 ~= httpResponse.statusCode else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw MeilisearchError.httpError(httpResponse.statusCode, errorMessage)
            }
            
            return data
            
        } catch let error as MeilisearchError {
            throw error
        } catch {
            throw MeilisearchError.networkError(error)
        }
    }
    
    private func makeRequest(path: String, method: String, body: Data?) async throws -> Data {
        guard let baseURL = serverURL else {
            throw MeilisearchError.serverNotRunning
        }
        
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(masterKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = body
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        Logger.log("Starting \(method) request to \(path) (body size: \(body?.count ?? 0) bytes) with master key: \(masterKey.prefix(8))...", log: Logger.general)
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            Logger.log("Completed \(method) request to \(path) in \(String(format: "%.2f", duration))s", log: Logger.general)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw MeilisearchError.invalidResponse
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                let duration = CFAbsoluteTimeGetCurrent() - startTime
                Logger.log("HTTP error \(httpResponse.statusCode) for \(method) request to \(path) after \(String(format: "%.2f", duration))s: \(errorMessage)", log: Logger.general)
                
                // For authentication errors, provide more specific message
                if httpResponse.statusCode == 403 {
                    Logger.log("Authentication failed - master key mismatch. Server key might be different from client key.", log: Logger.general)
                }
                
                throw MeilisearchError.httpError(httpResponse.statusCode, errorMessage)
            }
            
            return data
            
        } catch let error as MeilisearchError {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            Logger.log("Meilisearch error for \(method) request to \(path) after \(String(format: "%.2f", duration))s: \(error.localizedDescription)", log: Logger.general)
            throw error
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            let errorDescription = (error as NSError).localizedDescription
            Logger.log("Network error for \(method) request to \(path) after \(String(format: "%.2f", duration))s: \(errorDescription)", log: Logger.general)
            
            // Check if this is a timeout error
            if (error as NSError).code == NSURLErrorTimedOut {
                Logger.log("Request timed out - server may be overwhelmed. Consider reducing batch size.", log: Logger.general)
            }
            
            throw MeilisearchError.networkError(error)
        }
    }
    
    private func generateMasterKey() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<32).map { _ in letters.randomElement()! })
    }
}

// MARK: - Search Options

/// Configuration options for search queries
public struct SearchOptions {
    /// Maximum number of documents to return (default: 20)
    public let limit: Int?
    /// Number of documents to skip (default: 0)
    public let offset: Int?
    /// Document fields to include in results
    public let attributesToRetrieve: [String]?
    /// Document fields to crop for snippets
    public let attributesToCrop: [String]?
    /// Maximum length of cropped fields
    public let cropLength: Int?
    /// Document fields to highlight search terms
    public let attributesToHighlight: [String]?
    /// Filter expression to apply to search
    public let filter: String?
    /// Sort expression for results
    public let sort: [String]?
    /// Facet fields to include in results
    public let facets: [String]?
    /// HTML tag to wrap highlighted terms (start)
    public let highlightPreTag: String?
    /// HTML tag to wrap highlighted terms (end)
    public let highlightPostTag: String?
    /// String to indicate cropped text
    public let cropMarker: String?
    /// Whether to show match positions
    public let showMatchesPosition: Bool?
    
    public init(
        limit: Int? = nil,
        offset: Int? = nil,
        attributesToRetrieve: [String]? = nil,
        attributesToCrop: [String]? = nil,
        cropLength: Int? = nil,
        attributesToHighlight: [String]? = nil,
        filter: String? = nil,
        sort: [String]? = nil,
        facets: [String]? = nil,
        highlightPreTag: String? = nil,
        highlightPostTag: String? = nil,
        cropMarker: String? = nil,
        showMatchesPosition: Bool? = nil
    ) {
        self.limit = limit
        self.offset = offset
        self.attributesToRetrieve = attributesToRetrieve
        self.attributesToCrop = attributesToCrop
        self.cropLength = cropLength
        self.attributesToHighlight = attributesToHighlight
        self.filter = filter
        self.sort = sort
        self.facets = facets
        self.highlightPreTag = highlightPreTag
        self.highlightPostTag = highlightPostTag
        self.cropMarker = cropMarker
        self.showMatchesPosition = showMatchesPosition
    }
}

// MARK: - Error Types

enum MeilisearchError: LocalizedError {
    case serverNotRunning
    case invalidResponse
    case httpError(Int, String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .serverNotRunning:
            return "Meilisearch server is not running"
        case .invalidResponse:
            return "Invalid response from Meilisearch server"
        case .httpError(let status, let message):
            return "HTTP error \(status): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
