import Foundation
import PDFKit
import Combine

// MARK: - Data Models

/// Represents a parsed PDF document with lazy page loading for memory efficiency
public class PdfDocument {
    /// Original file URL
    public let fileURL: URL
    /// File name
    public let fileName: String
    /// File size in bytes
    public let fileSize: Int64
    /// Document title (from PDF metadata)
    public let title: String?
    /// Document author (from PDF metadata)
    public let author: String?
    /// Document subject (from PDF metadata)
    public let subject: String?
    /// Document creation date
    public let creationDate: Date?
    /// Total number of pages
    public let totalPages: Int
    
    // Private properties for lazy loading
    private let pdfDocument: PDFDocument
    private var cachedPages: [Int: DocumentPage] = [:]
    private let cacheQueue = DispatchQueue(label: "pdf.page.cache", attributes: .concurrent)
    
    public init(fileURL: URL, pdfDocument: PDFDocument) {
        self.fileURL = fileURL
        self.fileName = fileURL.lastPathComponent
        self.pdfDocument = pdfDocument
        
        // Get file size
        let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        self.fileSize = (fileAttributes?[.size] as? Int64) ?? 0
        
        // Extract metadata
        let documentAttributes = pdfDocument.documentAttributes
        self.title = documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String
        self.author = documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String
        self.subject = documentAttributes?[PDFDocumentAttribute.subjectAttribute] as? String
        self.creationDate = documentAttributes?[PDFDocumentAttribute.creationDateAttribute] as? Date
        
        self.totalPages = pdfDocument.pageCount
    }
    
    /// Get a specific page, loading it lazily if needed
    /// - Parameter pageNumber: Page number (1-based)
    /// - Returns: The requested page, or nil if not found
    public func page(at pageNumber: Int) -> DocumentPage? {
        guard pageNumber >= 1 && pageNumber <= totalPages else { return nil }
        
        return cacheQueue.sync {
            // Check cache first
            if let cachedPage = cachedPages[pageNumber] {
                return cachedPage
            }
            
            // Load page from PDF
            guard let pdfPage = pdfDocument.page(at: pageNumber - 1) else { return nil }
            let text = pdfPage.string ?? ""
            let page = DocumentPage(pageNumber: pageNumber, text: text)
            
            // Cache the page
            cachedPages[pageNumber] = page
            
            return page
        }
    }
    
    /// Get pages within a specific range
    /// - Parameter range: Range of page numbers (1-based)
    /// - Returns: Array of pages within the range
    public func pages(in range: Range<Int>) -> [DocumentPage] {
        return range.compactMap { page(at: $0) }
    }
    
    /// Get all pages (use with caution for large documents)
    public var allPages: [DocumentPage] {
        return (1...totalPages).compactMap { page(at: $0) }
    }
    
    /// Get pages that contain meaningful content (lazily evaluated)
    public var contentPages: [DocumentPage] {
        return allPages.filter { $0.hasContent }
    }
    
    /// Clear the page cache to free memory
    public func clearPageCache() {
        cacheQueue.async(flags: .barrier) {
            self.cachedPages.removeAll()
        }
    }
    
    /// Get the number of cached pages
    public var cachedPageCount: Int {
        return cacheQueue.sync { cachedPages.count }
    }
}

// MARK: - Error Types

public enum PdfParserError: LocalizedError {
    case fileNotFound
    case invalidPdfFile
    case unreadablePdf
    case emptyDocument
    case processingError(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "PDF file not found"
        case .invalidPdfFile:
            return "Invalid or corrupted PDF file"
        case .unreadablePdf:
            return "PDF file cannot be read or is password-protected"
        case .emptyDocument:
            return "PDF document contains no readable content"
        case .processingError(let message):
            return "PDF processing error: \(message)"
        }
    }
}

// MARK: - PDF Parser

/// Parses PDF files into structured text content suitable for RAG and LLM processing
@MainActor
public class PdfParser: ObservableObject {
    
    @Published public var isProcessing: Bool = false
    @Published public var processingProgress: Double = 0.0
    
