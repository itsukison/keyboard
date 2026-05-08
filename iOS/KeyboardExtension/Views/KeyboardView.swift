import UIKit

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

    required init?(coder: NSCoder) { fatalError() }

    public func cycleShift() {
        switch shiftState {
        case .off: shiftState = .shifted
        case .shifted, .locked: shiftState = .off
        }
        rebuild()
    }

    public func setShift(_ state: ShiftState) {
        shiftState = state
        rebuild()
    }

    public func switchPage(_ page: Page) {
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
                let button = KeyButton(spec: spec)
                button.onEvent = { [weak self] event in self?.onKey?(event) }
                return button
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
    var onEvent: ((KeyboardView.KeyEvent) -> Void)?
    private let label = UILabel()
    private let normalColor: UIColor
    private let highlightedColor: UIColor
    private let firesOnTouchDown: Bool
    private var repeatTimer: Timer?

    init(spec: KeySpec) {
        self.spec = spec
        switch spec.event {
        case .character, .space, .backspace:
            self.firesOnTouchDown = true
        default:
            self.firesOnTouchDown = false
        }

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

        // Character / backspace fire on touchDown for native latency feel.
        // Modifier keys (return / shift / page-switch / globe) commit on
        // touchUpInside so a tap can be cancelled by sliding off.
        if firesOnTouchDown {
            addTarget(self, action: #selector(fired), for: .touchDown)
        } else {
            addTarget(self, action: #selector(fired), for: .touchUpInside)
        }

        // Long-press repeat for backspace: native iOS waits ~400ms then
        // deletes characters at ~10Hz.
        if case .backspace = spec.event {
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            longPress.minimumPressDuration = 0.4
            longPress.cancelsTouchesInView = false
            addGestureRecognizer(longPress)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? highlightedColor : normalColor
        }
    }

    @objc private func fired() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onEvent?(spec.event)
    }

    @objc private func handleLongPress(_ gr: UILongPressGestureRecognizer) {
        switch gr.state {
        case .began:
            // Fire one immediately to feel responsive at the 400ms threshold,
            // then auto-repeat at 10Hz.
            onEvent?(.backspace)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.onEvent?(.backspace)
            }
        case .ended, .cancelled, .failed:
            repeatTimer?.invalidate()
            repeatTimer = nil
        default: break
        }
    }
}
