import Foundation


/// Represents a single page of parsed PDF content
public struct DocumentPage {
    /// Page number (1-based)
    public let pageNumber: Int
    /// Extracted text content from the page
    public let text: String
    /// Cleaned and formatted text suitable for RAG
    public let cleanedText: String
    /// Word count of the cleaned text
    public let wordCount: Int
    /// Character count of the cleaned text
    public let characterCount: Int
    /// Indicates if this page contains meaningful content
    public let hasContent: Bool
    
    public init(pageNumber: Int, text: String) {
        self.pageNumber = pageNumber
        self.text = text
        self.cleanedText = PdfParser.cleanText(text)
        self.wordCount = PdfParser.countWords(in: cleanedText)
        self.characterCount = cleanedText.count
        self.hasContent = wordCount > 5 // Consider pages with more than 5 words as meaningful
    }
}