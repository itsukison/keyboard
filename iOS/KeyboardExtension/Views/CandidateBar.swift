import UIKit
import os

/// Horizontal scrolling strip that shows candidate kanji choices.
/// Tap a candidate to commit.
public final class CandidateBar: UIView {

    public var onSelect: ((String) -> Void)?

    private static let touchLog = Logger(subsystem: "com.bilingual.keyboard", category: "touch")
    private static let touchDebugEnabled: Bool = ProcessInfo.processInfo.environment["KB_TOUCH_DEBUG"] != nil

    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let bottomSeparator = UIView()
    private var displayedCandidates: [String] = []
    private var displayedPreview: String = ""

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KeyboardColors.chromeBackground

        bottomSeparator.backgroundColor = UIColor(white: 0.58, alpha: 0.28)
        bottomSeparator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bottomSeparator)

        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceHorizontal = false
        addSubview(scroll)

        stack.axis = .horizontal
        stack.alignment = .fill
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),

            bottomSeparator.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomSeparator.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomSeparator.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomSeparator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    public func update(candidates: [String], preview: String) {
        guard candidates != displayedCandidates || preview != displayedPreview else { return }
        if candidates == displayedCandidates {
            displayedPreview = preview
            return
        }
        displayedCandidates = candidates
        displayedPreview = preview

        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (idx, candidate) in candidates.enumerated() {
            let isDefault = idx == 0
            let button = UIButton(type: .system)
            button.backgroundColor = .clear
            var title = AttributedString(candidate)
            title.font = UIFont.systemFont(ofSize: 20, weight: .regular)
            title.foregroundColor = UIColor.black
            var configuration = UIButton.Configuration.plain()
            configuration.attributedTitle = title
            configuration.baseForegroundColor = .black
            configuration.contentInsets = NSDirectionalEdgeInsets(
                top: 6,
                leading: 18,
                bottom: 7,
                trailing: 18
            )
            button.configuration = configuration
            if isDefault {
                button.accessibilityTraits.insert(.selected)
            }
            button.addAction(UIAction { [weak self] _ in
                if Self.touchDebugEnabled {
                    let msg = "candidateBar.select index=\(idx) text='\(candidate)'"
                    Self.touchLog.notice("\(msg, privacy: .public)")
                }
                self?.onSelect?(candidate)
            }, for: .touchUpInside)
            stack.addArrangedSubview(button)

            if idx < candidates.count - 1 {
                let separator = UIView()
                separator.backgroundColor = UIColor(white: 0.55, alpha: 0.28)
                separator.translatesAutoresizingMaskIntoConstraints = false
                separator.widthAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
                stack.addArrangedSubview(separator)
            }
        }
    }
}
