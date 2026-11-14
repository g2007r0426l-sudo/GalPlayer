import UIKit

// =============================================================================
// 主界面（对标咔咔喵）: 左侧边栏 + 右侧暖色渐变内容区
//   内容区 = 大标题「游戏库」+ 搜索框 + 「继续上次」横幅大卡 + 游戏网格
// =============================================================================

final class GameListViewController: UIViewController {

    enum Mode: Int { case all = 0, recent = 1 }

    private var mode: Mode = .all
    private var searchText: String = ""
    private var entries: [GameEntry] = []
    private var visible: [GameEntry] = []     // 排序 + 搜索过滤后

    // ---- 侧边栏 ----
    private let sidebarView = UIView()
    private let sidebarTitle = UILabel()
    private let sidebarStack = UIStackView()
    private var navButtons: [UIButton] = []
    private let navTitles = [("square.grid.2x2", "全部游戏"), ("clock", "最近游玩"), ("gearshape.fill", "设置")]

    // ---- 内容区 ----
    private let contentWrap = UIView()
    private let gradientLayer = CAGradientLayer()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let refreshButton = UIButton(type: .system)
    private let searchBar = UISearchBar()
    private var collectionView: UICollectionView!
    private let emptyLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.sidebarBg
        buildLayout()
        buildSidebar()
        buildContent()
        buildCollection()

        NotificationCenter.default.addObserver(self, selector: #selector(engineStopped),
                                               name: .engineStopped, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(libraryChanged),
                                               name: .libraryChanged, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        rescan(force: false)
        showFirstRunGuideIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = contentWrap.bounds
    }

    // -------------------------------------------------------------------------
    // 布局骨架
    // -------------------------------------------------------------------------
    private func buildLayout() {
        sidebarView.backgroundColor = Theme.sidebarBg
        sidebarView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sidebarView)

        contentWrap.translatesAutoresizingMaskIntoConstraints = false
        contentWrap.backgroundColor = .clear
        view.addSubview(contentWrap)

        gradientLayer.colors = [Theme.gradWarm.cgColor, Theme.gradMid.cgColor, Theme.gradCool.cgColor]
        gradientLayer.locations = [0, 0.45, 1]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        contentWrap.layer.insertSublayer(gradientLayer, at: 0)

