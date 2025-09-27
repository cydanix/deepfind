import Cocoa
import SwiftUI
import Foundation

struct RAGSettings {
    // Indexing settings
    static let maxChunkSize = 1000
    static let chunkOverlap = 200
    static let supportedFileTypes = ["txt", "md", "pdf", "docx", "rtf", "html", "swift", "py", "js", "ts"]
    
    // Search settings
    static let maxSearchResults = 5
    static let similarityThreshold = 0.7
    static let enableContextualSearch = true
    
    // LLM settings
    static let maxContextLength = 4000
    static let temperature = 0.7
}

struct DefaultSettings {
    static let hasCompletedOnboarding = false
    static let maxChunkSize = RAGSettings.maxChunkSize
    static let chunkOverlap = RAGSettings.chunkOverlap
    static let maxSearchResults = RAGSettings.maxSearchResults
    static let similarityThreshold = RAGSettings.similarityThreshold
    static let enableContextualSearch = RAGSettings.enableContextualSearch
    static let maxContextLength = RAGSettings.maxContextLength
    static let temperature = RAGSettings.temperature
    static let autoRefreshIndex = true
    static let showSearchSuggestions = true
}

class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    // UserDefaults keys
    private enum Keys: String {
        case hasCompletedOnboarding = "hasCompletedOnboarding"
        case maxChunkSize = "maxChunkSize"
        case chunkOverlap = "chunkOverlap"
        case maxSearchResults = "maxSearchResults"
        case similarityThreshold = "similarityThreshold"
        case enableContextualSearch = "enableContextualSearch"
        case maxContextLength = "maxContextLength"
        case temperature = "temperature"
        case autoRefreshIndex = "autoRefreshIndex"
        case showSearchSuggestions = "showSearchSuggestions"
    }

    private let defaults = UserDefaults.standard

    @Published var hasCompletedOnboarding: Bool = false {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding.rawValue)
        }
    }
    
    @Published var maxChunkSize: Int = DefaultSettings.maxChunkSize {
        didSet {
            defaults.set(maxChunkSize, forKey: Keys.maxChunkSize.rawValue)
        }
    }
    
    @Published var chunkOverlap: Int = DefaultSettings.chunkOverlap {
        didSet {
            defaults.set(chunkOverlap, forKey: Keys.chunkOverlap.rawValue)
        }
    }
    
    @Published var maxSearchResults: Int = DefaultSettings.maxSearchResults {
        didSet {
            defaults.set(maxSearchResults, forKey: Keys.maxSearchResults.rawValue)
        }
    }
    
    @Published var similarityThreshold: Double = DefaultSettings.similarityThreshold {
        didSet {
            defaults.set(similarityThreshold, forKey: Keys.similarityThreshold.rawValue)
        }
    }
    
    @Published var enableContextualSearch: Bool = DefaultSettings.enableContextualSearch {
        didSet {
            defaults.set(enableContextualSearch, forKey: Keys.enableContextualSearch.rawValue)
        }
    }

    @Published var maxContextLength: Int = DefaultSettings.maxContextLength {
        didSet {
            defaults.set(maxContextLength, forKey: Keys.maxContextLength.rawValue)
        }
    }
    
    @Published var temperature: Double = DefaultSettings.temperature {
        didSet {
            defaults.set(temperature, forKey: Keys.temperature.rawValue)
        }
    }
    
    @Published var autoRefreshIndex: Bool = DefaultSettings.autoRefreshIndex {
        didSet {
            defaults.set(autoRefreshIndex, forKey: Keys.autoRefreshIndex.rawValue)
        }
    }
    
    @Published var showSearchSuggestions: Bool = DefaultSettings.showSearchSuggestions {
        didSet {
            defaults.set(showSearchSuggestions, forKey: Keys.showSearchSuggestions.rawValue)
        }
    }

    private init() {
        loadSettings()
    }
    
    private func loadSettings() {
        // Load values from UserDefaults with default values
        // Note: Property observers are temporarily disabled during init
        self.hasCompletedOnboarding = defaults.object(forKey: Keys.hasCompletedOnboarding.rawValue) == nil ? DefaultSettings.hasCompletedOnboarding : defaults.bool(forKey: Keys.hasCompletedOnboarding.rawValue)
        self.maxChunkSize = defaults.object(forKey: Keys.maxChunkSize.rawValue) == nil ? DefaultSettings.maxChunkSize : defaults.integer(forKey: Keys.maxChunkSize.rawValue)
        self.chunkOverlap = defaults.object(forKey: Keys.chunkOverlap.rawValue) == nil ? DefaultSettings.chunkOverlap : defaults.integer(forKey: Keys.chunkOverlap.rawValue)
        self.maxSearchResults = defaults.object(forKey: Keys.maxSearchResults.rawValue) == nil ? DefaultSettings.maxSearchResults : defaults.integer(forKey: Keys.maxSearchResults.rawValue)
        self.similarityThreshold = defaults.object(forKey: Keys.similarityThreshold.rawValue) == nil ? DefaultSettings.similarityThreshold : defaults.double(forKey: Keys.similarityThreshold.rawValue)
        self.enableContextualSearch = defaults.object(forKey: Keys.enableContextualSearch.rawValue) == nil ? DefaultSettings.enableContextualSearch : defaults.bool(forKey: Keys.enableContextualSearch.rawValue)
        self.maxContextLength = defaults.object(forKey: Keys.maxContextLength.rawValue) == nil ? DefaultSettings.maxContextLength : defaults.integer(forKey: Keys.maxContextLength.rawValue)
        self.temperature = defaults.object(forKey: Keys.temperature.rawValue) == nil ? DefaultSettings.temperature : defaults.double(forKey: Keys.temperature.rawValue)
        self.autoRefreshIndex = defaults.object(forKey: Keys.autoRefreshIndex.rawValue) == nil ? DefaultSettings.autoRefreshIndex : defaults.bool(forKey: Keys.autoRefreshIndex.rawValue)
        self.showSearchSuggestions = defaults.object(forKey: Keys.showSearchSuggestions.rawValue) == nil ? DefaultSettings.showSearchSuggestions : defaults.bool(forKey: Keys.showSearchSuggestions.rawValue)
    }
    
    // MARK: - RAG Settings Management
    
    func updateChunkSize(_ size: Int) {
        guard size >= 100 && size <= 5000 else { return }
        maxChunkSize = size
    }
    
    func updateSimilarityThreshold(_ threshold: Double) {
        guard threshold >= 0.0 && threshold <= 1.0 else { return }
        similarityThreshold = threshold
    }
    
    func updateTemperature(_ temp: Double) {
        guard temp >= 0.0 && temp <= 2.0 else { return }
        temperature = temp
    }
    
    func getSupportedFileTypes() -> [String] {
        return RAGSettings.supportedFileTypes
    }
    
    // MARK: - Reset Settings
    
    func resetToDefaults() {
        // Update published properties directly (synchronously)
        // This will trigger didSet observers which will update UserDefaults
        hasCompletedOnboarding = DefaultSettings.hasCompletedOnboarding
        maxChunkSize = DefaultSettings.maxChunkSize
        chunkOverlap = DefaultSettings.chunkOverlap
        maxSearchResults = DefaultSettings.maxSearchResults
        similarityThreshold = DefaultSettings.similarityThreshold
        enableContextualSearch = DefaultSettings.enableContextualSearch
        maxContextLength = DefaultSettings.maxContextLength
        temperature = DefaultSettings.temperature
        autoRefreshIndex = DefaultSettings.autoRefreshIndex
        showSearchSuggestions = DefaultSettings.showSearchSuggestions
        
        // Force synchronize UserDefaults to ensure persistence
        defaults.synchronize()
    }

}