import Foundation

public enum SpanKind: String, Codable, Sendable {
    case japanese
    case english
}

public enum ConversionMode: String, Codable, Sendable {
    case dictionaryOnly
    case zenzaiV3
}

public struct DetectedSpan: Codable, Sendable {
    public var raw: String
    public var kind: SpanKind
    public var kana: String?

    public init(raw: String, kind: SpanKind, kana: String?) {
        self.raw = raw
        self.kind = kind
        self.kana = kana
    }
}

public struct AdapterInput: Codable, Sendable {
    public var rawRomaji: String
    public var kana: String
    public var contextBefore: String
    public var contextAfter: String
    public var maxCandidates: Int
    public var conversionMode: ConversionMode

    public init(
        rawRomaji: String,
        kana: String,
        contextBefore: String,
        contextAfter: String,
        maxCandidates: Int,
        conversionMode: ConversionMode
    ) {
        self.rawRomaji = rawRomaji
        self.kana = kana
        self.contextBefore = contextBefore
        self.contextAfter = contextAfter
        self.maxCandidates = maxCandidates
        self.conversionMode = conversionMode
    }
}

public struct AdapterOutput: Codable, Sendable {
    public var input: AdapterInput
    public var mainCandidate: String
    public var candidates: [String]
    public var segments: [String]
    public var coldStartMs: Double
    public var requestLatencyMs: Double
    public var contextPassed: String
    /// AzooKey's log-probability cost for the top candidate (more negative = worse).
    /// `nil` if no candidate was produced. Used as a JA-plausibility feedback signal.
    public var topCandidateScore: Double?
    /// `topCandidateScore` divided by mora count of the input kana, so it can be
    /// compared across spans of different lengths.
    public var topCandidateScorePerMora: Double?

    public init(
        input: AdapterInput,
        mainCandidate: String,
        candidates: [String],
        segments: [String],
        coldStartMs: Double,
        requestLatencyMs: Double,
        contextPassed: String,
        topCandidateScore: Double? = nil,
        topCandidateScorePerMora: Double? = nil
    ) {
        self.input = input
        self.mainCandidate = mainCandidate
        self.candidates = candidates
        self.segments = segments
        self.coldStartMs = coldStartMs
        self.requestLatencyMs = requestLatencyMs
        self.contextPassed = contextPassed
        self.topCandidateScore = topCandidateScore
        self.topCandidateScorePerMora = topCandidateScorePerMora
    }
}
