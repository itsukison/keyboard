import Foundation

public enum BilingualLanguage: Equatable, Sendable {
    case english
    case japanese
}

public struct BilingualSpan: Equatable, Sendable {
    public let raw: String
    public let language: BilingualLanguage
    public let kana: String?

    public init(raw: String, language: BilingualLanguage, kana: String?) {
        self.raw = raw
        self.language = language
        self.kana = kana
    }
}

public struct BilingualLanguageClassifier: Sendable {
    public var englishWords: Set<String>
    private let embeddedEnglishWords: [String]

    public init(
        englishWords: Set<String> = Self.defaultEnglishWords,
        embeddedEnglishMinimumWordLength: Int = 4
    ) {
        self.englishWords = englishWords
        self.embeddedEnglishWords = englishWords
            .filter { $0.count >= embeddedEnglishMinimumWordLength }
            .sorted { lhs, rhs in
                lhs.count == rhs.count ? lhs < rhs : lhs.count > rhs.count
            }
    }

    public func spans(in token: String, contextBefore: String = "") -> [BilingualSpan] {
        let pieces = preSplit(token)
        let contextBias = japaneseBias(from: contextBefore)
        return mergeAdjacent(pieces.map { piece in
            let language = classify(piece, contextBias: contextBias)
            return BilingualSpan(
                raw: piece.raw,
                language: language,
                kana: language == .japanese ? JapaneseRomaji.toKana(piece.clean) : nil
            )
        })
    }

    public func likelyLanguage(of token: String, contextBefore: String = "") -> BilingualLanguage {
        let spans = spans(in: token, contextBefore: contextBefore)
        let japaneseCount = spans.filter { $0.language == .japanese }.map(\.raw.count).reduce(0, +)
        let englishCount = spans.filter { $0.language == .english }.map(\.raw.count).reduce(0, +)
        return japaneseCount > englishCount ? .japanese : .english
    }

    private struct Piece {
        let raw: String
        let clean: String
        let explicitEnglish: Bool
    }

    private func preSplit(_ token: String) -> [Piece] {
        guard token.contains(where: { $0.isUppercase }) == false else {
            return [Piece(raw: token, clean: token.lowercased(), explicitEnglish: false)]
        }

        let chars = Array(token.lowercased())
        var pieces: [Piece] = []
        var japaneseBuffer = ""
        var index = 0

        while index < chars.count {
            let suffix = String(chars[index...])
            if let match = embeddedEnglishWords.first(where: { suffix.hasPrefix($0) }) {
                if !japaneseBuffer.isEmpty {
                    pieces.append(Piece(raw: japaneseBuffer, clean: japaneseBuffer, explicitEnglish: false))
                    japaneseBuffer = ""
                }
                pieces.append(Piece(raw: match, clean: match, explicitEnglish: true))
                index += match.count
            } else {
                japaneseBuffer.append(chars[index])
                index += 1
            }
        }

        if !japaneseBuffer.isEmpty {
            pieces.append(Piece(raw: japaneseBuffer, clean: japaneseBuffer, explicitEnglish: false))
        }
        if pieces.count == 1, !pieces[0].explicitEnglish {
            return [Piece(raw: token, clean: token.lowercased(), explicitEnglish: false)]
        }
        return pieces
    }

    private func classify(_ piece: Piece, contextBias: Double) -> BilingualLanguage {
        if piece.explicitEnglish { return .english }

        let clean = piece.clean
        let parse = JapaneseRomaji.parse(clean)
        let englishHit = englishWords.contains(clean)
        if englishHit, clean.count <= 2, Self.weakShortEnglish.contains(clean), contextBias <= 0 {
            return .english
        }
        var ja = contextBias
        var en = 0.0

        if parse.isComplete {
            ja += clean.count <= 2 ? 0.4 : 1.2
            if parse.moraCount >= 3 { ja += 0.8 }
            if clean.count >= 8 && !englishHit { ja += 1.6 }
        } else {
            en += 1.7
        }

        if Self.particles.contains(clean), parse.isComplete {
            ja += 1.1
        }
        if isTimeSuffix(clean) {
            ja += 1.8
        }
        if Self.japaneseEndings.contains(where: { clean.hasSuffix($0) }), clean.count >= 5, parse.isComplete {
            ja += 1.0
        }
        if Self.japaneseBigrams.contains(where: { clean.contains($0) }), parse.isComplete {
            ja += 0.7
        }
        if hasDoubleConsonant(clean), parse.isComplete {
            ja += 0.4
        }

        if englishHit {
            en += clean.count <= 2 ? 1.0 : 2.6
            if clean.count >= 4 { en += 1.8 }
            if clean.count >= 8 { en += 0.8 }
        }
        if piece.raw.contains(where: { $0.isUppercase }) {
            en += 1.4
        }
        if clean.contains("'") {
            en += 1.4
        }
        if Self.impossibleJapaneseClusters.contains(where: { clean.contains($0) }) {
            en += 1.8
        }
        if (clean.hasSuffix("ing") || clean.hasSuffix("ed") || clean.hasSuffix("ly")), englishHit {
            en += 0.8
        }

        return ja - en >= -0.2 ? .japanese : .english
    }

    private func japaneseBias(from context: String) -> Double {
        guard !context.isEmpty else { return 0 }
        let suffix = context.suffix(24)
        let japaneseScalars = suffix.unicodeScalars.filter {
            (0x3040...0x30FF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value)
        }.count
        let asciiLetters = suffix.unicodeScalars.filter {
            (65...90).contains($0.value) || (97...122).contains($0.value)
        }.count
        if japaneseScalars >= 2 { return 0.6 }
        if asciiLetters >= 8 { return -0.4 }
        return 0
    }

