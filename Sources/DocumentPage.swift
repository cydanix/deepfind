import Foundation


/// Represents a single page of parsed PDF content
public struct DocumentPage {
    /// Page number (1-based)
    public let pageNumber: Int
    /// Extracted text content from the page
    public let text: String

    public init(pageNumber: Int, text: String) {
        self.pageNumber = pageNumber
        self.text = text
    }
}