    public static let shared = PdfParser()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Parse a PDF file and extract its content
    /// - Parameter fileURL: URL of the PDF file to parse
    /// - Returns: Parsed PDF document with structured content
    /// - Throws: PdfParserError if parsing fails
    public func parsePdf(at fileURL: URL) async throws -> PdfDocument {
        Logger.log("Starting PDF parsing for file: \(fileURL.lastPathComponent)", log: Logger.general)
        
        isProcessing = true
        processingProgress = 0.0
        
        defer {
            isProcessing = false
            processingProgress = 0.0
        }
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw PdfParserError.fileNotFound
        }
        
        // Create PDFDocument
        guard let pdfDocument = PDFDocument(url: fileURL) else {
            throw PdfParserError.invalidPdfFile
        }
        
        // Check if document has pages
        let pageCount = pdfDocument.pageCount
        guard pageCount > 0 else {
            throw PdfParserError.emptyDocument
        }
        
        Logger.log("PDF has \(pageCount) pages", log: Logger.general)
        
        // Create document with lazy loading - no need to process all pages upfront
        let document = PdfDocument(fileURL: fileURL, pdfDocument: pdfDocument)
        
        // Validate that at least the first page can be read
        guard let firstPage = document.page(at: 1), firstPage.text.count > 0 else {
            throw PdfParserError.unreadablePdf
        }
        
        // Update progress to complete
        processingProgress = 1.0
        
        Logger.log("PDF parsing completed. Total pages: \(document.totalPages) (lazy loading enabled)", log: Logger.general)
        
        return document
    }
    
    /// Parse multiple PDF files
    /// - Parameter fileURLs: Array of PDF file URLs to parse
    /// - Returns: Array of parsed PDF documents
    /// - Throws: PdfParserError if any parsing fails
    public func parsePdfs(at fileURLs: [URL]) async throws -> [PdfDocument] {
        var documents: [PdfDocument] = []
        
        for (index, fileURL) in fileURLs.enumerated() {
            do {
                let document = try await parsePdf(at: fileURL)
                documents.append(document)
                Logger.log("Successfully parsed PDF \(index + 1)/\(fileURLs.count): \(fileURL.lastPathComponent)", log: Logger.general)
            } catch {
                Logger.log("Failed to parse PDF: \(fileURL.lastPathComponent) - \(error.localizedDescription)", log: Logger.general)
                // Continue with other files instead of failing completely
            }
        }
        
        return documents
    }
    
    // MARK: - Static Utility Methods
    
    /// Check if a file is a PDF based on its extension
    /// - Parameter fileURL: File URL to check
    /// - Returns: True if the file has a PDF extension
    nonisolated public static func isPdfFile(_ fileURL: URL) -> Bool {
        return fileURL.pathExtension.lowercased() == "pdf"
    }
    
    /// Clean and format text for RAG/LLM processing
    /// - Parameter text: Raw text to clean
    /// - Returns: Cleaned and formatted text
    nonisolated public static func cleanText(_ text: String) -> String {
        var cleaned = text
        
        // Remove excessive whitespace and normalize line breaks
        cleaned = cleaned.replacingOccurrences(of: "\r\n", with: "\n")
        cleaned = cleaned.replacingOccurrences(of: "\r", with: "\n")
        
        // Remove multiple consecutive newlines (keep maximum 2)
        cleaned = cleaned.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        
        // Remove multiple consecutive spaces
        cleaned = cleaned.replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
        
        // Remove leading/trailing whitespace from each line
        let lines = cleaned.components(separatedBy: "\n")
        let trimmedLines = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        cleaned = trimmedLines.joined(separator: "\n")
        
        // Remove empty lines at the beginning and end
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Fix common PDF extraction issues
        cleaned = fixCommonPdfIssues(cleaned)
        
        return cleaned
    }
    
    /// Count words in text
    /// - Parameter text: Text to count words in
    /// - Returns: Number of words
    nonisolated public static func countWords(in text: String) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }
    
    // MARK: - Private Methods
    
    
    /// Fix common issues that occur during PDF text extraction
    /// - Parameter text: Text to fix
    /// - Returns: Text with common issues corrected
    nonisolated private static func fixCommonPdfIssues(_ text: String) -> String {
        var fixed = text
        
        // Fix broken words (letters separated by spaces)
        // This is a common issue in PDF extraction where "hello" becomes "h e l l o"
        fixed = fixed.replacingOccurrences(of: "([a-zA-Z])\\s+([a-zA-Z])\\s+([a-zA-Z])", 
                                         with: "$1$2$3", 
                                         options: .regularExpression)
        
        // Fix hyphenated words at line breaks
        fixed = fixed.replacingOccurrences(of: "-\\s*\n\\s*", with: "", options: .regularExpression)
        
        // Fix bullet points and special characters
        fixed = fixed.replacingOccurrences(of: "•", with: "• ")
        fixed = fixed.replacingOccurrences(of: "◦", with: "◦ ")
        fixed = fixed.replacingOccurrences(of: "▪", with: "▪ ")
        
        // Ensure proper spacing after periods
        fixed = fixed.replacingOccurrences(of: "\\.([A-Z])", with: ". $1", options: .regularExpression)
        
        // Remove page numbers at the end of pages (simple heuristic)
        let lines = fixed.components(separatedBy: "\n")
        let filteredLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // Remove lines that are just numbers (likely page numbers)
            return !(trimmed.count <= 3 && Int(trimmed) != nil)
        }
        fixed = filteredLines.joined(separator: "\n")
        
        return fixed
    }
}

