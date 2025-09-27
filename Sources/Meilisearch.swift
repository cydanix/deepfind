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
        
        // Configure URL session with timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.urlSession = URLSession(configuration: config)
        
        // Generate a random master key
        self.masterKey = generateMasterKey()
        
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
    
    // MARK: - Private Methods
    
    private func findFreePort(startingFrom: Int = 7700) async -> Int? {
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
        
        Logger.log("Starting Meilisearch with arguments: \(process.arguments!.joined(separator: " "))", log: Logger.general)
        
        // For debugging: capture output instead of redirecting to null
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        
        self.process = process
        Logger.log("Meilisearch process started with PID: \(process.processIdentifier)", log: Logger.general)
        
        // Monitor process output asynchronously
        DispatchQueue.global().async {
            // Give the process a moment to start
            Thread.sleep(forTimeInterval: 0.1)
            
            let outputData = outputPipe.fileHandleForReading.availableData
            if !outputData.isEmpty {
                let output = String(data: outputData, encoding: .utf8) ?? "Unable to decode output"
                Logger.log("Meilisearch stdout: \(output)", log: Logger.general)
            }
            
            let errorData = errorPipe.fileHandleForReading.availableData  
            if !errorData.isEmpty {
                let error = String(data: errorData, encoding: .utf8) ?? "Unable to decode error"
                Logger.log("Meilisearch stderr: \(error)", log: Logger.general)
            }
            
            // Check if process is still running
            if let process = self.process, !process.isRunning {
                Logger.log("Meilisearch process terminated unexpectedly with exit code: \(process.terminationStatus)", log: Logger.general)
            }
        }
        
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
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw MeilisearchError.invalidResponse
            }
            
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
    
    private func generateMasterKey() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<32).map { _ in letters.randomElement()! })
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
