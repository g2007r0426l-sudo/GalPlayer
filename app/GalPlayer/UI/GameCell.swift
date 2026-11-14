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
        coverView.layer.cornerRadius = 18
        coverView.clipsToBounds = true
        contentView.addSubview(coverView)

        badgeLabel.font = Theme.roundedFont(size: 11, weight: .heavy)
        badgeLabel.textColor = .white
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 10
        badgeLabel.clipsToBounds = true
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(badgeLabel)

        nameLabel.font = Theme.roundedFont(size: 14, weight: .semibold)
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
// 占位封面: 暮紫→樱粉渐变 + 软萌小脸（眯眯眼/腮红/微笑） + 首字母小圆牌
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

        // 渐变底
        let colors = [Theme.coverTop.cgColor, Theme.coverBottom.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: 0),
                                   end: CGPoint(x: bounds.width, y: bounds.height),
                                   options: [])
        }

        // 软萌小脸
        let faceY = bounds.height * 0.40
        let eyeDX = bounds.width * 0.17
        let eyeR = max(3, bounds.width * 0.045)
        let ink = UIColor(white: 0.18, alpha: 0.85)

        for sign: CGFloat in [-1, 1] {
            let ex = bounds.midX + sign * eyeDX
            // 竖椭圆眼睛
            let eyeRect = CGRect(x: ex - eyeR, y: faceY - eyeR * 1.35, width: eyeR * 2, height: eyeR * 2.7)
            let eye = UIBezierPath(roundedRect: eyeRect, cornerRadius: eyeR)
            ink.setFill(); eye.fill()
            // 眼内高光
            let hl = UIBezierPath(arcCenter: CGPoint(x: ex - eyeR * 0.32, y: faceY - eyeR * 0.8),
                                  radius: eyeR * 0.3, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            UIColor.white.withAlphaComponent(0.9).setFill(); hl.fill()
            // 腮红
            let blush = UIBezierPath(arcCenter: CGPoint(x: bounds.midX + sign * bounds.width * 0.26, y: faceY + eyeR * 1.5),
                                     radius: bounds.width * 0.055, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            UIColor(red: 1, green: 0.55, blue: 0.65, alpha: 0.45).setFill(); blush.fill()
        }
        // 微笑
        let mouth = UIBezierPath(arcCenter: CGPoint(x: bounds.midX, y: faceY + eyeR * 1.05),
                                 radius: bounds.width * 0.05,
                                 startAngle: .pi * 0.15, endAngle: .pi * 0.85, clockwise: true)
        ink.setStroke()
        mouth.lineWidth = max(1.5, bounds.width * 0.02)
        mouth.lineCapStyle = .round
        mouth.stroke()

        // 首字母小圆牌（左下角）
        let letter = String(title.prefix(1)).uppercased()
        if !letter.isEmpty {
            let chipH = bounds.width * 0.2
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

        // 不支持的游戏: 灰色纱罩
        if isDimmed {
            UIColor(white: 0.08, alpha: 0.5).setFill()
            ctx.fill(bounds)
        }
    }
}
