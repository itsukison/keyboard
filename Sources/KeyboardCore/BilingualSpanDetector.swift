import Foundation

public struct BilingualSpanDetector: Sendable {
    public let englishWords: Set<String>
    private let embeddedEnglishWords: [String]

    public init(englishWords: Set<String> = BilingualSpanDetector.defaultEnglishWords) {
        self.englishWords = englishWords
        self.embeddedEnglishWords = englishWords
            .filter { $0.count >= 4 }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs < rhs }
                return lhs.count > rhs.count
            }
    }

    public static let defaultEnglishWords: Set<String> = [
        // articles / pronouns / prepositions
        "a", "an", "the", "i", "you", "he", "she", "it", "we", "they", "me", "him",
        "her", "us", "them", "my", "your", "his", "its", "our", "their", "this",
        "that", "these", "those", "of", "in", "on", "at", "to", "from", "for",
        "with", "by", "as", "into", "onto", "about", "over", "under", "after",
        "before", "between", "through",
        // verbs (common)
        "is", "am", "are", "was", "were", "be", "been", "being", "have", "has",
        "had", "do", "does", "did", "will", "would", "shall", "should", "can",
        "could", "may", "might", "must", "go", "going", "come", "get", "got",
        "make", "made", "take", "took", "see", "saw", "know", "knew", "think",
        "thought", "say", "said", "tell", "want", "give", "find", "use", "work",
        "call", "try", "ask", "need", "feel", "leave", "put", "mean", "keep",
        "let", "begin", "seem", "help", "talk", "turn", "start", "show", "hear",
        "play", "run", "move", "live", "believe", "bring", "happen", "write",
        "sit", "stand", "lose", "pay", "meet", "include", "continue", "set",
        "learn", "change", "lead", "watch", "follow", "stop", "create", "speak",
        "read", "spend", "grow", "open", "walk", "win", "teach", "offer",
        // common adjectives / adverbs
        "good", "bad", "big", "small", "new", "old", "high", "low", "long",
        "short", "great", "little", "own", "other", "same", "right", "wrong",
        "different", "important", "easy", "hard", "fast", "slow", "happy",
        "sad", "amazing", "smart", "strong", "honest", "real", "true", "false",
        "early", "late", "young", "ready", "free", "full", "open", "close",
        "very", "really", "just", "only", "also", "even", "still", "back",
        "here", "there", "now", "then", "when", "where", "why", "how", "what",
        "who", "which", "all", "any", "some", "many", "much", "more", "most",
        "few", "less", "no", "not", "yes",
        // common nouns
        "time", "day", "year", "way", "thing", "man", "woman", "child", "people",
        "person", "world", "life", "hand", "part", "place", "case", "week",
        "company", "system", "program", "question", "work", "government",
        "number", "night", "point", "home", "water", "room", "mother", "area",
        "money", "story", "fact", "month", "lot", "right", "study", "book",
        "eye", "job", "word", "business", "issue", "side", "kind", "head",
        "house", "service", "friend", "father", "power", "hour", "game", "line",
        "end", "member", "law", "car", "city", "community", "name", "team",
        "minute", "idea", "kid", "body", "information", "back", "parent", "face",
        "level", "office", "door", "health", "art", "war", "history", "party",
        "result", "change", "morning", "reason", "research", "girl", "boy",
        "guy", "moment", "air", "teacher", "force", "education", "foot",
        "phone", "computer", "meeting", "email", "message", "data", "internet",
        "video", "photo", "music", "movie", "food", "lunch", "dinner",
        "breakfast", "coffee", "tea", "school", "college", "university",
        "store", "shop", "park", "train", "bus", "plane", "airport", "station",
        "hotel", "restaurant", "hospital", "doctor", "nurse", "police",
        "problem", "solution", "project", "report", "document", "love",
        // conjunctions / common bits
        "and", "or", "but", "so", "if", "because", "while", "until", "though",
        "although", "since", "yet", "nor",
        // greetings / fillers
        "hello", "hi", "hey", "ok", "okay", "thanks", "thank", "please",
        "sorry", "yeah", "yep", "nope", "wow", "oh", "uh", "um",
    ]

    private static let particles: Set<String> = [
        "wa", "ga", "wo", "o", "ni", "de", "mo", "ka", "yo", "ne", "no", "to", "e",
    ]

    private static let weakShort: Set<String> = [
        "a", "an", "as", "at", "be", "by", "do", "e", "go", "he", "hi", "i", "in",
        "is", "it", "ka", "me", "mo", "ne", "ni", "no", "o", "of", "oh", "on", "or",
        "so", "to", "uh", "um", "up", "us", "wa", "we", "wo", "ya", "yo",
    ]

    private static let standaloneKanaWeakEnglish: Set<String> = [
        "be", "he", "me", "we",
    ]

    private static let jaBigrams: [String] = [
        "shi", "tsu", "chi", "kya", "kyu", "kyo", "ryu", "ryo", "myo", "nyu",
        "gyu", "pyo", "ja", "ju", "jo",
    ]

    private static let impossibleJapaneseClusters: [String] = [
        "str", "spl", "spr", "ght", "ths", "rld", "sked", "ngth",
    ]

    private static let strongVerbEndings: [String] = [
        "mashita", "masu", "desu", "nai", "nakatta", "teiru", "teru", "shita", "suru",
    ]

    private static let loanwordHints: Set<String> = [
        "apuri", "depaato", "koohii", "konpyuuta", "meeru", "mi-tinngu",
        "mi-tingu", "miitingu", "pasokon", "sumaato", "terebi",
    ]

    // MARK: - Public API

    public func detect(_ raw: String) -> [DetectedSpan] {
        let parts = splitPreservingWhitespace(raw)
        let words = parts.compactMap { $0.isSpace ? nil : $0.text }
        if words.isEmpty {
            if raw.isEmpty { return [] }
            return [.init(raw: raw, kind: .english, kana: nil)]
        }

        // Step 1: pre-split each whitespace-token into pieces. This handles
        // no-space mixed runs like "kyounomeetingha3jini" → [kyouno, meeting,
        // ha3jini] before scoring, so each piece can be classified on its own
        // merits. Pure single-word tokens come out as one piece.
        var wordPieces: [[ScoredToken]] = []
        for word in words {
            let pieces = preSplit(word)
            let scored = pieces.map { score(piece: $0) }
            wordPieces.append(scored)
        }

        // Step 2: flatten + smooth across all pieces (neighbors cross word
        // boundaries — "we" right after "korekara" needs to see "korekara").
        var flat: [ScoredToken] = wordPieces.flatMap { $0 }
        smooth(tokens: &flat)

        // Step 3: redistribute classifications back to wordPieces.
        var cursor = 0
        for i in wordPieces.indices {
            let count = wordPieces[i].count
            wordPieces[i] = Array(flat[cursor ..< cursor + count])
            cursor += count
        }

        // Step 4: build spans walking parts. Drop spaces adjacent to Japanese.
        var spans: [DetectedSpan] = []
        var pendingSpace: String? = nil
        var wordIdx = 0

        for part in parts {
            if part.isSpace {
                pendingSpace = part.text
                continue
            }
            let pieces = wordPieces[wordIdx]
            wordIdx += 1
            guard !pieces.isEmpty else { continue }

            if let space = pendingSpace,
               let lastSpan = spans.last,
               lastSpan.kind == .english,
               pieces.first!.classification == .english {
                spans.append(.init(raw: space, kind: .english, kana: nil))
            }
            pendingSpace = nil

            for piece in pieces {
                switch piece.classification {
                case .english:
                    spans.append(.init(raw: piece.raw, kind: .english, kana: nil))
                case .japanese:
                    spans.append(.init(
                        raw: piece.clean,
                        kind: .japanese,
                        kana: Romaji.toKana(piece.clean)
                    ))
                }
            }
        }

        return mergeAdjacent(spans)
    }

    // MARK: - Tokenization

    private struct Part {
        let text: String
        let isSpace: Bool
    }

    private func splitPreservingWhitespace(_ raw: String) -> [Part] {
        var result: [Part] = []
        var current = ""
        var currentIsSpace: Bool? = nil
        for ch in raw {
            let isSp = ch.isWhitespace
            if currentIsSpace == nil {
                currentIsSpace = isSp
            } else if currentIsSpace != isSp {
                result.append(Part(text: current, isSpace: currentIsSpace!))
                current = ""
                currentIsSpace = isSp
            }
            current.append(ch)
        }
        if !current.isEmpty, let isSp = currentIsSpace {
            result.append(Part(text: current, isSpace: isSp))
        }
        return result
    }

    private struct Piece {
        let raw: String       // preserves original case for passthrough
        let clean: String     // lowercased, normalized
        let explicitEnglish: Bool   // matched the embedded-English dictionary
    }

    /// Split a whitespace-token into JP/EN pieces. Tokens with uppercase letters
    /// (proper nouns / sentence start / user emphasis) are kept whole — we don't
    /// look for embedded English inside, since uppercase is a strong English
    /// signal on its own.
    private func preSplit(_ word: String) -> [Piece] {
        if word.contains(where: { $0.isUppercase }) {
            return [Piece(raw: word, clean: word.lowercased(), explicitEnglish: false)]
        }
        let lower = word.lowercased()
        let lowerChars = Array(lower)
        var pieces: [Piece] = []
        var japaneseBuffer = ""
        var index = 0

        while index < lowerChars.count {
            let suffix = String(lowerChars[index...])
            if let match = embeddedEnglishWords.first(where: { suffix.hasPrefix($0) }) {
                if !japaneseBuffer.isEmpty {
                    pieces.append(Piece(raw: japaneseBuffer, clean: japaneseBuffer, explicitEnglish: false))
                    japaneseBuffer = ""
                }
                pieces.append(Piece(raw: match, clean: match, explicitEnglish: true))
                index += match.count
            } else {
                japaneseBuffer.append(lowerChars[index])
                index += 1
            }
        }
        if !japaneseBuffer.isEmpty {
            pieces.append(Piece(raw: japaneseBuffer, clean: japaneseBuffer, explicitEnglish: false))
        }

        // No split happened — preserve original case rather than the lowered form.
        if pieces.count == 1 && !pieces[0].explicitEnglish {
            return [Piece(raw: word, clean: lower, explicitEnglish: false)]
        }
        return pieces
    }

    // MARK: - Scoring

    private struct ScoredToken {
        var raw: String
        var clean: String
        var hasUppercase: Bool
        var ja: Double
        var en: Double
        var kanaComplete: Bool
        var moraCount: Int
        var englishHit: Bool
        var explicitEnglish: Bool
        var classification: SpanKind

        var margin: Double { ja - en }
        var likelyJapanese: Bool { ja - en >= 1.2 }
        var likelyEnglish: Bool { en - ja >= 1.0 }
    }

    private func score(piece: Piece) -> ScoredToken {
        let clean = piece.clean
        let hasUppercase = piece.raw.contains(where: { $0.isUppercase })
        let englishHit = englishWords.contains(clean)
        let kana = parseRomaji(clean)
        var ja: Double = 0
        var en: Double = 0

        if piece.explicitEnglish {
            // Pre-split match in the embedded-English dictionary — definitively
            // English. Boost so smoothing can't flip it.
            en += 5.0
        }

        if isTimeSuffix(clean) {
            ja += 1.8
        }

        if kana.complete {
            ja += clean.count <= 2 ? 0.4 : 1.1
            if kana.moraCount >= 3 { ja += 0.7 }
            if clean.count >= 8 && !englishHit { ja += 1.7 }
        } else {
            en += 1.5
        }

        if Self.loanwordHints.contains(clean) || clean.contains("-") {
            if kana.complete { ja += 1.5 }
        }

        if Self.jaBigrams.contains(where: { clean.contains($0) }) && kana.complete {
            ja += 0.8
        }

        if hasDoubleConsonant(clean) && kana.complete {
            ja += 0.5
        }

        if Self.strongVerbEndings.contains(where: { clean.hasSuffix($0) })
            && kana.complete && clean.count > 4 {
            ja += 0.9
        }

        if englishHit {
            en += clean.count <= 2 ? 1.0 : 2.5
        }

        if clean.contains("'") {
            en += 1.6
        }

        if hasUppercase {
            en += 0.8
        }

        if Self.impossibleJapaneseClusters.contains(where: { clean.contains($0) }) {
            en += 1.6
        }

        if (clean.hasSuffix("ing") || clean.hasSuffix("ed") || clean.hasSuffix("ly"))
            && englishHit {
            en += 0.7
        }

        return ScoredToken(
            raw: piece.raw,
            clean: clean,
            hasUppercase: hasUppercase,
            ja: ja,
            en: en,
            kanaComplete: kana.complete,
            moraCount: kana.moraCount,
            englishHit: englishHit,
            explicitEnglish: piece.explicitEnglish,
            classification: .japanese
        )
    }

    private func smooth(tokens: inout [ScoredToken]) {
        for idx in tokens.indices {
            // Pre-split English matches are immutable — skip neighbor smoothing.
            if tokens[idx].explicitEnglish { continue }

            let leftRange = max(0, idx - 2) ..< idx
            let rightRange = (idx + 1) ..< min(tokens.count, idx + 3)
            let neighbors = Array(tokens[leftRange]) + Array(tokens[rightRange])
            let prev = idx > 0 ? tokens[idx - 1] : nil
            let next = idx + 1 < tokens.count ? tokens[idx + 1] : nil
            let jaNeighbors = neighbors.filter { $0.likelyJapanese }.count
            let enNeighbors = neighbors.filter { $0.likelyEnglish }.count
            let isAmbiguous = Self.weakShort.contains(tokens[idx].clean)
                || abs(tokens[idx].margin) < 1.2

            let englishSide = (prev?.likelyEnglish ?? false)
                || (next?.likelyEnglish ?? false)
                || enNeighbors >= 2
            let japaneseSide = (prev?.likelyJapanese ?? false)
                || (next?.likelyJapanese ?? false)
                || jaNeighbors >= 2

            // Standalone short kana ("we", "be", "he", "me") — virtually never
            // standalone Japanese. Any English-side signal trumps Japanese.
            if Self.standaloneKanaWeakEnglish.contains(tokens[idx].clean)
                && tokens[idx].englishHit
                && englishSide {
                tokens[idx].en += 2.5
            }

            // Particle inside a Japanese run → pull JP. Particle inside a clear
            // English run → pull EN.
            if Self.particles.contains(tokens[idx].clean) && isAmbiguous {
                if let p = prev, p.likelyJapanese {
                    tokens[idx].ja += 1.2
                }
                if jaNeighbors > 0 {
                    tokens[idx].ja += 1.4
                }
                if enNeighbors >= 2 && !japaneseSide {
                    tokens[idx].en += 1.6
                }
            }

            if isAmbiguous && jaNeighbors >= 2 {
                tokens[idx].ja += 1.2
            }
            if isAmbiguous && enNeighbors >= 2 && !japaneseSide {
                tokens[idx].en += 1.2
            }

            // Lower-bar English pull: short ambiguous dictionary tokens with at
            // least one clearly-English neighbor and no Japanese neighbors.
            if isAmbiguous
                && tokens[idx].englishHit
                && enNeighbors >= 1
                && jaNeighbors == 0
                && !(prev?.likelyJapanese ?? false) {
                tokens[idx].en += 1.5
            }
        }

        // Reinforce 3+ token kana-valid Japanese runs.
        var start = 0
        while start < tokens.count {
            var end = start
            while end < tokens.count
                && tokens[end].kanaComplete
                && !tokens[end].englishHit
                && !tokens[end].explicitEnglish {
                end += 1
            }
            if end - start >= 3 {
                for i in start ..< end {
                    tokens[i].ja += 0.9
                }
            }
            start = max(start + 1, end)
        }

        for idx in tokens.indices {
            tokens[idx].classification = classify(ja: tokens[idx].ja, en: tokens[idx].en)
        }
    }

    /// Default to Japanese on borderline cases — the user is on a Japanese-
    /// friendly keyboard, so converting and letting them backspace is the
    /// better default than passing romaji through.
    private func classify(ja: Double, en: Double) -> SpanKind {
        let margin = ja - en
        if margin <= -1.1 && en >= 1.4 { return .english }
        return .japanese
    }

    // MARK: - Helpers

    private struct KanaParse {
        let kana: String
        let complete: Bool
        let moraCount: Int
    }

    private func parseRomaji(_ clean: String) -> KanaParse {
        let chars = Array(clean)
        if chars.isEmpty { return KanaParse(kana: "", complete: false, moraCount: 0) }

        var i = 0
        var output = ""
        var moraCount = 0
        var complete = true
        let vowels = Romaji.vowels
        let consonants = Romaji.consonants

        while i < chars.count {
            let c = chars[i]
            let next: Character = i + 1 < chars.count ? chars[i + 1] : "\0"

            if c == "-" || c.isNumber || c == "'" {
                i += 1
                continue
            }
            if c == "n", next == "'" || next == "n" {
                output += "ん"
                moraCount += 1
                i += 2
                continue
            }
            if c == "n", next != "\0", !vowels.contains(next), next != "y" {
                output += "ん"
                moraCount += 1
                i += 1
                continue
            }
            if consonants.contains(c), c == next, c != "n" {
                output += "っ"
                i += 1
                continue
            }

            var matched = false
            for length in [3, 2, 1] where i + length <= chars.count {
                let piece = String(chars[i ..< i + length])
                if let kana = Romaji.kanaTable[piece] {
                    output += kana
                    moraCount += 1
                    i += length
                    matched = true
                    break
                }
            }
            if !matched {
                complete = false
                i += 1
            }
        }

        return KanaParse(kana: output, complete: complete && moraCount > 0, moraCount: moraCount)
    }

    private func isTimeSuffix(_ clean: String) -> Bool {
        guard clean.hasSuffix("ji") else { return false }
        let prefix = clean.dropLast(2)
        return !prefix.isEmpty && prefix.allSatisfy { $0.isNumber }
    }

    private func hasDoubleConsonant(_ clean: String) -> Bool {
        let chars = Array(clean)
        for i in 1 ..< chars.count {
            let prev = chars[i - 1]
            let curr = chars[i]
            if prev == curr,
               Romaji.consonants.contains(prev),
               prev != "l", prev != "e", prev != "o" {
                return true
            }
        }
        return false
    }

    private func mergeAdjacent(_ spans: [DetectedSpan]) -> [DetectedSpan] {
        var result: [DetectedSpan] = []
        for span in spans {
            guard let last = result.last else {
                result.append(span)
                continue
            }
            if last.kind == .english && span.kind == .english {
                result[result.count - 1] = .init(
                    raw: last.raw + span.raw,
                    kind: .english,
                    kana: nil
                )
            } else if last.kind == .japanese && span.kind == .japanese {
                let merged = last.raw + span.raw
                result[result.count - 1] = .init(
                    raw: merged,
                    kind: .japanese,
                    kana: Romaji.toKana(merged)
                )
            } else {
                result.append(span)
            }
        }
        return result
    }
}
