import Foundation

/// Character-trigram log-probability classifier for romaji-JA vs EN tokens.
///
/// The model is trained offline by the `TrigramBuilder` executable and shipped
/// as `Resources/trigrams.json`. At runtime the scorer pads a token with
/// boundary marks, slides a length-3 window, and returns the summed log-prob
/// under each class. Unseen trigrams fall back to the per-class
/// `unseenLogProb`, which already factors in Laplace smoothing and the shared
/// vocabulary size used at training time.
public final class TrigramScorer: @unchecked Sendable {

    public struct Score: Equatable, Sendable {
        public let ja: Double
        public let en: Double
        public var diff: Double { ja - en }
    }

    private struct ClassModel: Decodable {
        let unseenLogProb: Double
        let trigrams: [String: Double]
    }

    private struct Payload: Decodable {
        let version: Int
        let smoothingAlpha: Double
        let sharedVocabSize: Int
        let startMark: String
        let endMark: String
        let ja: ClassModel
        let en: ClassModel
    }

    private let startMark: Character
    private let endMark: Character
    private let jaTrigrams: [String: Double]
    private let enTrigrams: [String: Double]
    private let jaUnseen: Double
    private let enUnseen: Double

    public static let shared: TrigramScorer = {
        do {
            return try TrigramScorer()
        } catch {
            // The model is shipped with the library; if it is missing the
            // library is mis-built. Crash early in debug, degrade in release.
            assertionFailure("TrigramScorer init failed: \(error)")
            return TrigramScorer.empty()
        }
    }()

    public init(payload data: Data) throws {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        self.startMark = payload.startMark.first ?? "^"
        self.endMark = payload.endMark.first ?? "$"
        self.jaTrigrams = payload.ja.trigrams
        self.enTrigrams = payload.en.trigrams
        self.jaUnseen = payload.ja.unseenLogProb
        self.enUnseen = payload.en.unseenLogProb
    }

    public convenience init() throws {
        guard let url = Bundle.module.url(forResource: "trigrams", withExtension: "json") else {
            throw Error.resourceMissing
        }
        let data = try Data(contentsOf: url)
        try self.init(payload: data)
    }

    private init(empty: Void) {
        self.startMark = "^"
        self.endMark = "$"
        self.jaTrigrams = [:]
        self.enTrigrams = [:]
        self.jaUnseen = 0
        self.enUnseen = 0
    }

    fileprivate static func empty() -> TrigramScorer {
        TrigramScorer(empty: ())
    }

    public enum Error: Swift.Error {
        case resourceMissing
    }

    /// Returns summed log-probability of the padded token under each class.
    /// Tokens with fewer than 2 alpha-numeric characters get a zero-zero score
    /// (caller should fall back to other features).
    public func score(_ token: Substring) -> Score {
        score(String(token))
    }

    public func score(_ token: String) -> Score {
        let normalized = normalize(token)
        if normalized.isEmpty {
            return Score(ja: 0, en: 0)
        }
        var ja = 0.0
        var en = 0.0
        let padded: [Character] = [startMark] + Array(normalized) + [endMark]
        // padded always has at least 3 chars when normalized is non-empty
        for i in 0 ... padded.count - 3 {
            let tri = String(padded[i ..< i + 3])
            ja += jaTrigrams[tri] ?? jaUnseen
            en += enTrigrams[tri] ?? enUnseen
        }
        return Score(ja: ja, en: en)
    }

    /// Per-character normalized score difference. Positive favors JA, negative
    /// favors EN. Length-normalized so short and long tokens are comparable
    /// against the same threshold.
    public func normalizedDiff(_ token: String) -> Double {
        let s = score(token)
        let n = max(1, normalize(token).count + 2) // +2 for boundary trigrams
        return s.diff / Double(n)
    }

    private func normalize(_ token: String) -> String {
        var out = ""
        out.reserveCapacity(token.count)
        for ch in token.lowercased() {
            if (ch >= "a" && ch <= "z") || (ch >= "0" && ch <= "9") || ch == "-" {
                out.append(ch)
            }
        }
        return out
    }
}
