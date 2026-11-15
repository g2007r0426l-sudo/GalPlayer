import UIKit

// =============================================================================
// 游戏卡片：二次元封面 + 左上时间胶囊 + 右上引擎角标 + 白色信息脚条
// （封面视图 ChipLabel / PlaceholderCoverView 见 CoverArt.swift）
// =============================================================================

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
        layer.shadowOpacity = 0.10
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 5)

        coverView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(coverView)

        dimView.backgroundColor = .clear
        dimView.translatesAutoresizingMaskIntoConstraints = false
        dimView.isHidden = true
        contentView.addSubview(dimView)

        contentView.addSubview(timeChip)
        contentView.addSubview(engineChip)

        nameLabel.font = Theme.uiFont(size: 15, weight: .semibold)
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
            coverView.heightAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.66),

            timeChip.topAnchor.constraint(equalTo: coverView.topAnchor, constant: 9),
            timeChip.leadingAnchor.constraint(equalTo: coverView.leadingAnchor, constant: 9),
            timeChip.heightAnchor.constraint(equalToConstant: 20),

            engineChip.topAnchor.constraint(equalTo: coverView.topAnchor, constant: 9),
            engineChip.trailingAnchor.constraint(equalTo: coverView.trailingAnchor, constant: -9),
            engineChip.heightAnchor.constraint(equalToConstant: 20),

            dimView.topAnchor.constraint(equalTo: coverView.topAnchor),
            dimView.leadingAnchor.constraint(equalTo: coverView.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: coverView.trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: coverView.bottomAnchor),

            nameLabel.topAnchor.constraint(equalTo: coverView.bottomAnchor, constant: 10),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 13),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -13),

            metaLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            metaLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            metaLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            metaLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -11),
        ])
    }

    required init?(coder: NSCoder) { fatalError("纯代码 UI，禁用 storyboard") }

    // 按下缩放反馈
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.16, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.965, y: 0.965) : .identity
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        transform = .identity
        layer.removeAllAnimations()
        coverView.coverImage = nil
        coverView.title = ""
        coverView.isDimmed = false
    }

    func configure(with entry: GameEntry, engine: GameEngine) {
        coverView.title = entry.name
        coverView.coverImage = CoverArt.image(for: entry.name)
        timeChip.set(text: TimeAgo.string(from: entry.dirMtime), color: Theme.chipDark)

        switch engine {
        case .kirikiri:   engineChip.set(text: "KRKR", color: Theme.badgeKRKR)
        case .onscripter: engineChip.set(text: "ONS", color: Theme.badgeONS)
        case .artemis:    engineChip.set(text: "不支持", color: Theme.badgeOff)
        case .unknown:    engineChip.set(text: "未知", color: Theme.badgeOff)
        }

        // Kirikiri 在本机不可用（GPU 受限）：列表里直接标灰并说明，避免点开才报错
        let playable = (engine == .onscripter) || (engine == .artemis && ArtroidHandoff.isInstalled())
        coverView.isDimmed = !playable
        nameLabel.text = entry.name
        nameLabel.textColor = playable ? Theme.text : Theme.textSub
        if engine == .artemis {
            metaLabel.text = "点卡片 → 交给 Artroid+ 播放"
        } else if engine == .kirikiri {
            metaLabel.text = "本机暂不支持（GPU 受限）"
        } else {
            metaLabel.text = playable
                ? "本地游戏 · \(TimeAgo.string(from: entry.dirMtime))"
                : "建议用 Artroid+ 打开"
        }
    }
}
