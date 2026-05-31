import Foundation
import KeyboardPreferences
import SymSpellSwift

public final class SymSpellEnglishCorrectionProvider: EnglishCorrectionProvider, @unchecked Sendable {
    private let dictionaryURL: URL?
    private let lock = NSLock()
    private var symSpell: SymSpell?
    private var loadFailed = false
    private var loadStarted = false

    public init(dictionaryURL: URL? = nil) {
        self.dictionaryURL = dictionaryURL ?? Bundle.module.url(
            forResource: "frequency_dictionary_en_82_765",
            withExtension: "txt"
        )
    }

    public func preload() {
        guard let dictionaryURL = reserveLoad() else { return }

        let local = SymSpell(maxDictionaryEditDistance: 2, prefixLength: 7)
        do {
            let contents = try String(contentsOf: dictionaryURL, encoding: .utf8)
            contents.enumerateLines { line, _ in
                let parts = line.split(separator: " ", maxSplits: 1)
                guard parts.count == 2, let count = Int(parts[1]) else { return }
                local.createDictionaryEntry(key: String(parts[0]), count: count)
            }
            completeLoad(local)
        } catch {
            completeLoad(nil)
        }
    }

    public func correctionResult(for request: EnglishCorrectionRequest) -> EnglishCorrectionResult {
        let typed = normalized(request.typedWord)
        guard !typed.isEmpty else {
            return EnglishCorrectionResult(
                isTypedWordValid: false,
                topCorrection: nil,
                displayCandidates: [],
                rankedCandidates: []
            )
        }

        let dictionary = loadedDictionaryIfReady()
        let maxDistance = EnglishAutocorrectGate.maxAllowedDistance(forTypedLength: typed.count)
        let symSpellItems = dictionary?.lookup(typed, verbosity: .all, maxEditDistance: maxDistance) ?? []
        let exactDictionaryHit = symSpellItems.contains { $0.distance == 0 && $0.term == typed }
        let userPrefersRaw = ConversionPreferenceStore.shouldPreferRaw(scope: .english, input: typed)
        let isTypedWordValid = request.isTypedWordValidBySystem || exactDictionaryHit || userPrefersRaw

        var candidatesByKey: [String: CandidateAccumulator] = [:]
        if isTypedWordValid || userPrefersRaw {
            merge(
                text: typed,
                source: .typed,
                editDistance: 0,
                count: exactDictionaryHit ? count(for: typed, in: symSpellItems) : 1,
                typed: typed,
                originalTyped: request.typedWord,
                into: &candidatesByKey
            )
        }

        for item in symSpellItems.prefix(24) {
            merge(
                text: item.term,
                source: .symSpell,
                editDistance: item.distance,
                count: item.count,
                typed: typed,
                originalTyped: request.typedWord,
                into: &candidatesByKey
            )
        }

        for guess in request.systemGuesses.prefix(8) {
            let normalizedGuess = normalized(guess)
            guard !normalizedGuess.isEmpty else { continue }
            merge(
                text: normalizedGuess,
                source: .system,
                editDistance: EnglishAutocorrectGate.levenshtein(typed, normalizedGuess),
                count: 0,
                typed: typed,
                originalTyped: request.typedWord,
                into: &candidatesByKey
            )
        }

        for completion in request.systemCompletions.prefix(8) {
            let normalizedCompletion = normalized(completion)
            guard !normalizedCompletion.isEmpty else { continue }
            merge(
                text: normalizedCompletion,
                source: .completion,
                editDistance: max(0, normalizedCompletion.count - typed.count),
                count: 0,
                typed: typed,
                originalTyped: request.typedWord,
                into: &candidatesByKey
            )
        }

        let ranked = candidatesByKey.values
            .map { $0.candidate }
            .sorted {
                if $0.finalScore == $1.finalScore {
                    if $0.editDistance == $1.editDistance {
                        return $0.text < $1.text
                    }
                    return $0.editDistance < $1.editDistance
                }
                return $0.finalScore > $1.finalScore
            }

        let displayCandidates = displayCandidates(
            from: ranked,
            typed: request.typedWord,
            maxCandidates: request.maxCandidates
        )
        let topCorrection = topCorrection(
            from: ranked,
            typed: request.typedWord,
            normalizedTyped: typed,
            isTypedWordValid: isTypedWordValid,
            hasManualCapitalization: request.hasManualCapitalization
        )

        return EnglishCorrectionResult(
            isTypedWordValid: isTypedWordValid,
            topCorrection: topCorrection,
            displayCandidates: displayCandidates,
            rankedCandidates: ranked
        )
    }

    private func loadedDictionaryIfReady() -> SymSpell? {
        withLock { symSpell }
    }

