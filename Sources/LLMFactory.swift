import Foundation

@MainActor
class LLMFactory {
    static func createLLM() -> LLMProtocol {
        return LLM.shared
    }
}
