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
    private var displayedCandidates: [String] = []
    private var displayedPreview: String = ""

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KeyboardColors.chromeBackground

        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsHorizontalScrollIndicator = false
        addSubview(scroll)

        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 27
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
            button.backgroundColor = isDefault ? .white : .clear
            button.layer.cornerRadius = isDefault ? 4.5 : 0
            button.layer.cornerCurve = .continuous
            button.contentEdgeInsets = UIEdgeInsets(
                top: 8,
                left: isDefault ? 13 : 2,
                bottom: 8,
                right: isDefault ? 13 : 2
            )
            button.setAttributedTitle(
                NSAttributedString(
                    string: candidate,
                    attributes: [
                        .font: UIFont.systemFont(ofSize: 22, weight: .regular),
                        .foregroundColor: UIColor.black,
                    ]
                ),
                for: .normal
            )
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
        }
    }
}
