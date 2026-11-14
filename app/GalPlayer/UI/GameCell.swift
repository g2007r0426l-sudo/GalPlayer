import UIKit

// =============================================================================
// 游戏卡片: 占位封面（深色+首字母） + 名称 + 引擎角标
// =============================================================================

final class GameCell: UICollectionViewCell {

    private let coverView = PlaceholderCoverView()
    private let badgeLabel = UILabel()
    private let nameLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear

        coverView.translatesAutoresizingMaskIntoConstraints = false
        coverView.layer.cornerRadius = 12
        coverView.clipsToBounds = true
        contentView.addSubview(coverView)

        badgeLabel.font = .boldSystemFont(ofSize: 11)
        badgeLabel.textColor = .white
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 8
        badgeLabel.clipsToBounds = true
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(badgeLabel)

        nameLabel.font = .systemFont(ofSize: 14, weight: .medium)
        nameLabel.textColor = Theme.text
        nameLabel.textAlignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            coverView.topAnchor.constraint(equalTo: contentView.topAnchor),
            coverView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            coverView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            coverView.bottomAnchor.constraint(equalTo: nameLabel.topAnchor, constant: -8),

            badgeLabel.topAnchor.constraint(equalTo: coverView.topAnchor, constant: 8),
            badgeLabel.trailingAnchor.constraint(equalTo: coverView.trailingAnchor, constant: -8),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            badgeLabel.heightAnchor.constraint(equalToConstant: 22),

            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            nameLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("纯代码 UI，禁用 storyboard") }

    func configure(with entry: GameEntry) {
        let engine = EngineRegistry.shared.effectiveEngine(for: entry)
        coverView.title = entry.name

        switch engine {
        case .kirikiri:
            badgeLabel.text = " KRKR "
            badgeLabel.backgroundColor = Theme.badgeKRKR
        case .onscripter:
            badgeLabel.text = " ONS "
            badgeLabel.backgroundColor = Theme.badgeONS
        case .artemis:
            badgeLabel.text = " 不支持 "
            badgeLabel.backgroundColor = Theme.badgeOff
        case .unknown:
            badgeLabel.text = " 未知 "
            badgeLabel.backgroundColor = Theme.badgeOff
        }

        let disabled = !engine.playable
        coverView.isDimmed = disabled
        nameLabel.textColor = disabled ? Theme.textSub : Theme.text
        nameLabel.text = entry.name
        isUserInteractionEnabled = true
        contentView.alpha = disabled ? 0.85 : 1.0
    }
}

// =============================================================================
// 占位封面: 深色渐变 + 首字母
// =============================================================================
final class PlaceholderCoverView: UIView {

    var title: String = "" { didSet { setNeedsDisplay() } }
    var isDimmed: Bool = false { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.card
        isOpaque = false
    }

    required init?(coder: NSCoder) { fatalError("纯代码 UI，禁用 storyboard") }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let colors = [Theme.card.cgColor, UIColor.black.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: 0),
                                   end: CGPoint(x: bounds.width, y: bounds.height),
                                   options: [])
        }

        let letter = String(title.prefix(1)).uppercased()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: bounds.width * 0.4, weight: .bold),
            .foregroundColor: isDimmed ? Theme.textSub.withAlphaComponent(0.5) : Theme.accent.withAlphaComponent(0.85),
        ]
        let size = (letter as NSString).size(withAttributes: attrs)
        (letter as NSString).draw(
            at: CGPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2),
            withAttributes: attrs)
    }
}
