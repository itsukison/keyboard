import UIKit

/// Horizontal scrolling strip that shows candidate kanji choices.
/// Tap a candidate to commit.
public final class CandidateBar: UIView {

    public var onSelect: ((String) -> Void)?

    private let scroll = UIScrollView()
    private let stack = UIStackView()

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
        _ = preview
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
                self?.onSelect?(candidate)
            }, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
    }
}