// MARK: - Extensions

extension PdfDocument {
    /// Get text content for specific pages
    /// - Parameter pageNumbers: Array of page numbers (1-based)
    /// - Returns: Combined text from specified pages
    public func text(for pageNumbers: [Int]) -> String {
        let texts = pageNumbers.compactMap { pageNumber in
            page(at: pageNumber)?.cleanedText
        }
        return texts.joined(separator: "\n\n")
    }
    
    /// Create an iterator for processing pages one by one
    /// - Returns: Page iterator
    public func makePageIterator() -> PdfPageIterator {
        return PdfPageIterator(document: self)
    }
    
    /// Process pages using a closure, ideal for streaming/lazy processing
    /// - Parameter processor: Closure that processes each page
    public func forEachPage(_ processor: (DocumentPage) throws -> Void) rethrows {
        for pageNumber in 1...totalPages {
            if let page = page(at: pageNumber) {
                try processor(page)
            }
        }
    }
    
    /// Process content pages only (pages with meaningful content)
    /// - Parameter processor: Closure that processes each content page
    public func forEachContentPage(_ processor: (DocumentPage) throws -> Void) rethrows {
        for pageNumber in 1...totalPages {
            if let page = page(at: pageNumber), page.hasContent {
                try processor(page)
            }
        }
    }
    
    /// Process pages in a specific range using a closure
    /// - Parameters:
    ///   - range: Range of page numbers (1-based)
    ///   - processor: Closure that processes each page
    public func forEachPage(in range: Range<Int>, processor: (DocumentPage) throws -> Void) rethrows {
        for pageNumber in range {
            if let page = page(at: pageNumber) {
                try processor(page)
            }
        }
    }
}

/// Iterator for processing PDF pages one by one with lazy loading
public struct PdfPageIterator: IteratorProtocol, Sequence {
    private weak var document: PdfDocument?
    private var currentPageNumber: Int = 1
    
    init(document: PdfDocument) {
        self.document = document
    }
    
    public mutating func next() -> DocumentPage? {
        guard let document = document,
              currentPageNumber <= document.totalPages else { return nil }
        
        let page = document.page(at: currentPageNumber)
        currentPageNumber += 1
        return page
    }
    
    /// Reset iterator to the beginning
    public mutating func reset() {
        currentPageNumber = 1
    }
    
    /// Get the current position in the iteration (1-based page number)
    public var currentPosition: Int {
        return currentPageNumber
    }
    
    /// Get the total number of pages
    public var totalPages: Int {
        return document?.totalPages ?? 0
    }
    
    /// Check if there are more pages to iterate
    public var hasNext: Bool {
        guard let document = document else { return false }
        return currentPageNumber <= document.totalPages
    }
    
    /// Skip to a specific page number
    /// - Parameter pageNumber: Page number to skip to (1-based)
    public mutating func skipTo(pageNumber: Int) {
        currentPageNumber = Swift.max(1, pageNumber)
    }
}

