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
    static let chromeBackground = UIColor(red: 0.82, green: 0.83, blue: 0.86, alpha: 1.0)
    static let keyPressedBackground = UIColor(red: 0.76, green: 0.78, blue: 0.82, alpha: 1.0)
    static let modifierBackground = UIColor(red: 0.70, green: 0.72, blue: 0.77, alpha: 1.0)
    static let modifierPressedBackground = UIColor(red: 0.64, green: 0.66, blue: 0.71, alpha: 1.0)
    static let keyShadow = UIColor(white: 0.0, alpha: 1.0)
    static let popupStroke = UIColor(white: 0.70, alpha: 0.70)
}

private enum KeyboardAppearance {
    static let topInset: CGFloat = 4
    static let bottomInset: CGFloat = 14
    static let sideInset: CGFloat = 3
    static let verticalSpacing: CGFloat = 11
    static let keySpacing: CGFloat = 6
    static let homeRowInset: CGFloat = 19
    static let thirdRowModifierGap: CGFloat = 14
    static let keyCornerRadius: CGFloat = 4.5
    static let keyShadowOpacity: Float = 0.24
    static let keyShadowOffset = CGSize(width: 0, height: 1)
    static let letterFont = UIFont.systemFont(ofSize: 29, weight: .light)
    static let wordFont = UIFont.systemFont(ofSize: 17, weight: .regular)
    static let pageFont = UIFont.systemFont(ofSize: 20, weight: .regular)
    static let symbolWeight = UIImage.SymbolWeight.regular
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
        clipsToBounds = false
        rowsContainer = UIStackView()
        rowsContainer.axis = .vertical
        rowsContainer.distribution = .fillEqually
        rowsContainer.spacing = KeyboardAppearance.verticalSpacing
        rowsContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rowsContainer)
        NSLayoutConstraint.activate([
            rowsContainer.topAnchor.constraint(equalTo: topAnchor, constant: KeyboardAppearance.topInset),
            rowsContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -KeyboardAppearance.bottomInset),
            rowsContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: KeyboardAppearance.sideInset),
            rowsContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -KeyboardAppearance.sideInset),
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
    private var activePopupTouchID: ObjectIdentifier?
    private var keyPopup: KeyPopupView?

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
            showPopup(for: resolved.button, touch: touch)
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
        if activePopupTouchID == id {
            hidePopup(animated: true)
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

    private func showPopup(for button: KeyButton, touch: UITouch) {
        guard button.showsInputPopup else {
            hidePopup(animated: false)
            return
        }

        hidePopup(animated: false)

        let keyFrame = button.convert(button.bounds, to: self)
        let keyHeight = keyFrame.height
        let unclampedWidth = max(max(keyFrame.width + 26, keyFrame.width * 1.74), 60)
        let popupWidth = min(unclampedWidth, 80)
        let horizontalInset: CGFloat = 3
        let desiredX = keyFrame.midX - popupWidth / 2
        let maxX = max(horizontalInset, bounds.width - popupWidth - horizontalInset)
        let popupX = min(max(desiredX, horizontalInset), maxX)

        let bubbleHeight = max(keyHeight + 18, 62)
        let connectorHeight = max(min(keyHeight * 0.20, 9), 7)
        let desiredY = keyFrame.minY - bubbleHeight - connectorHeight
        let topLimit = superview.map { -convert(CGPoint.zero, to: $0).y } ?? -bounds.minY
        let popupY = max(desiredY, topLimit)
        let popupFrame = CGRect(
            x: popupX,
            y: popupY,
            width: popupWidth,
            height: keyFrame.maxY - popupY
        )
        let keyRect = CGRect(
            x: keyFrame.minX - popupX,
            y: keyFrame.minY - popupY,
            width: keyFrame.width,
            height: keyFrame.height
        )

        let popup = KeyPopupView(text: button.popupText)
        popup.configure(keyRect: keyRect, bubbleHeight: min(bubbleHeight, max(42, keyRect.minY - 2)))
        popup.frame = popupFrame
        popup.alpha = 1
        addSubview(popup)
        keyPopup = popup
        activePopupTouchID = ObjectIdentifier(touch)
    }

    private func hidePopup(animated: Bool) {
        activePopupTouchID = nil
        guard let popup = keyPopup else { return }
        keyPopup = nil
        popup.layer.removeAllAnimations()
        if animated {
            UIView.animate(withDuration: 0.07, delay: 0, options: [.beginFromCurrentState, .curveEaseOut]) {
                popup.alpha = 0
            } completion: { _ in
                popup.removeFromSuperview()
            }
        } else {
            popup.removeFromSuperview()
        }
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
        hidePopup(animated: false)
        rowsContainer.arrangedSubviews.forEach {
            rowsContainer.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        let layout = KeyboardLayout.layout(for: page, shiftState: shiftState)
        for (rowIdx, row) in layout.enumerated() {
            let buttons = row.map { spec -> KeyButton in
                KeyButton(spec: spec)
            }
            let interKeySpacings: [CGFloat]?
            if page == .letters && rowIdx == 2 {
                interKeySpacings = [KeyboardAppearance.thirdRowModifierGap]
                    + Array(repeating: KeyboardAppearance.keySpacing, count: max(0, row.count - 3))
                    + [KeyboardAppearance.thirdRowModifierGap]
            } else {
                interKeySpacings = nil
            }
            let needsInset = page == .letters && rowIdx == 1 && row.count == 9
            let rowView = KeyboardRow(
                buttons: buttons,
                spacing: KeyboardAppearance.keySpacing,
                interKeySpacings: interKeySpacings,
                leadingInset: needsInset ? KeyboardAppearance.homeRowInset : 0,
                trailingInset: needsInset ? KeyboardAppearance.homeRowInset : 0
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
    private let interKeySpacings: [CGFloat]?
    private let leadingInset: CGFloat
    private let trailingInset: CGFloat

    init(
        buttons: [KeyButton],
        spacing: CGFloat,
        interKeySpacings: [CGFloat]? = nil,
        leadingInset: CGFloat,
        trailingInset: CGFloat
    ) {
        self.buttons = buttons
        self.spacing = spacing
        self.interKeySpacings = interKeySpacings
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
        let gaps = normalizedGaps()
        let totalSpacing = gaps.reduce(0, +)
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
            if idx < gaps.count {
                x += widths[idx] + gaps[idx]
            }
        }
    }

    private func normalizedGaps() -> [CGFloat] {
        let gapCount = max(0, buttons.count - 1)
        guard let interKeySpacings, interKeySpacings.count == gapCount else {
            return Array(repeating: spacing, count: gapCount)
        }
        return interKeySpacings
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
        case .off: shiftLabel = "shift"
        case .shifted: shiftLabel = "shift.fill"
        case .locked: shiftLabel = "capslock.fill"
        }
        let shiftActive = shiftState != .off

        let row1 = "qwertyuiop"
        let row2 = "asdfghjkl"
        let row3 = "zxcvbnm"
        return [
            row1.map { c in KeySpec(cased(c), .character(cased(c))) },
            row2.map { c in KeySpec(cased(c), .character(cased(c))) },
            [KeySpec(shiftLabel, .shift, width: 1.32, isActive: shiftActive)]
                + row3.map { c in KeySpec(cased(c), .character(cased(c))) }
                + [KeySpec("delete.left", .backspace, width: 1.32)],
            [
                KeySpec("123", .switchPage(.numbers), width: 1.0),
                KeySpec("face.smiling", .nextKeyboard, width: 1.0),
                KeySpec("space", .space, width: 4.4),
                KeySpec("return", .returnKey, width: 2.15),
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
            [KeySpec("#+=", .switchPage(.symbols), width: 1.32)]
                + row3.map { c in KeySpec(String(c), .character(String(c))) }
                + [KeySpec("delete.left", .backspace, width: 1.32)],
            [
                KeySpec("ABC", .switchPage(.letters), width: 1.0),
                KeySpec("face.smiling", .nextKeyboard, width: 1.0),
                KeySpec("space", .space, width: 4.4),
                KeySpec("return", .returnKey, width: 2.15),
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
            [KeySpec("123", .switchPage(.numbers), width: 1.32)]
                + row3.map { c in KeySpec(String(c), .character(String(c))) }
                + [KeySpec("delete.left", .backspace, width: 1.32)],
            [
                KeySpec("ABC", .switchPage(.letters), width: 1.0),
                KeySpec("face.smiling", .nextKeyboard, width: 1.0),
                KeySpec("space", .space, width: 4.4),
                KeySpec("return", .returnKey, width: 2.15),
            ],
        ]
    }
}

final class KeyPopupView: UIView {
    private let shapeLayer = CAShapeLayer()
    private let label = UILabel()
    private var keyRect: CGRect = .zero
    private var bubbleHeight: CGFloat = 56

    init(text: String) {
        super.init(frame: .zero)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        clipsToBounds = false

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.13
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 1.25

        shapeLayer.fillColor = UIColor.white.cgColor
        shapeLayer.strokeColor = KeyboardColors.popupStroke.cgColor
        shapeLayer.lineWidth = 0.5
        layer.addSublayer(shapeLayer)

        label.text = text
        label.textAlignment = .center
        label.textColor = .black
        label.font = .systemFont(ofSize: 46, weight: .light)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(keyRect: CGRect, bubbleHeight: CGFloat) {
        self.keyRect = keyRect
        self.bubbleHeight = bubbleHeight
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let bubbleRect = CGRect(x: 0, y: 0, width: bounds.width, height: bubbleHeight)
        shapeLayer.frame = bounds
        shapeLayer.path = calloutPath(bubbleRect: bubbleRect, keyRect: keyRect).cgPath
        shapeLayer.shadowPath = shapeLayer.path
        label.frame = bubbleRect.insetBy(dx: 6, dy: 1)
    }

    private func calloutPath(bubbleRect: CGRect, keyRect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let bubbleRadius = min(14, bubbleRect.height / 4)
        let keyRadius = min(KeyboardAppearance.keyCornerRadius, keyRect.height / 4)
        let bubbleBottom = bubbleRect.maxY
        let connectorTopY = bubbleBottom - bubbleRadius * 0.06
        let keyTopY = keyRect.minY + keyRadius

        path.move(to: CGPoint(x: bubbleRect.minX + bubbleRadius, y: bubbleRect.minY))
        path.addLine(to: CGPoint(x: bubbleRect.maxX - bubbleRadius, y: bubbleRect.minY))
        path.addQuadCurve(
            to: CGPoint(x: bubbleRect.maxX, y: bubbleRect.minY + bubbleRadius),
            controlPoint: CGPoint(x: bubbleRect.maxX, y: bubbleRect.minY)
        )
        path.addLine(to: CGPoint(x: bubbleRect.maxX, y: bubbleBottom - bubbleRadius))
        path.addCurve(
            to: CGPoint(x: bubbleRect.maxX - bubbleRadius, y: connectorTopY),
            controlPoint1: CGPoint(x: bubbleRect.maxX, y: bubbleBottom - 2),
            controlPoint2: CGPoint(x: bubbleRect.maxX - 2, y: connectorTopY)
        )
        path.addCurve(
            to: CGPoint(x: keyRect.maxX, y: keyTopY),
            controlPoint1: CGPoint(x: bubbleRect.maxX - bubbleRadius - 1, y: bubbleBottom + 15),
            controlPoint2: CGPoint(x: keyRect.maxX, y: keyRect.minY - 7)
        )
        path.addLine(to: CGPoint(x: keyRect.maxX, y: keyRect.maxY - keyRadius))
        path.addQuadCurve(
            to: CGPoint(x: keyRect.maxX - keyRadius, y: keyRect.maxY),
            controlPoint: CGPoint(x: keyRect.maxX, y: keyRect.maxY)
        )
        path.addLine(to: CGPoint(x: keyRect.minX + keyRadius, y: keyRect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: keyRect.minX, y: keyRect.maxY - keyRadius),
            controlPoint: CGPoint(x: keyRect.minX, y: keyRect.maxY)
        )
        path.addLine(to: CGPoint(x: keyRect.minX, y: keyTopY))
        path.addCurve(
            to: CGPoint(x: bubbleRect.minX + bubbleRadius, y: connectorTopY),
            controlPoint1: CGPoint(x: keyRect.minX, y: keyRect.minY - 7),
            controlPoint2: CGPoint(x: bubbleRect.minX + bubbleRadius + 1, y: bubbleBottom + 15)
        )
        path.addCurve(
            to: CGPoint(x: bubbleRect.minX, y: bubbleBottom - bubbleRadius),
            controlPoint1: CGPoint(x: bubbleRect.minX + 2, y: connectorTopY),
            controlPoint2: CGPoint(x: bubbleRect.minX, y: bubbleBottom - 2)
        )
        path.addLine(to: CGPoint(x: bubbleRect.minX, y: bubbleRect.minY + bubbleRadius))
        path.addQuadCurve(
            to: CGPoint(x: bubbleRect.minX + bubbleRadius, y: bubbleRect.minY),
            controlPoint: CGPoint(x: bubbleRect.minX, y: bubbleRect.minY)
        )
        path.close()
        return path
    }
}

final class KeyButton: UIControl {
    let spec: KeySpec
    private let label = UILabel()
    private let symbolView = UIImageView()
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
        layer.cornerRadius = KeyboardAppearance.keyCornerRadius
        layer.cornerCurve = .continuous
        layer.shadowColor = KeyboardColors.keyShadow.cgColor
        layer.shadowOpacity = KeyboardAppearance.keyShadowOpacity
        layer.shadowOffset = KeyboardAppearance.keyShadowOffset
        layer.shadowRadius = 0

        label.text = spec.label
        label.textAlignment = .center
        label.font = Self.font(for: spec)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        addSubview(label)

        symbolView.contentMode = .scaleAspectFit
        symbolView.tintColor = .black
        symbolView.translatesAutoresizingMaskIntoConstraints = false
        symbolView.isUserInteractionEnabled = false
        addSubview(symbolView)

        if let image = Self.symbolImage(for: spec) {
            label.isHidden = true
            symbolView.image = image
        } else {
            symbolView.isHidden = true
        }

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            symbolView.centerXAnchor.constraint(equalTo: centerXAnchor),
            symbolView.centerYAnchor.constraint(equalTo: centerYAnchor),
            symbolView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.62),
            symbolView.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor, multiplier: 0.62),
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

    fileprivate var showsInputPopup: Bool {
        if case .character = spec.event { return true }
        return false
    }

    fileprivate var popupText: String {
        label.text ?? spec.label
    }

    fileprivate static func fmt(_ v: CGFloat) -> String {
        String(format: "%.1f", Double(v))
    }

    private static func font(for spec: KeySpec) -> UIFont {
        switch spec.event {
        case .character:
            return spec.label.count == 1 ? KeyboardAppearance.letterFont : KeyboardAppearance.wordFont
        case .space, .returnKey:
            return KeyboardAppearance.wordFont
        case .switchPage:
            return KeyboardAppearance.pageFont
        case .backspace, .shift, .nextKeyboard, .dismiss:
            return KeyboardAppearance.wordFont
        }
    }

    private static func symbolImage(for spec: KeySpec) -> UIImage? {
        let pointSize: CGFloat
        let symbolName: String
        switch spec.event {
        case .shift:
            symbolName = spec.label
            pointSize = 26
        case .backspace:
            symbolName = spec.label
            pointSize = 25
        case .nextKeyboard:
            symbolName = spec.label
            pointSize = 23
        case .character, .space, .returnKey, .switchPage, .dismiss:
            return nil
        }
        let config = UIImage.SymbolConfiguration(
            pointSize: pointSize,
            weight: KeyboardAppearance.symbolWeight,
            scale: .default
        )
        return UIImage(systemName: symbolName, withConfiguration: config)
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
