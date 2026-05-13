import Foundation

/// Drives the bilingual conversion pipeline for a single document.
///
/// Maintains a running `leftSideContext` of converted Japanese (English raw text is
/// intentionally excluded — the zenzai model is monolingual Japanese and English
/// tokens in the prompt degrade context-sensitive picks).
public final class InputController {
    private let detector: BilingualSpanDetector
    private let adapter: KanaKanjiAdapter
    private let useZenzai: Bool
    private var _leftSideContext: String = ""
    /// Tail of recently committed text retaining both JA and EN. Drives the
    /// document-level `LanguagePrior`. Kept separate from `_leftSideContext`
    /// (which feeds zenzai and is JA-only by design — see file header).
    private var _recentCommittedTail: String = ""
    private static let recentCommittedTailLimit = 200
    private let lock = NSLock()
    private let conversionLock = NSLock()
    public var leftSideContext: String {
        lock.lock(); defer { lock.unlock() }
        return _leftSideContext
    }
    public var recentCommittedTail: String {
        lock.lock(); defer { lock.unlock() }
        return _recentCommittedTail
    }

    public init(
        detector: BilingualSpanDetector = .init(),
        adapter: KanaKanjiAdapter,
        useZenzai: Bool
    ) {
        self.detector = detector
        self.adapter = adapter
        self.useZenzai = useZenzai
    }

    /// Result for the current in-progress run (not yet committed).
    ///
    /// `raw` is the exact input string the conversion was produced from. The
    /// caller MUST compare it against the live buffer before committing —
    /// fast typing produces a buffer longer than the snapshot the conversion
    /// was built from, and dropping the suffix on commit silently destroys
    /// user input.
    public struct LiveConversion: Sendable {
        public let raw: String
        public let spans: [DetectedSpan]
        public let conversions: [AdapterOutput]

        public init(raw: String, spans: [DetectedSpan], conversions: [AdapterOutput]) {
            self.raw = raw
            self.spans = spans
            self.conversions = conversions
        }

        /// Joined preview combining English raw + each Japanese span's main candidate.
        public var preview: String {
            var conversionIndex = 0
            var output = ""
            for span in spans {
                switch span.kind {
                case .english:
                    output += span.raw
                case .japanese:
                    if conversionIndex < conversions.count {
                        output += conversions[conversionIndex].mainCandidate
                        conversionIndex += 1
                    } else if let kana = span.kana {
                        output += kana
                    }
                }
            }
            return output
        }
    }

    /// Run detection + conversion for the current uncommitted input buffer.
    /// Caller passes only the *uncommitted* romaji; committed text lives in `leftSideContext`.
    /// Safe to call concurrently with `commit(japanese:)` and `reset()`.
    public func convert(_ raw: String, documentPrior: LanguagePrior = .neutral) -> LiveConversion {
        conversionLock.lock()
        defer { conversionLock.unlock() }

        let spans = detector.detect(raw, documentPrior: documentPrior)
        lock.lock()
        var contextBefore = _leftSideContext
        lock.unlock()
        var conversions: [AdapterOutput] = []
        let mode: ConversionMode = useZenzai ? .zenzaiV3 : .dictionaryOnly

        for span in spans {
            switch span.kind {
            case .english:
                // Skip English in zenzai context — model is Japanese-only.
                continue
            case .japanese:
                guard let kana = span.kana else { continue }
                let input = AdapterInput(
                    rawRomaji: span.raw,
                    kana: kana,
                    contextBefore: contextBefore,
                    contextAfter: "",
                    maxCandidates: 10,
                    conversionMode: mode
                )
                let output = adapter.convert(input)
                conversions.append(output)
                contextBefore += output.mainCandidate
            }
        }

        return LiveConversion(raw: raw, spans: spans, conversions: conversions)
    }

    /// Append a committed piece of text (English raw or chosen Japanese) to the left-side
    /// context. Only Japanese is kept; English is dropped intentionally.
    public func commit(japanese: String) {
        lock.lock(); defer { lock.unlock() }
        _leftSideContext += japanese
        appendToRecentTailLocked(japanese)
    }

    /// Append a committed English fragment to the document-prior tail only.
    /// Does not pollute the zenzai `leftSideContext`.
    public func commitEnglish(_ english: String) {
        lock.lock(); defer { lock.unlock() }
        appendToRecentTailLocked(english)
    }

    public func reset() {
        lock.lock(); defer { lock.unlock() }
        _leftSideContext = ""
        _recentCommittedTail = ""
    }

    private func appendToRecentTailLocked(_ piece: String) {
        _recentCommittedTail += piece
        if _recentCommittedTail.count > Self.recentCommittedTailLimit {
            let drop = _recentCommittedTail.count - Self.recentCommittedTailLimit
            _recentCommittedTail.removeFirst(drop)
        }
    }
}