        NSLayoutConstraint.activate([
            sidebarView.topAnchor.constraint(equalTo: view.topAnchor),
            sidebarView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sidebarView.widthAnchor.constraint(equalToConstant: 290),

            contentWrap.topAnchor.constraint(equalTo: view.topAnchor),
            contentWrap.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentWrap.leadingAnchor.constraint(equalTo: sidebarView.trailingAnchor),
            contentWrap.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func buildSidebar() {
        sidebarTitle.text = "🌸 GalPlayer"
        sidebarTitle.font = Theme.uiFont(size: 30, weight: .heavy)
        sidebarTitle.textColor = Theme.text
        sidebarTitle.translatesAutoresizingMaskIntoConstraints = false
        sidebarView.addSubview(sidebarTitle)

        sidebarStack.axis = .vertical
        sidebarStack.spacing = 6
        sidebarStack.translatesAutoresizingMaskIntoConstraints = false
        sidebarView.addSubview(sidebarStack)

        let version = UILabel()
        version.text = "v0.1.0 · Kirikiri2 + ONScripter"
        version.font = .systemFont(ofSize: 11)
        version.textColor = Theme.textSub
        version.translatesAutoresizingMaskIntoConstraints = false
        sidebarView.addSubview(version)

        for (i, (icon, title)) in navTitles.enumerated() {
            let btn = UIButton(type: .system)
            btn.setImage(UIImage(systemName: icon)?.withRenderingMode(.alwaysTemplate), for: .normal)
            btn.setTitle(title, for: .normal)
            btn.titleLabel?.font = Theme.uiFont(size: 16)
            btn.contentHorizontalAlignment = .leading
            btn.imageEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 8)
            btn.titleEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
            btn.contentEdgeInsets = UIEdgeInsets(top: 12, left: 4, bottom: 12, right: 8)
            btn.layer.cornerRadius = 14
            btn.tag = i
            btn.addTarget(self, action: #selector(navTapped(_:)), for: .touchUpInside)
            sidebarStack.addArrangedSubview(btn)
            navButtons.append(btn)
        }
        applySidebarSelection()

        NSLayoutConstraint.activate([
            sidebarTitle.topAnchor.constraint(equalTo: sidebarView.safeAreaLayoutGuide.topAnchor, constant: 24),
            sidebarTitle.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor, constant: 24),

            sidebarStack.topAnchor.constraint(equalTo: sidebarTitle.bottomAnchor, constant: 24),
            sidebarStack.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor, constant: 16),
            sidebarStack.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor, constant: -16),

            version.bottomAnchor.constraint(equalTo: sidebarView.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            version.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor, constant: 24),
        ])
    }

    private func applySidebarSelection() {
        for (i, btn) in navButtons.enumerated() {
            let selected = (i == mode.rawValue)
            btn.backgroundColor = selected ? Theme.accent : .clear
            btn.setTitleColor(selected ? .white : Theme.textSub, for: .normal)
            btn.tintColor = selected ? .white : Theme.textSub
        }
    }

    private func buildContent() {
        titleLabel.text = "游戏库"
        titleLabel.font = Theme.uiFont(size: 36, weight: .heavy)
        titleLabel.textColor = Theme.text
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentWrap.addSubview(titleLabel)

        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = Theme.textSub
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentWrap.addSubview(subtitleLabel)

        refreshButton.setImage(UIImage(systemName: "arrow.clockwise")?.withRenderingMode(.alwaysTemplate),
                               for: .normal)
        refreshButton.tintColor = Theme.accentDeep
        refreshButton.backgroundColor = Theme.cardBg
        refreshButton.layer.cornerRadius = 22
        refreshButton.layer.shadowColor = UIColor.black.cgColor
        refreshButton.layer.shadowOpacity = 0.08
        refreshButton.layer.shadowRadius = 8
        refreshButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        refreshButton.accessibilityLabel = "刷新游戏列表"
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
        contentWrap.addSubview(refreshButton)

        searchBar.placeholder = "🔍 搜索游戏"
        searchBar.searchBarStyle = .minimal
        searchBar.backgroundImage = UIImage()
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        contentWrap.addSubview(searchBar)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentWrap.safeAreaLayoutGuide.topAnchor, constant: 28),
            titleLabel.leadingAnchor.constraint(equalTo: contentWrap.leadingAnchor, constant: 24),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            refreshButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            refreshButton.trailingAnchor.constraint(equalTo: contentWrap.trailingAnchor, constant: -24),
            refreshButton.widthAnchor.constraint(equalToConstant: 44),
            refreshButton.heightAnchor.constraint(equalToConstant: 44),

            searchBar.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 14),
            searchBar.leadingAnchor.constraint(equalTo: contentWrap.leadingAnchor, constant: 20),
            searchBar.trailingAnchor.constraint(equalTo: contentWrap.trailingAnchor, constant: -20),
        ])
    }

    private func buildCollection() {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, env in
            guard let self else { return nil }
            if sectionIndex == 0 {
                // 「继续上次」横幅大卡
                let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1), heightDimension: .absolute(190)))
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                       heightDimension: .absolute(190)),
                    subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20)
                return section
            } else {
                let width = env.container.contentSize.width
                let cols = self.columnCount(for: width)
                let inset: CGFloat = 20, spacing: CGFloat = 16
                let itemW = (width - inset * 2 - spacing * CGFloat(cols - 1)) / CGFloat(cols)
                let itemH = itemW * 0.60 + 64
                let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1), heightDimension: .absolute(itemH)))
                item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: NSCollectionLayoutSize(widthDimension: .absolute(width - inset * 2),
                                                       heightDimension: .absolute(itemH)),
                    subitems: Array(repeating: item, count: cols))
                group.interItemSpacing = .fixed(spacing)
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = spacing
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: inset, bottom: 32, trailing: inset)
                return section
            }
        }
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(GameCell.self, forCellWithReuseIdentifier: "GameCell")
        collectionView.register(HeroCardCell.self, forCellWithReuseIdentifier: "HeroCard")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        contentWrap.addSubview(collectionView)

        let lp = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        lp.minimumPressDuration = 0.5
        collectionView.addGestureRecognizer(lp)

        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.font = Theme.uiFont(size: 16)
        emptyLabel.textColor = Theme.textSub
        emptyLabel.text = "🎀 这里还空空哒 🎀\n\n把游戏文件夹放进\n/var/mobile/Documents/Galgames/\n\n游戏就会自动出现在这里啦～"
        emptyLabel.frame = CGRect(x: 0, y: 0, width: 500, height: 320)
        emptyLabel.autoresizingMask = [.flexibleWidth]
        collectionView.backgroundView = emptyLabel

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: contentWrap.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: contentWrap.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: contentWrap.bottomAnchor),
        ])
    }

    private func columnCount(for width: CGFloat) -> Int {
        width >= 1000 ? 4 : (width >= 700 ? 3 : 2)
    }

    // -------------------------------------------------------------------------
    // 数据
    // -------------------------------------------------------------------------
    private func rescan(force: Bool) {
        entries = Scanner.shared.rescan(force: force)
        applyFilter()
    }

    private func applyFilter() {
        var list = entries
        if mode == .recent {
            list.sort { $0.dirMtime > $1.dirMtime }
        } else {
            list.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        if !searchText.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        visible = list
        subtitleLabel.text = "\(visible.count) 部作品"
        collectionView.backgroundView?.isHidden = !visible.isEmpty
        collectionView.reloadData()
    }

    private func showFirstRunGuideIfNeeded() {
        guard Scanner.shared.isFirstRun else { return }
        Scanner.shared.markFirstRunDone()
        let alert = UIAlertController(
            title: "🌸 欢迎来到 GalPlayer",
            message: """
            请将游戏文件夹放入设备目录:
            /var/mobile/Documents/Galgames/<游戏名>/

            支持引擎:
            · Kirikiri2  —— 目录内含 *.xp3（如 data.xp3）
            · ONScripter —— 目录内含 nscript.dat 或 0.txt
            """,
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道啦", style: .default))
        present(alert, animated: true)
    }

    // -------------------------------------------------------------------------
    // 动作
    // -------------------------------------------------------------------------
    @objc private func navTapped(_ sender: UIButton) {
        if sender.tag == 2 {
            navigationController?.pushViewController(GlobalSettingsViewController(), animated: true)
            return
        }
        mode = Mode(rawValue: sender.tag) ?? .all
        applySidebarSelection()
        applyFilter()
    }

    @objc private func refreshTapped() {
        rescan(force: true)
    }

    @objc private func libraryChanged() {
        rescan(force: false)
    }

    @objc private func engineStopped() {
        if let presented = presentedViewController, presented is EngineOverlayViewController {
            presented.dismiss(animated: false)
        }
        (UIApplication.shared.delegate as? AppDelegate)?.restoreMainWindow()
    }

    @objc private func handleLongPress(_ gr: UILongPressGestureRecognizer) {
        guard gr.state == .began else { return }
        let p = gr.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: p) else { return }
        let entry: GameEntry
        if indexPath.section == 0 {
            guard let first = visible.first else { return }
            entry = first
        } else {
            entry = visible[indexPath.item]
        }
        let sheet = GameSettingsSheet(entry: entry)
        sheet.modalPresentationStyle = .overFullScreen
        present(sheet, animated: false)
    }

    private func launch(_ entry: GameEntry) {
        let engine = EngineRegistry.shared.effectiveEngine(for: entry)
        guard engine.playable else {
            let msg = engine == .artemis
                ? "Artemis 引擎（root.pfs）一期暂不支持，建议用 Artroid+ 打开。"
                : "无法识别该游戏引擎。长按卡片可手动指定引擎。"
            let alert = UIAlertController(title: entry.name, message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "好的", style: .default))
            present(alert, animated: true)
            return
        }

        let overlay = EngineOverlayViewController()
        overlay.modalPresentationStyle = .overFullScreen
        present(overlay, animated: false) {
            GameSession.shared.start(entry: entry) { [weak self] result in
                switch result {
                case .success:
                    break // SDL 窗口将全屏接管
                case .failure(let err):
                    self?.presentedViewController?.dismiss(animated: false)
                    let alert = UIAlertController(title: "启动失败", message: err.message, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "好的", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }
}

// =============================================================================
// 数据源
// =============================================================================
extension GameListViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func numberOfSections(in collectionView: UICollectionView) -> Int { 2 }

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        if section == 0 { return visible.isEmpty ? 0 : 1 }
        return visible.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "HeroCard", for: indexPath) as! HeroCardCell
            if let hero = visible.first {
                cell.configure(with: hero, engine: EngineRegistry.shared.effectiveEngine(for: hero))
            }
            return cell
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GameCell", for: indexPath) as! GameCell
        let entry = visible[indexPath.item]
        cell.configure(with: entry, engine: EngineRegistry.shared.effectiveEngine(for: entry))
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let entry = indexPath.section == 0 ? visible.first : visible[indexPath.item]
        if let entry { launch(entry) }
    }
}

