import UIKit
import os
import NaturalLanguage
import KeyboardCore

/// Custom keyboard input controller.
///
/// IME-style flow (azooKey/Gboard convention — iOS keyboard extensions have no
/// `setMarkedText` API):
/// 1. Each keypress appends raw romaji to `buffer` AND is inserted into the host
///    text field immediately, so the user sees what they typed in real time.
/// 2. The candidate strip shows the converted preview + alternatives.
/// 3. On space/return/candidate tap we `deleteBackward` the raw buffer length,
///    then insert the converted text. This is invisible to the host (atomic
///    replace).
///
/// Reliability invariant: every `.character` event must end up in `buffer`
/// exactly once and reach the host exactly once. Commit MUST NOT delete more
/// raw chars than it can replace — otherwise fast typing drops the suffix
/// that arrived after the conversion snapshot.
public final class KeyboardViewController: UIInputViewController {

    // MARK: - State

    /// Uncommitted raw input (romaji + embedded English). What's currently
    /// visible at the tail of the host text field.
    private var buffer: String = ""
    private var liveConversion: InputController.LiveConversion?
    private var inputController: InputController!
    private var displayedTextManager: DisplayedTextManager!
    private let conversionCoordinator = ConversionCoordinator()
    private var keyboardView: KeyboardView!
    private var candidateBar: CandidateBar!
    private var pendingTextState: ObservedTextState?
    private var lastShiftTap: TimeInterval = 0
    private var traceSequence: UInt64 = 0
    private let textChecker = UITextChecker()
    private var englishCandidatesActive = false
    private var currentDocumentPrior: LanguagePrior = .neutral
    private var lastPriorSampleHash: Int?
    /// User shortcuts + contacts surfaced by UILexicon. Treated as "always
    /// valid" English words so autocorrect leaves them alone.
    private var userLexiconEntries: Set<String> = []
    private static let doubleTapWindow: TimeInterval = 0.35
    private static let log = Logger(subsystem: "com.bilingual.keyboard", category: "input")
    private static let debugLogging: Bool = ProcessInfo.processInfo.environment["KEYBOARD_DEBUG_LOG"] != nil
    /// Signposter for Instruments Time Profiler. Intervals: `tap-to-proxy`,
    /// `apply`, `englishSuggestions`, `candidateBar.update`.
    private static let signposter = OSSignposter(subsystem: "com.bilingual.keyboard", category: "perf")
    /// Diagnostic A/B flags read once at process start. See HANDOFF perf bisect.
    private static let disableConversion: Bool = ProcessInfo.processInfo.environment["KB_DISABLE_CONVERSION"] != nil
    private static let disableEnglishSuggest: Bool = ProcessInfo.processInfo.environment["KB_DISABLE_ENGLISH_SUGGEST"] != nil

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()

        Self.log.notice("flags: debugLog=\(Self.debugLogging) disableConversion=\(Self.disableConversion) disableEnglishSuggest=\(Self.disableEnglishSuggest)")

        let weightURL = Self.bundledZenzaiWeightURL()
        let useZenzai = weightURL != nil
        let adapter = KanaKanjiAdapter(zenzaiWeightURL: weightURL)
        self.inputController = InputController(adapter: adapter, useZenzai: useZenzai)
        self.displayedTextManager = DisplayedTextManager { [unowned self] in
            self.textDocumentProxy
        }

        setupViews()
        requestSupplementaryLexicon { [weak self] lexicon in
            guard let self else { return }
            self.userLexiconEntries = Set(lexicon.entries.flatMap {
                [$0.documentText.lowercased(), $0.userInput.lowercased()]
            })
        }

