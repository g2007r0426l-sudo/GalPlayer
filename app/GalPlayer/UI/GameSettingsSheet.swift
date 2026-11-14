import UIKit

// =============================================================================
// 单游戏设置弹层: 手动指定引擎（自动识别失败兜底） / 清除识别缓存
// =============================================================================

final class GameSettingsSheet: UIViewController {

    private let entry: GameEntry
    private let cardView = UIView()

    init(entry: GameEntry) {
        self.entry = entry
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("纯代码 UI，禁用 storyboard") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.55)

        let tap = UITapGestureRecognizer(target: self, action: #selector(closeTapped))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        buildCard()
    }

    private func buildCard() {
        cardView.backgroundColor = Theme.card
        cardView.layer.cornerRadius = 16
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        // ---- 标题 ----
        let nameLabel = UILabel()
        nameLabel.text = entry.name
        nameLabel.font = .boldSystemFont(ofSize: 17)
        nameLabel.textColor = Theme.text
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(nameLabel)

        let detected = entry.detected
        let effective = EngineRegistry.shared.effectiveEngine(for: entry)
        let detectedLabel = UILabel()
        detectedLabel.numberOfLines = 0
        detectedLabel.font = .systemFont(ofSize: 12)
        detectedLabel.textColor = Theme.textSub
        detectedLabel.text = """
        自动识别: \(detected.displayName)\(effective != detected ? "（已手动指定: \(effective.displayName)）" : "")
        路径: \(entry.path)
        """
        detectedLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(detectedLabel)

        // ---- 引擎选项 ----
        let segTitle = UILabel()
        segTitle.text = "指定引擎"
        segTitle.font = .boldSystemFont(ofSize: 13)
        segTitle.textColor = Theme.text
        segTitle.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(segTitle)

        let seg = UISegmentedControl(items: ["自动", "Kirikiri", "ONScripter"])
        seg.selectedSegmentTintColor = Theme.accent
        seg.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        seg.setTitleTextAttributes([.foregroundColor: Theme.textSub], for: .normal)
        seg.translatesAutoresizingMaskIntoConstraints = false

        if let ov = EngineRegistry.shared.overrideRaw(for: entry.name) {
            switch ov {
            case .kirikiri: seg.selectedSegmentIndex = 1
            case .onscripter: seg.selectedSegmentIndex = 2
            default: seg.selectedSegmentIndex = 0
            }
        } else {
            seg.selectedSegmentIndex = 0
        }
        seg.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            switch seg.selectedSegmentIndex {
            case 1: EngineRegistry.shared.setOverride(.kirikiri, for: self.entry.name)
            case 2: EngineRegistry.shared.setOverride(.onscripter, for: self.entry.name)
            default: EngineRegistry.shared.setOverride(nil, for: self.entry.name)
            }
        }, for: .valueChanged)
        cardView.addSubview(seg)

        // ---- 清除缓存 ----
        let clearBtn = UIButton(type: .system)
        clearBtn.setTitle("清除识别缓存（下次打开重扫）", for: .normal)
        clearBtn.tintColor = Theme.accent
        clearBtn.addAction(UIAction { [weak self] _ in
            EngineRegistry.shared.clearDetectionCache(for: self?.entry.name ?? "")
            self?.closeTapped()
        }, for: .touchUpInside)
        clearBtn.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(clearBtn)

        // ---- 关闭 ----
        let closeBtn = UIButton(type: .system)
        closeBtn.setTitle("完成", for: .normal)
        closeBtn.tintColor = Theme.accent
        closeBtn.titleLabel?.font = .boldSystemFont(ofSize: 15)
        closeBtn.addAction(UIAction { [weak self] _ in self?.closeTapped() }, for: .touchUpInside)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(closeBtn)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            nameLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            nameLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            nameLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            detectedLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            detectedLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detectedLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),

            segTitle.topAnchor.constraint(equalTo: detectedLabel.bottomAnchor, constant: 18),
            segTitle.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),

            seg.topAnchor.constraint(equalTo: segTitle.bottomAnchor, constant: 10),
            seg.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            seg.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            seg.heightAnchor.constraint(equalToConstant: 36),

            clearBtn.topAnchor.constraint(equalTo: seg.bottomAnchor, constant: 18),
            clearBtn.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),

            closeBtn.topAnchor.constraint(equalTo: clearBtn.bottomAnchor, constant: 14),
            closeBtn.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            closeBtn.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16),
        ])
    }

    @objc private func closeTapped() {
        dismiss(animated: false)
    }
}