extension GameListViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchText = searchText.trimmingCharacters(in: .whitespaces)
        applyFilter()
    }
}

// =============================================================================
// 「继续上次」横幅大卡
// =============================================================================
final class HeroCardCell: UICollectionViewCell {

    private let coverView = PlaceholderCoverView()
    private let overlay = UIView()
    private let overlayGradient = CAGradientLayer()
    private let chip = ChipLabel()
    private let nameLabel = UILabel()
    private let metaLabel = UILabel()
    private let playButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 20
        contentView.layer.masksToBounds = true
        contentView.backgroundColor = Theme.cardBg
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.10
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 4)

        coverView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(coverView)

        overlayGradient.colors = [
            UIColor.black.withAlphaComponent(0).cgColor,
            UIColor.black.withAlphaComponent(0.55).cgColor,
        ]
        overlayGradient.locations = [0.45, 1]
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.layer.addSublayer(overlayGradient)
        overlay.isUserInteractionEnabled = false
        contentView.addSubview(overlay)

        chip.set(text: "继续上次", color: Theme.chipDark)
        contentView.addSubview(chip)

        nameLabel.font = Theme.roundedFont(size: 20, weight: .heavy)
        nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        metaLabel.font = .systemFont(ofSize: 12)
        metaLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(metaLabel)

        playButton.setImage(UIImage(systemName: "play.fill")?.withRenderingMode(.alwaysTemplate), for: .normal)
        playButton.tintColor = .white
        playButton.backgroundColor = Theme.accent
        playButton.layer.cornerRadius = 26
        playButton.layer.shadowColor = UIColor.black.cgColor
        playButton.layer.shadowOpacity = 0.2
        playButton.layer.shadowRadius = 8
        playButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        playButton.isUserInteractionEnabled = false
        playButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(playButton)

        NSLayoutConstraint.activate([
            coverView.topAnchor.constraint(equalTo: contentView.topAnchor),
            coverView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            coverView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            coverView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            overlay.topAnchor.constraint(equalTo: contentView.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            chip.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            chip.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            chip.heightAnchor.constraint(equalToConstant: 22),

            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            nameLabel.bottomAnchor.constraint(equalTo: metaLabel.topAnchor, constant: -2),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: playButton.leadingAnchor, constant: -12),

            metaLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            metaLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),

            playButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            playButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
            playButton.widthAnchor.constraint(equalToConstant: 52),
            playButton.heightAnchor.constraint(equalToConstant: 52),
        ])
    }

    required init?(coder: NSCoder) { fatalError("纯代码 UI，禁用 storyboard") }

    override func layoutSubviews() {
        super.layoutSubviews()
        overlayGradient.frame = overlay.bounds
    }

    func configure(with entry: GameEntry, engine: GameEngine) {
        coverView.title = entry.name
        nameLabel.text = entry.name
        metaLabel.text = "上次游玩 · \(TimeAgo.string(from: entry.dirMtime)) · \(engine.displayName)"
        chip.isHidden = !engine.playable
        coverView.isDimmed = !engine.playable
    }
}

// =============================================================================
// 引擎运行遮罩层（SDL 窗口出现前的黑屏过渡）
// =============================================================================
final class EngineOverlayViewController: UIViewController {
    private let label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        label.text = "正在启动游戏…"
        label.textColor = Theme.textSub
        label.font = .systemFont(ofSize: 15)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
}
