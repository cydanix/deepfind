import Foundation


public final class LexicalReranker {

    // MARK: - Public API

    public init() {}

    /// Scores a single text against a query.
    public func lexicalScore(query: String, text: String) -> Double {
        let (qOrig, q) = tokenize(query)
        let (_, t) = tokenize(text)

        // Build set for fast membership (lowercased)
        let tset: Set<String> = Set(t)

        // Exact token overlap (lowercased)
        var overlap = 0.0
        for w in q where tset.contains(w) {
            overlap += 1.0
        }

        // Early return if empty
        guard !q.isEmpty, !t.isEmpty else { return overlap }

        // Phrase / proximity bonus (simple substring on lowercased tokens)
        let qJoined = q.joined(separator: " ")
        let tJoined = t.joined(separator: " ")
        let phraseBonus: Double = tJoined.contains(qJoined) ? 1.0 : 0.0

        // ID/code emphasis using ORIGINAL casing; membership on lowercased
        var idHits = 0.0
        for (i, wOrig) in qOrig.enumerated() where isIDToken(wOrig) {
            if tset.contains(q[i]) {
                idHits += 1.0
            }
        }

        // Length penalty (very long chunks get a tiny penalty)
        let lengthPen = log1p(Double(t.count)) / 10.0

        return overlap + 2.0 * phraseBonus + 1.5 * idHits - lengthPen
    }

    /// Reranks documents by lexical score descending.
    public func rerankLexical(query: String, docs: [DocumentChunk]) -> [DocumentChunk] {
        let scored: [(doc: DocumentChunk, score: Double)] = docs.map {
            ($0, lexicalScore(query: query, text: $0.content))
        }
        return scored.sorted { $0.score > $1.score }.map { $0.doc }
    }

    // MARK: - Internals

    /// Tokenize into Unicode letter/digit/underscore tokens.
    /// Returns parallel arrays: originals and lowercased.
    private func tokenize(_ s: String) -> (orig: [String], lower: [String]) {
        var buffer = String.UnicodeScalarView()
        var originals: [String] = []
        var lowers: [String] = []

        @inline(__always)
        func flush() {
            if !buffer.isEmpty {
                let token = String(String.UnicodeScalarView(buffer))
                originals.append(token)
                lowers.append(token.lowercased())
                buffer.removeAll(keepingCapacity: true)
            }
        }

        let letters = CharacterSet.letters
        let digits = CharacterSet.decimalDigits

        for scalar in s.unicodeScalars {
            if letters.contains(scalar) || digits.contains(scalar) || scalar == "_" {
                buffer.append(scalar)
            } else {
                flush()
            }
        }
        flush()

        return (originals, lowers)
    }

    /// Heuristic: treat as ID/code if it has any digit OR
    /// all its letters are uppercase (Unicode-aware).
    private func isIDToken(_ token: String) -> Bool {
        var hasDigit = false
        var hasLetter = false

        // Collect letters to check uppercase property
        var letterOnly = ""

        for ch in token {
            // Check digit
            if ch.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) }) {
                hasDigit = true
            }

            // Check letter
            if ch.unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) }) {
                hasLetter = true
                letterOnly.append(ch)
            }
        }

        // All letters uppercase?
        var allUpper = false
        if hasLetter {
            // Compare in a locale-independent way
            allUpper = (letterOnly == letterOnly.uppercased())
        }

        return hasDigit || (hasLetter && allUpper)
    }
}