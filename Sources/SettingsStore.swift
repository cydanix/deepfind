import Cocoa
import SwiftUI
import Foundation

struct RAGSettings {
    static let supportedFileTypes = ["txt", "md", "pdf", "docx", "rtf", "html", "swift", "py", "js", "ts"]
}

struct DefaultSettings {
    static let hasCompletedOnboarding = false
}

class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    // UserDefaults keys
    private enum Keys: String {
        case hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    private let defaults = UserDefaults.standard

    @Published var hasCompletedOnboarding: Bool = false {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding.rawValue)
        }
    }

    private init() {
        loadSettings()
    }
    
    private func loadSettings() {
        // Load values from UserDefaults with default values
        // Note: Property observers are temporarily disabled during init
        self.hasCompletedOnboarding = defaults.object(forKey: Keys.hasCompletedOnboarding.rawValue) == nil ? DefaultSettings.hasCompletedOnboarding : defaults.bool(forKey: Keys.hasCompletedOnboarding.rawValue)
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
        
        // Force synchronize UserDefaults to ensure persistence
        defaults.synchronize()
    }

}