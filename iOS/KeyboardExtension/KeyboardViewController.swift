import UIKit
import os
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
    private var keyboardView: KeyboardView!
    private var candidateBar: CandidateBar!
    private var conversionTask: Task<Void, Never>?
    private var lastShiftTap: TimeInterval = 0
    private static let doubleTapWindow: TimeInterval = 0.35
    private static let log = Logger(subsystem: "com.bilingual.keyboard", category: "input")
    private static let debugLogging: Bool = ProcessInfo.processInfo.environment["KEYBOARD_DEBUG_LOG"] != nil

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()

        let weightURL = Self.bundledZenzaiWeightURL()
        let useZenzai = weightURL != nil
        let adapter = KanaKanjiAdapter(zenzaiWeightURL: weightURL)
        self.inputController = InputController(adapter: adapter, useZenzai: useZenzai)

        setupViews()

        // Compact Japanese keyboard surface (~276pt: 53 candidate
        // bar + 223 key area). Priority < required so the system can override
        // for landscape / floating contexts.
        let heightConstraint = view.heightAnchor.constraint(equalToConstant: 276)
        heightConstraint.priority = .init(999)
        heightConstraint.isActive = true
    }

    public override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        // Only treat empty context as "fresh document" when we have no
        // composing buffer of our own. Without this guard, hosts that briefly
        // report an empty `documentContextBeforeInput` during fast input
        // would wipe `buffer` while raw chars remain in the host, desyncing
        // the next commit's deleteBackward count.
        guard buffer.isEmpty else { return }
        let context = textDocumentProxy.documentContextBeforeInput ?? ""
        if context.isEmpty {
            inputController.reset()
            liveConversion = nil
            candidateBar.update(candidates: [], preview: "")
        }
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
            buffer.append(ch)
            textDocumentProxy.insertText(ch)
            traceKey(label: "char", key: ch, prevBuffer: prev, nextBuffer: buffer)
            // One-shot shift: revert to off after a single character.
            if keyboardView.shiftState == .shifted {
                keyboardView.setShift(.off)
            }
            scheduleConvert()
        case .backspace:
            let prev = buffer
            if !buffer.isEmpty {
                buffer.removeLast()
                textDocumentProxy.deleteBackward()
                traceKey(label: "bksp", key: "⌫", prevBuffer: prev, nextBuffer: buffer)
                scheduleConvert()
            } else {
                textDocumentProxy.deleteBackward()
                traceKey(label: "bksp-host", key: "⌫", prevBuffer: prev, nextBuffer: buffer)
            }
        case .space:
            handleSpace()
        case .returnKey:
            commitPreview()
            textDocumentProxy.insertText("\n")
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

    private func commitPreview() {
        guard !buffer.isEmpty else { return }
        // Run conversion synchronously against the *current* buffer so the
        // preview length matches the deleteBackward count exactly. This is
        // the critical fast-typing fix: an async snapshot from earlier would
        // be shorter than `buffer`, causing commit to delete characters it
        // can't put back.
        conversionTask?.cancel()
        let live = inputController.convert(buffer)
        commit(live)
    }

    private func handleSpace() {
        guard !buffer.isEmpty else {
            textDocumentProxy.insertText(" ")
            return
        }

        // In Japanese composition, space acts as confirmation only. For plain
        // English runs, keep the expected keyboard behavior: finish the current
        // word and then insert a separating space.
        conversionTask?.cancel()
        let live = inputController.convert(buffer)
        let hasJapaneseComposition = live.spans.contains { $0.kind == .japanese }
        commit(live)
        if !hasJapaneseComposition {
            textDocumentProxy.insertText(" ")
        }
    }

    /// Atomic replace: delete the raw romaji we previously inserted, then insert
    /// the converted preview + any suffix typed after the conversion snapshot.
    /// The host sees one logical edit and zero characters are dropped.
    private func commit(_ live: InputController.LiveConversion) {
        let snapshot = live.raw
        let suffix: String
        if buffer.hasPrefix(snapshot) {
            suffix = String(buffer.dropFirst(snapshot.count))
        } else {
            // Buffer no longer starts with the snapshot — shouldn't happen,
            // but if it does, prefer preserving raw input over committing.
            Self.log.error("commit: buffer doesn't start with snapshot; aborting commit to preserve raw input. buffer=\(self.buffer, privacy: .public) snapshot=\(snapshot, privacy: .public)")
            return
        }
        let preview = live.preview
        let deletes = buffer.count
        for _ in 0 ..< deletes {
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(preview)
        if !suffix.isEmpty {
            textDocumentProxy.insertText(suffix)
        }
        for (idx, span) in live.spans.enumerated() where span.kind == .japanese {
            let japaneseSoFar = live.spans.prefix(idx).filter { $0.kind == .japanese }.count
            if japaneseSoFar < live.conversions.count {
                inputController.commit(japanese: live.conversions[japaneseSoFar].mainCandidate)
            }
        }
        traceCommit(snapshot: snapshot, preview: preview, suffix: suffix, deletes: deletes)
        buffer = suffix
        liveConversion = nil
        candidateBar.update(candidates: [], preview: "")
        if !buffer.isEmpty {
            scheduleConvert()
        }
    }

    // MARK: - Conversion scheduling

    private func scheduleConvert() {
        conversionTask?.cancel()
        let snapshot = buffer
        if snapshot.isEmpty {
            liveConversion = nil
            candidateBar.update(candidates: [], preview: "")
            return
        }
        conversionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000)
            if Task.isCancelled { return }
            guard let self else { return }
            let result = self.inputController.convert(snapshot)
            await MainActor.run {
                guard !Task.isCancelled, snapshot == self.buffer else { return }
                self.liveConversion = result
                self.candidateBar.update(
                    candidates: result.conversions.first?.candidates ?? [],
                    preview: result.preview
                )
            }
        }
    }

    // MARK: - Instrumentation

    private func traceKey(label: String, key: String, prevBuffer: String, nextBuffer: String) {
        guard Self.debugLogging else { return }
        let active = liveConversion != nil
        let candCount = liveConversion?.conversions.first?.candidates.count ?? 0
        Self.log.debug("\(label, privacy: .public) key=\(key, privacy: .public) buf:'\(prevBuffer, privacy: .public)'→'\(nextBuffer, privacy: .public)' conv=\(active ? "y" : "n", privacy: .public) cands=\(candCount, privacy: .public)")
    }

    private func traceCommit(snapshot: String, preview: String, suffix: String, deletes: Int) {
        guard Self.debugLogging else { return }
        Self.log.debug("commit snap='\(snapshot, privacy: .public)' preview='\(preview, privacy: .public)' suffix='\(suffix, privacy: .public)' deletes=\(deletes, privacy: .public)")
    }

    // MARK: - Resources

    private static func bundledZenzaiWeightURL() -> URL? {
        Bundle(for: KeyboardViewController.self).url(forResource: "zenz-v3-small-Q5_K_M", withExtension: "gguf")
    }
}
