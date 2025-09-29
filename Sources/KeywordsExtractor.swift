import Foundation

public final class KeywordsExtractor {
    // MARK: - Public API
    public init() {}

    /// Returns keywords from the query with punctuation removed and stopwords filtered.
    /// Language is auto-detected between "en".
    public func getQueryKeywords(_ query: String) -> [String] {
        // lowercase first (Unicode-aware)
        let lower = query.lowercased()

        // detect language
        let lang = Self.detectLang(lower)

        // replace non-alphanumeric (keeping latin and digits) with spaces
        let cleaned = Self.nonAlphanumericRegex.stringByReplacingMatches(
            in: lower,
            options: [],
            range: NSRange(lower.startIndex..<lower.endIndex, in: lower),
            withTemplate: " "
        )

        // split on whitespace
        let words = cleaned.split(whereSeparator: { $0.isWhitespace }).map { String($0) }

        // choose stopwords
        let stop: Set<String> = (lang == "en") ? Self.englishStopWords : Self.englishStopWords

        // filter; keep order, do not deduplicate (mirrors your Go)
        var keywords: [String] = []
        keywords.reserveCapacity(words.count)
        for w in words where !w.isEmpty && !stop.contains(w) {
            keywords.append(w)
        }
        return keywords
    }

    // MARK: - Language detection (very lightweight)
    /// Always returns English for this English-only implementation.
    static func detectLang(_ s: String) -> String {
        return "en"
    }

    // MARK: - Regex
    /// Matches any character that is NOT: latin a–z or digit 0–9 (case-insensitive).
    private static let nonAlphanumericRegex: NSRegularExpression = {
        // Using explicit ranges for safety; add A-Z via caseInsensitive option.
        let pattern = "[^a-z0-9]+"
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    // MARK: - Stopwords (English)
    private static let englishStopWords: Set<String> = [
        // Articles
        "a","an","the",
        // Conjunctions
        "and","but","or","nor","for","yet","so","as","because","however","though","although","until","while",
        // Prepositions
        "in","on","at","to","for","with","by","from","up","down","over","under","into","onto","upon","of","off",
        // Pronouns
        "i","you","he","she","it","we","they","me","him","her","us","them",
        "my","your","his","its","our","their","this","that","these","those",
        // Be verbs
        "am","is","are","was","were","be","been","being",
        // Common verbs & modals
        "do","does","did","have","has","had","will","would","should","could","can","might","must","shall",
        // Question words
        "what","when","where","why","how","which","who","whom",
        // Quantities and numbers
        "all","any","both","each","few","many","some","one","two","three","four","five","first","second","third","once","twice",
        // Common filler/adverbial words
        "please","about","then","there","here","just","very","really","also","too","again","still","such","like",
        // Query-specific words
        "tell","explain","describe","write","know","everything","give"
    ]

}