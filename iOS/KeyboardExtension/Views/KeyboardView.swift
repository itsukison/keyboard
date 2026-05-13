import os
import KeyboardCore
import UIKit

extension UIInputView: @retroactive UIInputViewAudioFeedback {
    open var enableInputClicksWhenVisible: Bool { true }
}

/// Shared diagnostic logger for the touch/hit-test investigation.
/// Subsystem: `com.bilingual.keyboard`, category: `touch`.
/// Enabled when env var `KB_TOUCH_DEBUG` is set.
enum KeyboardTouchDiagnostics {
    static let log = Logger(subsystem: "com.bilingual.keyboard", category: "touch")
    static let enabled: Bool = ProcessInfo.processInfo.environment["KB_TOUCH_DEBUG"] != nil
}

enum KeyboardColors {
    static let chromeBackground = UIColor(red: 0.81, green: 0.82, blue: 0.85, alpha: 1.0)
    static let keyPressedBackground = UIColor(red: 0.74, green: 0.76, blue: 0.80, alpha: 1.0)
    static let modifierBackground = UIColor(red: 0.68, green: 0.70, blue: 0.75, alpha: 1.0)
    static let modifierPressedBackground = UIColor(red: 0.62, green: 0.64, blue: 0.69, alpha: 1.0)
}

/// On-screen keyboard with three pages: QWERTY (letters), numbers, symbols.
///
/// Uses a custom `KeyboardRow` per row instead of `UIStackView` so widths are
/// computed by exact pixel division — `UIStackView` rounded the right-most
/// keys (p, l) slightly smaller than the others.
public final class KeyboardView: UIView {

    public enum Page {
        case letters
        case numbers
        case symbols
    }

    public enum ShiftState {
        case off
        case shifted   // capitalises the next character then auto-reverts
        case locked    // caps lock; stays until tapped off
    }

    public enum KeyEvent {
        case character(String)
        case backspace
        case space
        case returnKey
        case shift
        case switchPage(Page)
        case nextKeyboard
        case dismiss
    }

    public var onKey: ((KeyEvent) -> Void)?