    private func isTimeSuffix(_ clean: String) -> Bool {
        guard clean.hasSuffix("ji") else { return false }
        let prefix = clean.dropLast(2)
        return !prefix.isEmpty && prefix.allSatisfy(\.isNumber)
    }

    private func hasDoubleConsonant(_ clean: String) -> Bool {
        let chars = Array(clean)
        guard chars.count >= 2 else { return false }
        for i in 1 ..< chars.count {
            let previous = chars[i - 1]
            let current = chars[i]
            if previous == current,
               JapaneseRomaji.consonants.contains(previous),
               previous != "l",
               previous != "e",
               previous != "o" {
                return true
            }
        }
        return false
    }

    private func mergeAdjacent(_ spans: [BilingualSpan]) -> [BilingualSpan] {
        var result: [BilingualSpan] = []
        for span in spans {
            guard let last = result.last, last.language == span.language else {
                result.append(span)
                continue
            }
            let raw = last.raw + span.raw
            result[result.count - 1] = BilingualSpan(
                raw: raw,
                language: span.language,
                kana: span.language == .japanese ? JapaneseRomaji.toKana(raw) : nil
            )
        }
        return result
    }

    private static let particles: Set<String> = [
        "wa", "ga", "wo", "o", "ni", "de", "mo", "ka", "yo", "ne", "no", "to", "e",
    ]

    private static let weakShortEnglish: Set<String> = [
        "a", "an", "as", "at", "be", "by", "do", "go", "he", "hi", "i", "in",
        "is", "it", "me", "no", "of", "oh", "on", "or", "so", "to", "uh", "um",
        "up", "us", "we",
    ]

    private static let japaneseBigrams: [String] = [
        "shi", "tsu", "chi", "kya", "kyu", "kyo", "ryu", "ryo", "myo", "nyu",
        "gyu", "pyo", "ja", "ju", "jo",
    ]

    private static let impossibleJapaneseClusters: [String] = [
        "str", "spl", "spr", "ght", "ths", "rld", "sked", "ngth",
    ]

    private static let japaneseEndings: [String] = [
        "mashita", "masu", "desu", "nai", "nakatta", "teiru", "teru", "shita", "suru",
    ]

    public static let defaultEnglishWords: Set<String> = [
        "a", "an", "the", "i", "you", "he", "she", "it", "we", "they", "me", "him",
        "her", "us", "them", "my", "your", "his", "its", "our", "their", "this",
        "that", "these", "those", "of", "in", "on", "at", "to", "from", "for",
        "with", "by", "as", "into", "onto", "about", "over", "under", "after",
        "before", "between", "through", "and", "or", "but", "so", "if", "because",
        "while", "until", "though", "although", "since", "yet", "nor",
        "is", "am", "are", "was", "were", "be", "been", "being", "have", "has",
        "had", "do", "does", "did", "will", "would", "shall", "should", "can",
        "could", "may", "might", "must", "go", "going", "come", "get", "got",
        "like", "look",
        "make", "made", "take", "took", "see", "saw", "know", "knew", "think",
        "thought", "say", "said", "tell", "want", "give", "find", "use", "work",
        "call", "try", "ask", "need", "feel", "leave", "put", "mean", "keep",
        "let", "start", "show", "hear", "play", "run", "move", "live", "read",
        "write", "open", "walk", "teach", "good", "bad", "big", "small", "new",
        "old", "high", "low", "long", "short", "great", "little", "same", "right",
        "wrong", "different", "important", "easy", "hard", "fast", "slow", "happy",
        "sad", "real", "true", "false", "early", "late", "ready", "free", "full",
        "very", "really", "just", "only", "also", "even", "still", "back", "here",
        "there", "now", "then", "when", "where", "why", "how", "what", "who",
        "which", "all", "any", "some", "many", "much", "more", "most", "few",
        "less", "no", "not", "yes", "time", "day", "year", "way", "thing", "man",
        "woman", "child", "people", "person", "world", "life", "hand", "part",
        "place", "case", "week", "company", "system", "program", "question",
        "government", "number", "night", "point", "home", "water", "room", "area",
        "money", "story", "month", "lot", "study", "book", "eye", "job", "word",
        "business", "issue", "side", "kind", "head", "house", "service", "friend",
        "power", "hour", "game", "line", "end", "member", "law", "car", "city",
        "community", "name", "team", "minute", "idea", "kid", "body", "information",
        "parent", "face", "level", "office", "door", "health", "art", "history",
        "party", "result", "change", "morning", "reason", "research", "phone",
        "computer", "meeting", "email", "message", "data", "internet", "video",
        "photo", "music", "movie", "food", "lunch", "dinner", "breakfast", "coffee",
        "tea", "school", "store", "shop", "park", "train", "bus", "plane", "airport",
        "station", "hotel", "restaurant", "hospital", "doctor", "problem", "solution",
        "project", "report", "document", "love", "language", "english", "japanese",
        "keyboard", "iphone", "apple", "android", "google", "microsoft", "github",
        "swift", "python", "code", "coding", "software", "app", "application",
        "website", "browser", "server", "client", "database", "network", "account",
        "password", "profile", "setting", "settings", "notification", "calendar",
        "schedule", "today", "tomorrow", "yesterday", "hello", "hi", "hey", "ok",
        "okay", "thanks", "thank", "please", "sorry", "yeah", "yep", "nope", "wow",
        "oh", "uh", "um", "wanna", "gonna", "gotta", "kinda", "sorta", "lemme",
        "gimme", "dunno", "yall", "aint", "nah", "hmm", "huh", "omg", "lol",
        "lmao", "btw", "fyi", "idk", "tbh", "ngl", "imo", "imho", "asap", "etc",
        "brb",
    ]
}
