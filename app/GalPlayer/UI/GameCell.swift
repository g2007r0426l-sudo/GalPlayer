import UIKit

// =============================================================================
// 游戏卡片（咔咔喵风）: 渐变封面 + 左上时间胶囊 + 右上引擎角标 + 白色信息脚条
// =============================================================================

final class ChipLabel: UILabel {
    init() {
        super.init(frame: .zero)
        font = Theme.roundedFont(size: 10, weight: .heavy)
        textColor = .white
        textAlignment = .center
        layer.cornerRadius = 9
        clipsToBounds = true
        translatesAutoresizingMaskIntoConstraints = false
    }
    required init?(coder: NSCoder) { fatalError("纯代码 UI") }

    func set(text value: String, color: UIColor) {
        self.text = "  \(value)  "
        backgroundColor = color
        isHidden = false
    }
}

final class GameCell: UICollectionViewCell {

    private let coverView = PlaceholderCoverView()
    private let dimView = UIView()
    private let timeChip = ChipLabel()
    private let engineChip = ChipLabel()
    private let nameLabel = UILabel()
    private let metaLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = Theme.cardBg
        contentView.layer.cornerRadius = 20
        contentView.layer.masksToBounds = true
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 4)

        coverView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(coverView)

        dimView.backgroundColor = UIColor(white: 0.1, alpha: 0.4)
        dimView.translatesAutoresizingMaskIntoConstraints = false
        dimView.isHidden = true
        contentView.addSubview(dimView)

        contentView.addSubview(timeChip)
        contentView.addSubview(engineChip)

        nameLabel.font = Theme.roundedFont(size: 15, weight: .semibold)
        nameLabel.textColor = Theme.text
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        metaLabel.font = .systemFont(ofSize: 12)
        metaLabel.textColor = Theme.textSub
        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(metaLabel)

        NSLayoutConstraint.activate([
            coverView.topAnchor.constraint(equalTo: contentView.topAnchor),
            coverView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            coverView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            coverView.heightAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.60),

            timeChip.topAnchor.constraint(equalTo: coverView.topAnchor, constant: 8),
            timeChip.leadingAnchor.constraint(equalTo: coverView.leadingAnchor, constant: 8),
            timeChip.heightAnchor.constraint(equalToConstant: 20),

            engineChip.topAnchor.constraint(equalTo: coverView.topAnchor, constant: 8),
            engineChip.trailingAnchor.constraint(equalTo: coverView.trailingAnchor, constant: -8),
            engineChip.heightAnchor.constraint(equalToConstant: 20),

            dimView.topAnchor.constraint(equalTo: coverView.topAnchor),
            dimView.leadingAnchor.constraint(equalTo: coverView.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: coverView.trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: coverView.bottomAnchor),

            nameLabel.topAnchor.constraint(equalTo: coverView.bottomAnchor, constant: 9),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            metaLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            metaLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            metaLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            metaLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
        ])
    }

    required init?(coder: NSCoder) { fatalError("纯代码 UI，禁用 storyboard") }

    func configure(with entry: GameEntry, engine: GameEngine) {
        coverView.title = entry.name
        timeChip.set(text: TimeAgo.string(from: entry.dirMtime), color: Theme.chipDark)

        switch engine {
        case .kirikiri:   engineChip.set(text: "KRKR", color: Theme.badgeKRKR)
        case .onscripter: engineChip.set(text: "ONS", color: Theme.badgeONS)
        case .artemis:    engineChip.set(text: "不支持", color: Theme.badgeOff)
        case .unknown:    engineChip.set(text: "未知", color: Theme.badgeOff)
        }

        let playable = engine.playable
        dimView.isHidden = playable
        nameLabel.text = entry.name
        nameLabel.textColor = playable ? Theme.text : Theme.textSub
        metaLabel.text = playable ? "本地游戏 · \(TimeAgo.string(from: entry.dirMtime))" : "建议用 Artroid+ 打开"
    }
}

// =============================================================================
// 占位封面: 暮紫→樱粉渐变 + 软萌小脸（眯眯眼/腮红/微笑） + 首字母小圆牌
// =============================================================================
final class PlaceholderCoverView: UIView {

    var title: String = "" { didSet { setNeedsDisplay() } }
    var isDimmed: Bool = false { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.cardBg
        isOpaque = false
        clipsToBounds = true
    }

    required init?(coder: NSCoder) { fatalError("纯代码 UI，禁用 storyboard") }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let colors = [Theme.coverTop.cgColor, Theme.coverBottom.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: 0),
                                   end: CGPoint(x: bounds.width, y: bounds.height),
                                   options: [])
        }

        let faceY = bounds.height * 0.44
        let eyeDX = bounds.width * 0.17
        let eyeR = max(3, bounds.width * 0.045)
        let ink = UIColor(white: 0.18, alpha: 0.85)

        for sign: CGFloat in [-1, 1] {
            let ex = bounds.midX + sign * eyeDX
            let eyeRect = CGRect(x: ex - eyeR, y: faceY - eyeR * 1.35, width: eyeR * 2, height: eyeR * 2.7)
            let eye = UIBezierPath(roundedRect: eyeRect, cornerRadius: eyeR)
            ink.setFill(); eye.fill()
            let hl = UIBezierPath(arcCenter: CGPoint(x: ex - eyeR * 0.32, y: faceY - eyeR * 0.8),
                                  radius: eyeR * 0.3, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            UIColor.white.withAlphaComponent(0.9).setFill(); hl.fill()
            let blush = UIBezierPath(arcCenter: CGPoint(x: bounds.midX + sign * bounds.width * 0.26, y: faceY + eyeR * 1.5),
                                     radius: bounds.width * 0.055, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            UIColor(red: 1, green: 0.55, blue: 0.65, alpha: 0.45).setFill(); blush.fill()
        }
        let mouth = UIBezierPath(arcCenter: CGPoint(x: bounds.midX, y: faceY + eyeR * 1.05),
                                 radius: bounds.width * 0.05,
                                 startAngle: .pi * 0.15, endAngle: .pi * 0.85, clockwise: true)
        ink.setStroke()
        mouth.lineWidth = max(1.5, bounds.width * 0.02)
        mouth.lineCapStyle = .round
        mouth.stroke()

        let letter = String(title.prefix(1)).uppercased()
        if !letter.isEmpty {
            let chipH = bounds.width * 0.18
            let attrs: [NSAttributedString.Key: Any] = [
                .font: Theme.roundedFont(size: chipH * 0.62, weight: .heavy),
                .foregroundColor: Theme.accent,
            ]
            let size = (letter as NSString).size(withAttributes: attrs)
            let chipW = size.width + chipH * 0.6
            let chipRect = CGRect(x: 10, y: bounds.height - chipH - 10, width: chipW, height: chipH)
            let chip = UIBezierPath(roundedRect: chipRect, cornerRadius: chipH / 2)
            UIColor.white.withAlphaComponent(0.92).setFill(); chip.fill()
            (letter as NSString).draw(at: CGPoint(x: chipRect.minX + chipH * 0.3,
                                                  y: chipRect.minY + (chipH - size.height) / 2),
                                      withAttributes: attrs)
        }

        if isDimmed {
            UIColor(white: 0.08, alpha: 0.5).setFill()
            ctx.fill(bounds)
        }
    }
}