        // Compact Japanese keyboard surface (~276pt: 53 candidate
        // bar + 223 key area). Priority < required so the system can override
        // for landscape / floating contexts.
        let heightConstraint = view.heightAnchor.constraint(equalToConstant: 276)
        heightConstraint.priority = .init(999)
        heightConstraint.isActive = true
    }

    public override func viewWillDisappear(_ animated: Bool) {
        conversionCoordinator.cancel()
        super.viewWillDisappear(animated)
    }

    public override func textWillChange(_ textInput: UITextInput?) {
        super.textWillChange(textInput)
        pendingTextState = displayedTextManager?.snapshot()
    }

    public override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        guard let displayedTextManager else { return }
        let after = displayedTextManager.snapshot()
        if let before = pendingTextState {
            switch displayedTextManager.consumeExpectedEdit(before: before, after: after) {
            case .matched(let hasMoreEdits):
                traceExpectedEdit(before: before, after: after, matched: true)
                pendingTextState = hasMoreEdits ? after : nil
                return
            case .noMatch:
                traceExpectedEdit(before: before, after: after, matched: false)
            }
        }
        pendingTextState = nil

        if !buffer.isEmpty {
            if after.left.hasSuffix(buffer) {
                return
            }
            if after.left.isEmpty, after.center.isEmpty, after.right.isEmpty {
                return
            }
            clearComposition(resetContext: true)
            return
        }

        // Only treat empty context as "fresh document" when we have no
        // composing buffer of our own. Without this guard, hosts that briefly
        // report an empty `documentContextBeforeInput` during fast input
        // would wipe `buffer` while raw chars remain in the host, desyncing
        // the next commit's deleteBackward count.
        guard buffer.isEmpty else { return }
        if after.left.isEmpty {
            clearComposition(resetContext: true)
        }
        // Focus/cursor change while not composing → refresh the document-
        // level language prior. Hashed so we don't re-run NLLanguageRecognizer
        // when the surrounding text hasn't actually changed.
        refreshDocumentPriorIfNeeded()
    }

    // MARK: - View setup

    private func setupViews() {
        candidateBar = CandidateBar(frame: .zero)
        candidateBar.translatesAutoresizingMaskIntoConstraints = false
        candidateBar.onSelect = { [weak self] candidate in
            self?.commitCandidate(candidate)
        }
        view.addSubview(candidateBar)

        keyboardView = KeyboardView(frame: .zero)
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.onKey = { [weak self] event in
            self?.handle(event)
        }
        view.addSubview(keyboardView)

        NSLayoutConstraint.activate([
            candidateBar.topAnchor.constraint(equalTo: view.topAnchor),
            candidateBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            candidateBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            candidateBar.heightAnchor.constraint(equalToConstant: 53),

            keyboardView.topAnchor.constraint(equalTo: candidateBar.bottomAnchor),
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Key handling

    private func handle(_ event: KeyboardView.KeyEvent) {
        switch event {
        case .character(let ch):
            let prev = buffer
            let prevDisplayed = traceDocumentTail()
            let start = DispatchTime.now().uptimeNanoseconds
            let tapState = Self.signposter.beginInterval("tap-to-proxy")
            buffer.append(ch)
            displayedTextManager.insertRaw(ch)
            Self.signposter.endInterval("tap-to-proxy", tapState)
            let end = DispatchTime.now().uptimeNanoseconds
            traceKey(
                label: "char",
                key: ch,
                prevBuffer: prev,
                nextBuffer: buffer,
                prevDisplayed: prevDisplayed,
                nextDisplayed: traceDocumentTail(),
                proxyElapsedMs: Double(end - start) / 1_000_000
            )
            // One-shot shift: revert to off after a single character.
            if keyboardView.shiftState == .shifted {
                keyboardView.setShift(.off)
            }
            scheduleConvert()
        case .backspace:
            let prev = buffer
            let prevDisplayed = traceDocumentTail()
            if !buffer.isEmpty {
                displayedTextManager.deleteBackward(buffer: &buffer)
                traceKey(
                    label: "bksp",
                    key: "⌫",
                    prevBuffer: prev,
                    nextBuffer: buffer,
                    prevDisplayed: prevDisplayed,
                    nextDisplayed: traceDocumentTail()
                )
                scheduleConvert()
            } else {
                displayedTextManager.deleteBackward()
                traceKey(
                    label: "bksp-host",
                    key: "⌫",
                    prevBuffer: prev,
                    nextBuffer: buffer,
                    prevDisplayed: prevDisplayed,
                    nextDisplayed: traceDocumentTail()
                )
            }
        case .space:
            handleSpace()
        case .returnKey:
            handleReturn()
        case .shift:
            // Single tap cycles off ↔ shifted; a second tap within the
            // double-tap window engages caps lock.
            let now = Date().timeIntervalSinceReferenceDate
            if now - lastShiftTap < Self.doubleTapWindow
                && keyboardView.shiftState == .shifted {
                keyboardView.setShift(.locked)
            } else {
                keyboardView.cycleShift()
            }
            lastShiftTap = now
        case .switchPage(let page):
            keyboardView.switchPage(page)
        case .nextKeyboard:
            advanceToNextInputMode()
        case .dismiss:
            dismissKeyboard()
        }
    }

    private func commitCandidate(_ candidate: String) {
        if englishCandidatesActive {
            commitEnglishCandidate(candidate)
            return
        }
        guard let live = liveConversion, !live.spans.isEmpty else { return }
        // The candidate was produced from `live.raw`, which may now be a
        // proper prefix of `buffer` (user kept typing while the candidate bar
        // showed). Splice the user's chosen candidate into a fresh
        // LiveConversion that still owns the snapshot, then commit normally —
        // commit() will preserve the post-snapshot suffix.
        var conversions = live.conversions
        if !conversions.isEmpty {
            conversions[0] = AdapterOutput(
                input: conversions[0].input,
                mainCandidate: candidate,
                candidates: conversions[0].candidates,
                segments: conversions[0].segments,
                coldStartMs: conversions[0].coldStartMs,
                requestLatencyMs: conversions[0].requestLatencyMs,
                contextPassed: conversions[0].contextPassed
            )
        }
        let revised = InputController.LiveConversion(
            raw: live.raw,
            spans: live.spans,
            conversions: conversions
        )
        commit(revised)
    }

    // MARK: - English autocorrect

    /// Replaces the last English span in the live conversion with the tapped suggestion,
    /// preserving any preceding Japanese conversions and any suffix typed after the snapshot.
    /// Pass `overrideLive` when calling from a synchronous path that already ran conversion.
    private func commitEnglishCandidate(_ suggestion: String, overrideLive: InputController.LiveConversion? = nil) {
        let live = overrideLive ?? liveConversion
        guard let live, !live.spans.isEmpty else { return }
        conversionCoordinator.cancel()
        let preview = englishReplacedPreview(live: live, suggestion: suggestion)
        guard let plan = InputCommitPlanner.replacement(buffer: buffer, snapshot: live.raw, preview: preview) else {
            Self.log.error("englishCommit: snapshot/buffer mismatch. buffer=\(self.buffer, privacy: .public) snapshot=\(live.raw, privacy: .public)")
            return
        }
        let prevDisplayed = traceDocumentTail()
        displayedTextManager.replaceComposition(plan: plan)
        let lastEnglishIndex = live.spans.lastIndex(where: { $0.kind == .english })
        for (idx, span) in live.spans.enumerated() {
            switch span.kind {
            case .japanese:
                let jaBefore = live.spans.prefix(idx).filter { $0.kind == .japanese }.count
                if jaBefore < live.conversions.count {
                    inputController.commit(japanese: live.conversions[jaBefore].mainCandidate)
                }
            case .english:
                // The trailing English span is the one we just corrected;
                // record the suggestion in the tail, not the raw input.
                inputController.commitEnglish(idx == lastEnglishIndex ? suggestion : span.raw)
            }
        }
        traceCommit(plan: plan, prevDisplayed: prevDisplayed, nextDisplayed: traceDocumentTail())
        buffer = plan.nextBuffer
        liveConversion = nil
        englishCandidatesActive = false
        candidateBar.update(candidates: [], preview: "")
        refreshDocumentPriorIfNeeded()
        if !buffer.isEmpty { scheduleConvert() }
    }

    /// Rebuilds the preview string replacing the last English span's raw text with `suggestion`.
    private func englishReplacedPreview(live: InputController.LiveConversion, suggestion: String) -> String {
        var convIdx = 0
        var out = ""
        for (i, span) in live.spans.enumerated() {
            switch span.kind {
            case .english:
                out += i == live.spans.count - 1 ? suggestion : span.raw
            case .japanese:
                if convIdx < live.conversions.count {
                    out += live.conversions[convIdx].mainCandidate
                    convIdx += 1
                } else if let kana = span.kana {
                    out += kana
                }
            }
        }
        return out
    }

    /// Result of inspecting the trailing English word with UITextChecker.
    /// `isTypedWordValid` is the gate that prevents native-style overcorrection:
    /// if the typed word is in the system dictionary (or the user lexicon),
    /// space MUST NOT replace it.
    private struct EnglishSuggestionResult {
        let typedWord: String
        let isTypedWordValid: Bool
        let topCorrection: String?
        let displayCandidates: [String]
        static let empty = EnglishSuggestionResult(typedWord: "", isTypedWordValid: false, topCorrection: nil, displayCandidates: [])
    }

    /// Returns suggestion data for the last word in `text`. Combines validity
    /// gate + edit-distance-capped top correction + display list for the
    /// candidate bar. Native iOS keyboards only autocorrect when the typed
    /// word is *not* in the dictionary AND a close-edit-distance candidate
    /// exists; this mirrors that behavior.
    private func englishSuggestions(for text: String) -> EnglishSuggestionResult {
        if Self.disableEnglishSuggest { return .empty }
        let suggestState = Self.signposter.beginInterval("englishSuggestions")
        defer { Self.signposter.endInterval("englishSuggestions", suggestState) }
        let lastWord = text
            .components(separatedBy: .whitespaces)
            .last(where: { !$0.isEmpty }) ?? text
        guard !lastWord.isEmpty else { return .empty }
        let nsWord = lastWord as NSString
        let range = NSRange(location: 0, length: nsWord.length)

        let bad = textChecker.rangeOfMisspelledWord(
            in: lastWord, range: range, startingAt: 0, wrap: false, language: "en_US"
        )
        let inLexicon = userLexiconEntries.contains(lastWord.lowercased())
        let isValid = bad.location == NSNotFound || inLexicon

        let completions = textChecker.completions(
            forPartialWordRange: range, in: lastWord, language: "en_US"
        ) ?? []
        let guesses: [String]
        if !isValid {
            guesses = textChecker.guesses(forWordRange: bad, in: lastWord, language: "en_US") ?? []
        } else {
            guesses = []
        }
        // Candidate bar shows guesses first (tap-to-correct) then completions
        // (tap-to-extend). De-duped, capped at 8.
        var seen: Set<String> = []
        var display: [String] = []
        for s in guesses + completions where !s.isEmpty {
            if seen.insert(s).inserted { display.append(s) }
            if display.count >= 8 { break }
        }

        // Top correction only fires when typed word is invalid AND a guess is
        // within the edit-distance gate (see EnglishAutocorrectGate).
        let topCorrection: String?
        if !isValid, let candidate = guesses.first,
           EnglishAutocorrectGate.correctionPassesGate(typed: lastWord, candidate: candidate) {
            topCorrection = candidate
        } else {
            topCorrection = nil
        }

        return EnglishSuggestionResult(
            typedWord: lastWord,
            isTypedWordValid: isValid,
            topCorrection: topCorrection,
            displayCandidates: display
        )
    }

    // MARK: - Document language prior

    /// Recompute the document-level `LanguagePrior` from the host text proxy
    /// + recently-committed tail, but only when the sampled context has
    /// actually changed (cheap hash check). Called on focus/cursor change
    /// and after every commit.
    private func refreshDocumentPriorIfNeeded() {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let after = textDocumentProxy.documentContextAfterInput ?? ""
        let beforeTail = String(before.suffix(200))
        let afterHead = String(after.prefix(50))
        let committedTail = inputController?.recentCommittedTail ?? ""
        let sample = committedTail + beforeTail + " " + afterHead
        let hash = sample.hashValue
        if hash == lastPriorSampleHash { return }
        lastPriorSampleHash = hash
        currentDocumentPrior = Self.languagePrior(for: sample)
    }

    private static func languagePrior(for text: String) -> LanguagePrior {
        // NLLanguageRecognizer needs some signal — very short samples yield
        // unreliable hypotheses, so fall back to neutral.
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 8 else { return .neutral }
        let recognizer = NLLanguageRecognizer()
        recognizer.languageHints = [.japanese: 0.5, .english: 0.5]
        recognizer.processString(trimmed)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 5)
        let ja = hypotheses[.japanese] ?? 0
        let en = hypotheses[.english] ?? 0
        if ja == 0 && en == 0 { return .neutral }
        // Map raw probabilities to symmetric bias: positive jaBias when JA
        // dominates, negative when EN dominates. enBias mirrors. Clamp to
        // ±1 so a single noisy sample can't swamp the per-token scores.
        let diff = max(-1.0, min(1.0, ja - en))
        return LanguagePrior(jaBias: max(0, diff), enBias: max(0, -diff))
    }

    private func commitPreview() {
        guard !buffer.isEmpty else { return }
        // Run conversion synchronously against the *current* buffer so the
        // preview length matches the deleteBackward count exactly. This is
        // the critical fast-typing fix: an async snapshot from earlier would
        // be shorter than `buffer`, causing commit to delete characters it
        // can't put back.
        conversionCoordinator.cancel()
        let live = convertCurrentBuffer()
        commit(live)
    }

    private func handleSpace() {
        guard !buffer.isEmpty else {
            let prevDisplayed = traceDocumentTail()
            displayedTextManager.insertCommitted(" ")
            traceKey(
                label: "space-host",
                key: "space",
                prevBuffer: buffer,
                nextBuffer: buffer,
                prevDisplayed: prevDisplayed,
                nextDisplayed: traceDocumentTail()
            )
            return
        }

        conversionCoordinator.cancel()
        let live = convertCurrentBuffer()

        // Native-style English autocorrect gate: when the last span is
        // English, only replace with a correction if the typed word is *not*
        // in the dictionary AND a guess is within the edit-distance cap.
        // Otherwise commit verbatim. This is what stops `its` → `it's`.
        if live.spans.last?.kind == .english {
            let enRaw = live.spans.last?.raw ?? ""
            let result = englishSuggestions(for: enRaw)
            if !result.isTypedWordValid, let top = result.topCorrection {
                commitEnglishCandidate(top, overrideLive: live)
            } else {
                commit(live)
            }
            displayedTextManager.insertCommitted(" ")
            return
        }

        // In Japanese composition, space acts as confirmation only. For plain
        // English runs, keep the expected keyboard behavior: finish the current
        // word and then insert a separating space.
        let hasJapaneseComposition = live.spans.contains { $0.kind == .japanese }
        commit(live)
        if !hasJapaneseComposition {
            displayedTextManager.insertCommitted(" ")
        }
    }

    private func handleReturn() {
        guard !buffer.isEmpty else {
            let prevDisplayed = traceDocumentTail()
            displayedTextManager.insertCommitted("\n")
            traceKey(
                label: "return-host",
                key: "return",
                prevBuffer: buffer,
                nextBuffer: buffer,
                prevDisplayed: prevDisplayed,
                nextDisplayed: traceDocumentTail()
            )
            return
        }

        // Dismiss suggestions without applying them — same behavior as Japanese.
        if englishCandidatesActive {
            keepRawInput()
            return
        }

        conversionCoordinator.cancel()
        let live = convertCurrentBuffer()
        if hasSuggestedOptions(live) {
            keepRawInput()
        } else {
            commit(live)
            displayedTextManager.insertCommitted("\n")
        }
    }

    private func hasSuggestedOptions(_ live: InputController.LiveConversion) -> Bool {
        live.conversions.contains { !$0.candidates.isEmpty }
    }

    private func keepRawInput() {
        let prevBuffer = buffer
        let prevDisplayed = traceDocumentTail()
        buffer = ""
        liveConversion = nil
        englishCandidatesActive = false
        candidateBar.update(candidates: [], preview: "")
        traceKey(
            label: "return-keep-raw",
            key: "return",
            prevBuffer: prevBuffer,
            nextBuffer: buffer,
            prevDisplayed: prevDisplayed,
            nextDisplayed: traceDocumentTail()
        )
    }

    /// Atomic replace: delete the raw romaji we previously inserted, then insert
    /// the converted preview + any suffix typed after the conversion snapshot.
    /// The host sees one logical edit and zero characters are dropped.
    private func commit(_ live: InputController.LiveConversion) {
        let snapshot = live.raw
        let preview = live.preview
        guard let plan = InputCommitPlanner.replacement(buffer: buffer, snapshot: snapshot, preview: preview) else {
            // Buffer no longer starts with the snapshot — shouldn't happen,
            // but if it does, prefer preserving raw input over committing.
            Self.log.error("commit: buffer doesn't start with snapshot; aborting commit to preserve raw input. buffer=\(self.buffer, privacy: .public) snapshot=\(snapshot, privacy: .public)")
            return
        }
        let prevDisplayed = traceDocumentTail()
        displayedTextManager.replaceComposition(plan: plan)
        for (idx, span) in live.spans.enumerated() {
            switch span.kind {
            case .japanese:
                let japaneseSoFar = live.spans.prefix(idx).filter { $0.kind == .japanese }.count
                if japaneseSoFar < live.conversions.count {
                    inputController.commit(japanese: live.conversions[japaneseSoFar].mainCandidate)
                }
            case .english:
                inputController.commitEnglish(span.raw)
            }
        }
        traceCommit(plan: plan, prevDisplayed: prevDisplayed, nextDisplayed: traceDocumentTail())
        buffer = plan.nextBuffer
        liveConversion = nil
        englishCandidatesActive = false
        candidateBar.update(candidates: [], preview: "")
        refreshDocumentPriorIfNeeded()
        if !buffer.isEmpty {
            scheduleConvert()
        }
    }

    // MARK: - Conversion scheduling

    private func scheduleConvert() {
        if Self.disableConversion {
            // Diagnostic: completely bypass detection/conversion + candidate UI.
            // Buffer keeps growing; commit paths still work via convertCurrentBuffer.
            return
        }
        conversionCoordinator.cancel()
        let snapshot = buffer
        if snapshot.isEmpty {
            liveConversion = nil
            englishCandidatesActive = false
            candidateBar.update(candidates: [], preview: "")
            traceConversion(label: "clear", snapshot: snapshot, result: nil)
            return
        }
        traceConversion(label: "schedule", snapshot: snapshot, result: nil)
        let leftSideContext = inputController.leftSideContext
        let prior = currentDocumentPrior
        let controller = inputController!
        let requestID = conversionCoordinator.schedule(
            snapshot: snapshot,
            leftSideContext: leftSideContext,
            documentPrior: prior,
            convert: {
                controller.convert(snapshot, documentPrior: prior)
            },
            apply: { [weak self] output in
                guard let self else { return }
                let applyState = Self.signposter.beginInterval("apply")
                defer { Self.signposter.endInterval("apply", applyState) }
                guard output.snapshot == self.buffer else {
                    self.traceConversion(
                        label: "stale-skip",
                        snapshot: output.snapshot,
                        result: output.conversion,
                        requestID: output.requestID,
                        elapsedMs: output.elapsedMs,
                        cacheHit: output.cacheHit
                    )
                    return
                }
                self.liveConversion = output.conversion
                if output.conversion.spans.last?.kind == .english {
                    let enRaw = output.conversion.spans.last?.raw ?? ""
                    let result = self.englishSuggestions(for: enRaw)
                    self.englishCandidatesActive = !result.displayCandidates.isEmpty
                    let barState = Self.signposter.beginInterval("candidateBar.update")
                    self.candidateBar.update(candidates: result.displayCandidates, preview: output.conversion.preview)
                    Self.signposter.endInterval("candidateBar.update", barState)
                } else {
                    self.englishCandidatesActive = false
                    let barState = Self.signposter.beginInterval("candidateBar.update")
                    self.candidateBar.update(
                        candidates: output.conversion.conversions.first?.candidates ?? [],
                        preview: output.conversion.preview
                    )
                    Self.signposter.endInterval("candidateBar.update", barState)
                }
                self.traceConversion(
                    label: "apply",
                    snapshot: output.snapshot,
                    result: output.conversion,
                    requestID: output.requestID,
                    elapsedMs: output.elapsedMs,
                    cacheHit: output.cacheHit
                )
            }
        )
        traceConversion(label: "request-\(requestID)", snapshot: snapshot, result: nil)
    }

    private func convertCurrentBuffer() -> InputController.LiveConversion {
        let leftSideContext = inputController.leftSideContext
        let prior = currentDocumentPrior
        if let cached = conversionCoordinator.cachedConversion(raw: buffer, leftSideContext: leftSideContext, documentPrior: prior) {
            traceConversion(label: "sync-cache", snapshot: buffer, result: cached, elapsedMs: 0, cacheHit: true)
            return cached
        }
        let start = DispatchTime.now().uptimeNanoseconds
        let live = inputController.convert(buffer, documentPrior: prior)
        let end = DispatchTime.now().uptimeNanoseconds
        conversionCoordinator.store(live, leftSideContext: leftSideContext, documentPrior: prior)
        traceConversion(
            label: "sync",
            snapshot: buffer,
            result: live,
            elapsedMs: Double(end - start) / 1_000_000,
            cacheHit: false
        )
        return live
    }

    private func clearComposition(resetContext: Bool) {
        conversionCoordinator.cancel()
        buffer = ""
        liveConversion = nil
        englishCandidatesActive = false
        candidateBar.update(candidates: [], preview: "")
        if resetContext {
            inputController.reset()
            // Committed tail just got wiped — force a fresh prior sample
            // next time so we don't reuse the stale hash.
            lastPriorSampleHash = nil
            currentDocumentPrior = .neutral
        }
    }

    // MARK: - Instrumentation

    private func traceKey(
        label: String,
        key: String,
        prevBuffer: String,
        nextBuffer: String,
        prevDisplayed: String?,
        nextDisplayed: String?,
        proxyElapsedMs: Double? = nil
    ) {
        guard Self.debugLogging else { return }
        let message = tracePrefix(label: label)
            + " key='\(key)'"
            + " prevBuffer='\(prevBuffer)'"
            + " nextBuffer='\(nextBuffer)'"
            + " prevDisplayed='\(prevDisplayed ?? "<unavailable>")'"
            + " nextDisplayed='\(nextDisplayed ?? "<unavailable>")'"
            + " proxyEditSeq=\(displayedTextManager?.proxyEditSequence ?? 0)"
            + " tapToProxyMs=\(proxyElapsedMs ?? -1)"
            + traceConversionState()
        Self.log.debug("\(message, privacy: .public)")
    }

    private func traceCommit(
        plan: InputCommitPlanner.Replacement,
        prevDisplayed: String?,
        nextDisplayed: String?
    ) {
        guard Self.debugLogging else { return }
        let message = tracePrefix(label: "commit")
            + " snapshot='\(plan.snapshot)'"
            + " preview='\(plan.preview)'"
            + " suffix='\(plan.suffix)'"
            + " deletes=\(plan.deleteCount)"
            + " inserted='\(plan.insertedText)'"
            + " nextBuffer='\(plan.nextBuffer)'"
            + " prevDisplayed='\(prevDisplayed ?? "<unavailable>")'"
            + " nextDisplayed='\(nextDisplayed ?? "<unavailable>")'"
            + " proxyEditSeq=\(displayedTextManager?.proxyEditSequence ?? 0)"
            + traceConversionState()
        Self.log.debug("\(message, privacy: .public)")
    }

    private func traceConversion(
        label: String,
        snapshot: String,
        result: InputController.LiveConversion?,
        requestID: UInt64? = nil,
        elapsedMs: Double? = nil,
        cacheHit: Bool? = nil
    ) {
        guard Self.debugLogging else { return }
        let message = tracePrefix(label: "conversion-\(label)")
            + " snapshot='\(snapshot)'"
            + " liveBuffer='\(buffer)'"
            + " preview='\(result?.preview ?? "")'"
            + " requestID=\(requestID ?? 0)"
            + " conversionMs=\(elapsedMs ?? -1)"
            + " cacheHit=\((cacheHit ?? false) ? "y" : "n")"
            + traceConversionState(candidateCountOverride: result?.conversions.first?.candidates.count)
        Self.log.debug("\(message, privacy: .public)")
    }

    private func traceExpectedEdit(before: ObservedTextState, after: ObservedTextState, matched: Bool) {
        guard Self.debugLogging else { return }
        let message = tracePrefix(label: "expected-edit")
            + " matched=\(matched ? "y" : "n")"
            + " beforeLeft='\(before.left)'"
            + " afterLeft='\(after.left)'"
            + " beforeCenter='\(before.center)'"
            + " afterCenter='\(after.center)'"
            + " beforeRight='\(before.right)'"
            + " afterRight='\(after.right)'"
            + " proxyEditSeq=\(displayedTextManager?.proxyEditSequence ?? 0)"
        Self.log.debug("\(message, privacy: .public)")
    }

    private func tracePrefix(label: String) -> String {
        traceSequence += 1
        return "seq=\(traceSequence) ts=\(Date().timeIntervalSince1970) event=\(label)"
    }

    private func traceConversionState(candidateCountOverride: Int? = nil) -> String {
        let active = liveConversion != nil
        let candCount = candidateCountOverride ?? liveConversion?.conversions.first?.candidates.count ?? 0
        let focusedCandidateIndex = -1
        return " conversionActive=\(active ? "y" : "n") candidateCount=\(candCount) focusedCandidateIndex=\(focusedCandidateIndex)"
    }

    private func traceDocumentTail() -> String? {
        guard Self.debugLogging else { return nil }
        return String((displayedTextManager?.snapshot().left ?? "").suffix(120))
    }

    // MARK: - Resources

    private static func bundledZenzaiWeightURL() -> URL? {
        Bundle(for: KeyboardViewController.self).url(forResource: "zenz-v3-small-Q5_K_M", withExtension: "gguf")
    }
}