    private func reserveLoad() -> URL? {
        withLock {
            guard symSpell == nil, !loadFailed, !loadStarted else { return nil }
            guard let dictionaryURL else {
                loadFailed = true
                return nil
            }
            loadStarted = true
            return dictionaryURL
        }
    }

    private func completeLoad(_ loaded: SymSpell?) {
        withLock {
            if let loaded {
                symSpell = loaded
            } else {
                loadFailed = true
            }
        }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private func count(for typed: String, in items: [SuggestItem]) -> Int {
        items.first { $0.term == typed && $0.distance == 0 }?.count ?? 1
    }

    private func merge(
        text: String,
        source: EnglishCorrectionCandidateSource,
        editDistance: Int,
        count: Int,
        typed: String,
        originalTyped: String,
        into candidatesByKey: inout [String: CandidateAccumulator]
    ) {
        let key = normalized(text)
        guard isAllowedCandidate(key) else { return }
        let frequencyScore = count > 0 ? log10(Double(count) + 1) : 0
        let proximityScore = QWERTYKeyboardProximity.score(typed: typed, candidate: key)
        let transpositionScore = isAdjacentTransposition(typed, key) ? 4.0 : 0.0
        let punctuationPenalty = punctuationShape(text) == punctuationShape(typed) ? 0.0 : -1.0
        let sourceScore: Double = switch source {
        case .symSpell: 1.0
        case .system: 0.75
        case .completion: -2.0
        case .typed: 4.0
        }
        let finalScore = sourceScore
            + frequencyScore
            + proximityScore
            + transpositionScore
            + punctuationPenalty
            - Double(editDistance) * 5.0

        let displayText = applyCasing(from: text, matching: originalTyped)
        let candidate = EnglishCorrectionCandidate(
            text: displayText,
            source: source,
            editDistance: editDistance,
            frequencyScore: frequencyScore,
            keyboardProximityScore: proximityScore,
            finalScore: finalScore
        )

        if let existing = candidatesByKey[key], existing.candidate.finalScore >= finalScore {
            return
        }
        candidatesByKey[key] = CandidateAccumulator(candidate: candidate)
    }

    private func displayCandidates(
        from ranked: [EnglishCorrectionCandidate],
        typed: String,
        maxCandidates: Int
    ) -> [String] {
        let rankedText = ranked.map(\.text)
        let preferred = ConversionPreferenceStore.rerank(
            scope: .english,
            input: typed,
            candidates: rankedText
        )
        var seen: Set<String> = []
        var display: [String] = []
        for candidate in preferred where !candidate.isEmpty {
            if seen.insert(candidate.lowercased()).inserted {
                display.append(candidate)
            }
            if display.count >= maxCandidates { break }
        }
        return display
    }

    private func topCorrection(
        from ranked: [EnglishCorrectionCandidate],
        typed: String,
        normalizedTyped: String,
        isTypedWordValid: Bool,
        hasManualCapitalization: Bool
    ) -> String? {
        guard !isTypedWordValid else { return nil }
        guard !EnglishAutocorrectGate.shouldSuppressAutocorrectionForManualCapitalization(
            typed: typed,
            hasManualCapitalization: hasManualCapitalization
        ) else {
            return nil
        }
        guard let candidate = ranked.first(where: {
            $0.source != .completion && normalized($0.text) != normalizedTyped
        }) else {
            return nil
        }
        guard EnglishAutocorrectGate.correctionPassesGate(typed: typed, candidate: candidate.text) else {
            return nil
        }
        return candidate.text
    }

    private func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func isAllowedCandidate(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        return text.allSatisfy { ch in
            guard ch.unicodeScalars.count == 1, let scalar = ch.unicodeScalars.first else { return false }
            let value = scalar.value
            return (97...122).contains(value) || ch == "'" || ch == "-"
        }
    }

    private func punctuationShape(_ text: String) -> String {
        text.filter { $0 == "'" || $0 == "-" }
    }

    private func isAdjacentTransposition(_ typed: String, _ candidate: String) -> Bool {
        let lhs = Array(typed)
        let rhs = Array(candidate)
        guard lhs.count == rhs.count else { return false }
        let diffs = lhs.indices.filter { lhs[$0] != rhs[$0] }
        guard diffs.count == 2,
              let first = diffs.first,
              let second = diffs.last,
              second == first + 1 else {
            return false
        }
        return lhs[first] == rhs[second] && lhs[second] == rhs[first]
    }

    private func applyCasing(from candidate: String, matching typed: String) -> String {
        guard typed.contains(where: { $0.isUppercase }) else { return candidate }
        if typed.allSatisfy({ !$0.isLetter || $0.isUppercase }) {
            return candidate.uppercased()
        }
        guard let first = candidate.first else { return candidate }
        return first.uppercased() + candidate.dropFirst()
    }

    private struct CandidateAccumulator {
        let candidate: EnglishCorrectionCandidate
    }
}
