import Foundation

protocol LLMProtocol {
    func process( prompt: String, text: String) async throws -> String
    func isReady() async throws -> Bool
}