    private var page: Page = .letters
    public private(set) var shiftState: ShiftState = .off
    private var rowsContainer: UIStackView!
    private var touchSeq: UInt64 = 0

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KeyboardColors.chromeBackground
        rowsContainer = UIStackView()
        rowsContainer.axis = .vertical
        rowsContainer.distribution = .fillEqually
        rowsContainer.spacing = 11
        rowsContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rowsContainer)
        NSLayoutConstraint.activate([
            rowsContainer.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            rowsContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            rowsContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            rowsContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
        ])
        rebuild()
    }

    // MARK: - Keyboard-level hit targeting

    private struct ActiveTouch {
        let button: KeyButton
        let resolution: KeyboardHitMap<Int>.Resolution
        let firedOnBegin: Bool
    }

    private struct ResolvedKey {
        let button: KeyButton
        let resolution: KeyboardHitMap<Int>.Resolution
    }

    private var hitMap = KeyboardHitMap<Int>(
        bounds: KeyboardHitRect(x: 0, y: 0, width: 0, height: 0),
        rows: []
    )
    private var keyButtonsByHitID: [Int: KeyButton] = [:]
    private var hitMapNeedsRebuild = true
    private var activeTouches: [ObjectIdentifier: ActiveTouch] = [:]
    private var backspaceRepeatTouchID: ObjectIdentifier?
    private var backspaceRepeatTimer: Timer?

    /// Make the keyboard surface itself receive all touches in the key area.
    /// Visible `KeyButton` frames stay as caps; this view resolves every point
    /// in its bounds to the nearest key and drives highlight/action state.
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha >= 0.01, bounds.contains(point) else {
            return nil
        }
        return self
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        rowsContainer.layoutIfNeeded()
        rebuildHitMap()
    }

    private func rebuildHitMap() {
        var rows: [KeyboardHitMap<Int>.Row] = []
        var buttonsByID: [Int: KeyButton] = [:]
        var nextID = 0

        for rowView in rowsContainer.arrangedSubviews.compactMap({ $0 as? KeyboardRow }) {
            let buttons = rowView.subviews
                .compactMap { $0 as? KeyButton }
                .sorted { $0.frame.minX < $1.frame.minX }
            guard !buttons.isEmpty else { continue }

            var keyFrames: [KeyboardHitMap<Int>.KeyFrame] = []
            for button in buttons {
                let id = nextID
                nextID += 1
                buttonsByID[id] = button
                keyFrames.append(.init(
                    key: id,
                    rect: button.convert(button.bounds, to: self).keyboardHitRect
                ))
            }
            rows.append(.init(
                rect: rowView.convert(rowView.bounds, to: self).keyboardHitRect,
                keys: keyFrames
            ))
        }

        keyButtonsByHitID = buttonsByID
        hitMap = KeyboardHitMap(bounds: bounds.keyboardHitRect, rows: rows)
        hitMapNeedsRebuild = false
    }

    private func resolveKey(at point: CGPoint) -> ResolvedKey? {
        if hitMapNeedsRebuild || keyButtonsByHitID.isEmpty {
            layoutIfNeeded()
            rowsContainer.layoutIfNeeded()
            rebuildHitMap()
        }
        guard let resolution = hitMap.resolve(point.keyboardHitPoint),
              let button = keyButtonsByHitID[resolution.key] else {
            return nil
        }
        return ResolvedKey(button: button, resolution: resolution)
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        for touch in touches {
            let id = ObjectIdentifier(touch)
            let point = touch.location(in: self)
            guard let resolved = resolveKey(at: point) else {
                logTouch(phase: "began", touch: touch, resolved: nil)
                continue
            }
            resolved.button.setResolvedHighlighted(true)
            let firesOnBegin = resolved.button.spec.event.firesOnTouchBegin
            activeTouches[id] = ActiveTouch(
                button: resolved.button,
                resolution: resolved.resolution,
                firedOnBegin: firesOnBegin
            )
            logTouch(phase: "began", touch: touch, resolved: resolved)
            if firesOnBegin {
                fire(resolved.button)
            }
            if case .backspace = resolved.button.spec.event {
                startBackspaceRepeat(for: id)
            }
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard KeyboardTouchDiagnostics.enabled else { return }
        for touch in touches {
            let active = activeTouches[ObjectIdentifier(touch)]
            let resolved = active.map { ResolvedKey(button: $0.button, resolution: $0.resolution) }
            logTouch(phase: "moved", touch: touch, resolved: resolved)
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        for touch in touches {
            finishTouch(touch, phase: "ended", shouldFireEndAction: true)
        }
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        for touch in touches {
            finishTouch(touch, phase: "cancelled", shouldFireEndAction: false)
        }
    }

    private func finishTouch(_ touch: UITouch, phase: String, shouldFireEndAction: Bool) {
        let id = ObjectIdentifier(touch)
        guard let active = activeTouches.removeValue(forKey: id) else {
            logTouch(phase: phase, touch: touch, resolved: nil)
            return
        }
        if backspaceRepeatTouchID == id {
            stopBackspaceRepeat()
        }
        active.button.setResolvedHighlighted(false)
        let resolved = ResolvedKey(button: active.button, resolution: active.resolution)
        logTouch(phase: phase, touch: touch, resolved: resolved)
        if shouldFireEndAction, !active.firedOnBegin {
            fire(active.button)
        }
    }

    private func fire(_ button: KeyButton) {
        onKey?(button.spec.event)
        button.playFeedback()
        logKeyFired(button)
    }

    private func startBackspaceRepeat(for touchID: ObjectIdentifier) {
        stopBackspaceRepeat()
        backspaceRepeatTouchID = touchID
        backspaceRepeatTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.repeatBackspace()
            }
        }
    }

    private func repeatBackspace() {
        guard let touchID = backspaceRepeatTouchID,
              let active = activeTouches[touchID],
              case .backspace = active.button.spec.event else {
            stopBackspaceRepeat()
            return
        }
        fire(active.button)
        backspaceRepeatTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let touchID = self.backspaceRepeatTouchID,
                      let active = self.activeTouches[touchID],
                      case .backspace = active.button.spec.event else {
                    self.stopBackspaceRepeat()
                    return
                }
                self.fire(active.button)
            }
        }
    }

    private func stopBackspaceRepeat() {
        backspaceRepeatTimer?.invalidate()
        backspaceRepeatTimer = nil
        backspaceRepeatTouchID = nil
    }

    private func logTouch(phase: String, touch: UITouch, resolved: ResolvedKey?) {
        guard KeyboardTouchDiagnostics.enabled else { return }
        touchSeq += 1
        let seq = touchSeq
        let point = touch.location(in: self)
        let rawHit = keyCap(at: point)

        let hitDescription: String
        if let resolved {
            let key = resolved.button
            let frame = key.convert(key.bounds, to: self)
            hitDescription = "RESOLVED "
                + "rawHit='\(rawHit?.spec.label ?? "nil")' "
                + "resolvedKey='\(key.spec.label)' "
                + "event=\(eventDescription(key.spec.event)) "
                + "zone=\(resolved.resolution.isDirectHit ? "direct-cap" : "virtual") "
                + "rowDist=\(fmt(resolved.resolution.rowDistance))pt "
                + "centerDist=\(fmt(resolved.resolution.centerDistance))pt "
                + "edgeDist=\(fmt(resolved.resolution.edgeDistance))pt "
                + "frame=(x=\(fmt(frame.origin.x)) y=\(fmt(frame.origin.y)) "
                + "w=\(fmt(frame.size.width)) h=\(fmt(frame.size.height)))"
        } else {
            hitDescription = "UNRESOLVED rawHit='\(rawHit?.spec.label ?? "nil")'"
        }

        let message = "touch#\(seq)"
            + " phase=\(phase)"
            + " point=(\(fmt(point.x)), \(fmt(point.y)))"
            + " page=\(pageDescription)"
            + " shift=\(shiftDescription)"
            + " " + hitDescription
        KeyboardTouchDiagnostics.log.notice("\(message, privacy: .public)")
    }

    private func keyCap(at point: CGPoint) -> KeyButton? {
        for button in keyButtonsByHitID.values {
            let frame = button.convert(button.bounds, to: self)
            if frame.contains(point) {
                return button
            }
        }
        return nil
    }

    private func logKeyFired(_ button: KeyButton) {
        guard KeyboardTouchDiagnostics.enabled else { return }
        let f = button.convert(button.bounds, to: self)
        let firedMessage = "key.fired"
            + " label='\(button.spec.label)'"
            + " event=\(eventDescription(button.spec.event))"
            + " frame=(x=\(fmt(f.origin.x)) y=\(fmt(f.origin.y))"
            + " w=\(fmt(f.size.width)) h=\(fmt(f.size.height)))"
        KeyboardTouchDiagnostics.log.notice("\(firedMessage, privacy: .public)")
    }

    private func fmt(_ v: CGFloat) -> String {
        fmt(Double(v))
    }

    private func fmt(_ v: Double) -> String {
        String(format: "%.1f", v)
    }

    private var pageDescription: String {
        switch page {
        case .letters: return "letters"
        case .numbers: return "numbers"
        case .symbols: return "symbols"
        }
    }

    private var shiftDescription: String {
        switch shiftState {
        case .off: return "off"
        case .shifted: return "shifted"
        case .locked: return "locked"
        }
    }

    private func eventDescription(_ event: KeyEvent) -> String {
        switch event {
        case .character(let s): return "character('\(s)')"
        case .backspace: return "backspace"
        case .space: return "space"
        case .returnKey: return "returnKey"
        case .shift: return "shift"
        case .switchPage(let p):
            switch p {
            case .letters: return "switchPage(letters)"
            case .numbers: return "switchPage(numbers)"
            case .symbols: return "switchPage(symbols)"
            }
        case .nextKeyboard: return "nextKeyboard"
        case .dismiss: return "dismiss"
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    public func cycleShift() {
        switch shiftState {
        case .off: shiftState = .shifted
        case .shifted, .locked: shiftState = .off
        }
        rebuild()
    }

    public func setShift(_ state: ShiftState) {
        guard shiftState != state else { return }
        shiftState = state
        rebuild()
    }

    public func switchPage(_ page: Page) {
        guard self.page != page || shiftState != .off else { return }
        self.page = page
        self.shiftState = .off
        rebuild()
    }

    private func rebuild() {
        rowsContainer.arrangedSubviews.forEach {
            rowsContainer.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        let layout = KeyboardLayout.layout(for: page, shiftState: shiftState)
        for (rowIdx, row) in layout.enumerated() {
            let buttons = row.map { spec -> KeyButton in
                KeyButton(spec: spec)
            }
            // English QWERTY row 2 is inset, but the Japanese romaji layout
            // keeps ten keys by adding the long-vowel/hyphen key at the right.
            let needsInset = page == .letters && rowIdx == 1 && row.count == 9
            let rowView = KeyboardRow(
                buttons: buttons,
                spacing: 7,
                leadingInset: needsInset ? 19 : 0,
                trailingInset: needsInset ? 19 : 0
            )
            rowsContainer.addArrangedSubview(rowView)
        }
        hitMapNeedsRebuild = true
        setNeedsLayout()
    }
}

/// Lays out keys in a row at exact pixel widths (avoids UIStackView rounding
/// the right-most key smaller).
final class KeyboardRow: UIView {
    private let buttons: [KeyButton]
    private let spacing: CGFloat
    private let leadingInset: CGFloat
    private let trailingInset: CGFloat

    init(buttons: [KeyButton], spacing: CGFloat, leadingInset: CGFloat, trailingInset: CGFloat) {
        self.buttons = buttons
        self.spacing = spacing
        self.leadingInset = leadingInset
        self.trailingInset = trailingInset
        super.init(frame: .zero)
        for button in buttons { addSubview(button) }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !buttons.isEmpty else { return }
        let totalUnits = buttons.reduce(0) { $0 + $1.spec.widthFactor }
        let totalSpacing = spacing * CGFloat(buttons.count - 1)
        let available = bounds.width - leadingInset - trailingInset - totalSpacing
        let unit = available / totalUnits

        // Compute per-key widths rounded to the screen scale, distribute the
        // rounding remainder onto the widest key so all keys land on pixel
        // boundaries with no visible gap.
        let scale = UIScreen.main.scale
        var widths = buttons.map { btn -> CGFloat in
            (unit * btn.spec.widthFactor * scale).rounded(.toNearestOrEven) / scale
        }
        let remainder = available - widths.reduce(0, +)
        if abs(remainder) > 0.001, let widest = widths.indices.max(by: { widths[$0] < widths[$1] }) {
            widths[widest] += remainder
        }

        var x = leadingInset
        for (idx, button) in buttons.enumerated() {
            button.frame = CGRect(x: x, y: 0, width: widths[idx], height: bounds.height)
            x += widths[idx] + spacing
        }
    }
}

/// Specifies a single key on the keyboard.
struct KeySpec {
    let label: String
    let event: KeyboardView.KeyEvent
    /// Width factor relative to a standard letter key (1.0 = standard).
    let widthFactor: CGFloat
    /// Highlights the key as "active" (used for shift in shifted/locked).
    let isActive: Bool

    init(_ label: String, _ event: KeyboardView.KeyEvent, width: CGFloat = 1.0, isActive: Bool = false) {
        self.label = label
        self.event = event
        self.widthFactor = width
        self.isActive = isActive
    }
}

enum KeyboardLayout {
    static func layout(for page: KeyboardView.Page, shiftState: KeyboardView.ShiftState) -> [[KeySpec]] {
        switch page {
        case .letters: return letters(shiftState: shiftState)
        case .numbers: return numbers()
        case .symbols: return symbols()
        }
    }

    private static func letters(shiftState: KeyboardView.ShiftState) -> [[KeySpec]] {
        let isUpper = shiftState != .off
        let cased: (Character) -> String = { c in
            String(isUpper ? Character(String(c).uppercased()) : c)
        }
        let shiftLabel: String
        switch shiftState {
        case .off: shiftLabel = "⇧"
        case .shifted: shiftLabel = "⇧"
        case .locked: shiftLabel = "⇪"
        }
        let shiftActive = shiftState != .off

        let row1 = "qwertyuiop"
        let row2 = "asdfghjkl-"
        let row3 = "zxcvbnm"
        return [
            row1.map { c in KeySpec(cased(c), .character(cased(c))) },
            row2.map { c in KeySpec(cased(c), .character(cased(c))) },
            [KeySpec(shiftLabel, .shift, width: 1.4, isActive: shiftActive)]
                + row3.map { c in KeySpec(cased(c), .character(cased(c))) }
                + [KeySpec("⌫", .backspace, width: 1.4)],
            [
                KeySpec("123", .switchPage(.numbers), width: 1.4),
                KeySpec("🌐", .nextKeyboard, width: 1.0),
                KeySpec("space", .space, width: 5.0),
                KeySpec("return", .returnKey, width: 2.0),
            ],
        ]
    }

    private static func numbers() -> [[KeySpec]] {
        let row1 = "1234567890"
        let row2 = "-/:;()$&@\""
        let row3 = ".,?!'"
        return [
            row1.map { c in KeySpec(String(c), .character(String(c))) },
            row2.map { c in KeySpec(String(c), .character(String(c))) },
            [KeySpec("#+=", .switchPage(.symbols), width: 1.4)]
                + row3.map { c in KeySpec(String(c), .character(String(c))) }
                + [KeySpec("⌫", .backspace, width: 1.4)],
            [
                KeySpec("ABC", .switchPage(.letters), width: 1.4),
                KeySpec("🌐", .nextKeyboard, width: 1.0),
                KeySpec("space", .space, width: 5.0),
                KeySpec("return", .returnKey, width: 2.0),
            ],
        ]
    }

    private static func symbols() -> [[KeySpec]] {
        let row1 = "[]{}#%^*+="
        let row2 = "_\\|~<>€£¥•"
        let row3 = ".,?!'"
        return [
            row1.map { c in KeySpec(String(c), .character(String(c))) },
            row2.map { c in KeySpec(String(c), .character(String(c))) },
            [KeySpec("123", .switchPage(.numbers), width: 1.4)]
                + row3.map { c in KeySpec(String(c), .character(String(c))) }
                + [KeySpec("⌫", .backspace, width: 1.4)],
            [
                KeySpec("ABC", .switchPage(.letters), width: 1.4),
                KeySpec("🌐", .nextKeyboard, width: 1.0),
                KeySpec("space", .space, width: 5.0),
                KeySpec("return", .returnKey, width: 2.0),
            ],
        ]
    }
}

final class KeyButton: UIControl {
    let spec: KeySpec
    private let label = UILabel()
    private let normalColor: UIColor
    private let highlightedColor: UIColor
    private static let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    init(spec: KeySpec) {
        self.spec = spec
        let isLetterCap: Bool
        switch spec.event {
        case .character, .space: isLetterCap = true
        default: isLetterCap = false
        }

        // Native palette (light mode):
        // - letter / space caps: white, taps lightly darken
        // - modifier caps: mid-gray (#ABB0B7), taps invert toward white
        // - active modifier (shifted): inverted — white normal, gray highlight
        if isLetterCap {
            self.normalColor = .white
            self.highlightedColor = KeyboardColors.keyPressedBackground
        } else if spec.isActive {
            self.normalColor = .white
            self.highlightedColor = KeyboardColors.modifierPressedBackground
        } else {
            self.normalColor = KeyboardColors.modifierBackground
            self.highlightedColor = .white
        }

        super.init(frame: .zero)
        backgroundColor = normalColor
        layer.cornerRadius = 4.5
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.28
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0

        // Single typed characters (letters, digits, punctuation) render at 26pt
        // for a native-keyboard look. Modifier glyphs (⇧/⇪/⌫/🌐) and word
        // labels (space, return, 123, ABC, #+=) render at 16pt.
        let glyphModifiers: Set<String> = ["⇧", "⇪", "⌫", "🌐"]
        let useLargeFont = spec.label.count == 1 && !glyphModifiers.contains(spec.label)
        label.text = spec.label
        label.textAlignment = .center
        label.font = .systemFont(ofSize: useLargeFont ? 26 : 16, weight: .regular)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? highlightedColor : normalColor
        }
    }

    fileprivate func setResolvedHighlighted(_ highlighted: Bool) {
        isHighlighted = highlighted
    }

    fileprivate func playFeedback() {
        UIDevice.current.playInputClick()
        Self.feedbackGenerator.impactOccurred()
        Self.feedbackGenerator.prepare()
    }

    fileprivate static func fmt(_ v: CGFloat) -> String {
        String(format: "%.1f", Double(v))
    }
}

private extension KeyboardView.KeyEvent {
    var firesOnTouchBegin: Bool {
        switch self {
        case .character, .space, .backspace:
            return true
        case .returnKey, .shift, .switchPage, .nextKeyboard, .dismiss:
            return false
        }
    }
}

private extension CGRect {
    var keyboardHitRect: KeyboardHitRect {
        KeyboardHitRect(
            x: Double(origin.x),
            y: Double(origin.y),
            width: Double(size.width),
            height: Double(size.height)
        )
    }
}

private extension CGPoint {
    var keyboardHitPoint: KeyboardHitPoint {
        KeyboardHitPoint(x: Double(x), y: Double(y))
    }
}
