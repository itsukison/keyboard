import Foundation

public enum EnglishCorrectionCandidateSource: String, Sendable {
    case symSpell
    case system
    case completion
    case typed
}

public struct EnglishCorrectionCandidate: Equatable, Sendable {
    public let text: String
    public let source: EnglishCorrectionCandidateSource
    public let editDistance: Int
    public let frequencyScore: Double
    public let keyboardProximityScore: Double
    public let finalScore: Double

    public init(
        text: String,
        source: EnglishCorrectionCandidateSource,
        editDistance: Int,
        frequencyScore: Double,
        keyboardProximityScore: Double,
        finalScore: Double
    ) {
        self.text = text
        self.source = source
        self.editDistance = editDistance
        self.frequencyScore = frequencyScore
        self.keyboardProximityScore = keyboardProximityScore
        self.finalScore = finalScore
    }
}

public struct EnglishCorrectionRequest: Sendable {
    public let typedWord: String
    public let contextBeforeWord: String
    public let maxCandidates: Int
    public let isTypedWordValidBySystem: Bool
    public let hasManualCapitalization: Bool
    public let systemGuesses: [String]
    public let systemCompletions: [String]

    public init(
        typedWord: String,
        contextBeforeWord: String = "",
        maxCandidates: Int = 8,
        isTypedWordValidBySystem: Bool = false,
        hasManualCapitalization: Bool = false,
        systemGuesses: [String] = [],
        systemCompletions: [String] = []
    ) {
        self.typedWord = typedWord
        self.contextBeforeWord = contextBeforeWord
        self.maxCandidates = maxCandidates
        self.isTypedWordValidBySystem = isTypedWordValidBySystem
        self.hasManualCapitalization = hasManualCapitalization
        self.systemGuesses = systemGuesses
        self.systemCompletions = systemCompletions
    }
}

public struct EnglishCorrectionResult: Equatable, Sendable {
    public let isTypedWordValid: Bool
    public let topCorrection: String?
    public let displayCandidates: [String]
    public let rankedCandidates: [EnglishCorrectionCandidate]

    public init(
        isTypedWordValid: Bool,
        topCorrection: String?,
        displayCandidates: [String],
        rankedCandidates: [EnglishCorrectionCandidate]
    ) {
        self.isTypedWordValid = isTypedWordValid
        self.topCorrection = topCorrection
        self.displayCandidates = displayCandidates
        self.rankedCandidates = rankedCandidates
    }
}

public protocol EnglishCorrectionProvider {
    func correctionResult(for request: EnglishCorrectionRequest) -> EnglishCorrectionResult
}
