import Cocoa
import SwiftUI
import Foundation

struct RAGSettings {
    static let supportedFileTypes = ["txt", "md", "pdf", "docx", "rtf", "html", "swift", "py", "js", "ts"]
}

struct DefaultSettings {
    static let hasCompletedOnboarding = false
    static let contextSize = 10000
}

class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    // UserDefaults keys
    private enum Keys: String {
        case hasCompletedOnboarding = "hasCompletedOnboarding"
        case contextSize = "contextSize"
    }

    private let defaults = UserDefaults.standard

    @Published var hasCompletedOnboarding: Bool = false {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding.rawValue)
        }
    }
    
    @Published var contextSize: Int = DefaultSettings.contextSize {
        didSet {
            defaults.set(contextSize, forKey: Keys.contextSize.rawValue)
        }
    }

    private init() {
        loadSettings()
    }
    
    private func loadSettings() {
        // Load values from UserDefaults with default values
        // Note: Property observers are temporarily disabled during init
        self.hasCompletedOnboarding = defaults.object(forKey: Keys.hasCompletedOnboarding.rawValue) == nil ? DefaultSettings.hasCompletedOnboarding : defaults.bool(forKey: Keys.hasCompletedOnboarding.rawValue)
        self.contextSize = defaults.object(forKey: Keys.contextSize.rawValue) == nil ? DefaultSettings.contextSize : defaults.integer(forKey: Keys.contextSize.rawValue)
    }
    
    // MARK: - File Types Management
    
    func getSupportedFileTypes() -> [String] {
        return RAGSettings.supportedFileTypes
    }
    
    // MARK: - Reset Settings
    
    func resetToDefaults() {
        // Update published properties directly (synchronously)
        // This will trigger didSet observers which will update UserDefaults
        hasCompletedOnboarding = DefaultSettings.hasCompletedOnboarding
        contextSize = DefaultSettings.contextSize
        
        // Force synchronize UserDefaults to ensure persistence
        defaults.synchronize()
    }

}