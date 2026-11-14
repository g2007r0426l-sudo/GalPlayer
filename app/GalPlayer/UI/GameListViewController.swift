import UIKit

// =============================================================================
// 主界面: 游戏网格（iPad 横屏 4 列自适应）
// =============================================================================

final class GameListViewController: UIViewController {

    private var entries: [GameEntry] = []

    private var collectionView: UICollectionView!

    private let refreshControlButton = { () -> UIButton in
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        b.accessibilityLabel = "刷新游戏列表"
        return b
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "🌸 GalPlayer"
        view.backgroundColor = Theme.background

        setupNavbar()
        setupCollectionView()

        // 引擎退出 -> 回到列表（收起遮罩层）
        NotificationCenter.default.addObserver(self, selector: #selector(engineStopped),
                                               name: .engineStopped, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(libraryChanged),
                                               name: .libraryChanged, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        rescan(force: false)
        showFirstRunGuideIfNeeded()
    }

    // -------------------------------------------------------------------------
    // UI 构建（纯代码）
    // -------------------------------------------------------------------------
    private func setupNavbar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: refreshControlButton)
        refreshControlButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)

        let gear = UIBarButtonItem(image: UIImage(systemName: "gearshape.fill"),
                                   style: .plain, target: self,
                                   action: #selector(settingsTapped))
        gear.accessibilityLabel = "全局设置"
        navigationItem.leftBarButtonItem = gear
    }

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 20
        layout.sectionInset = UIEdgeInsets(top: 16, left: 24, bottom: 32, right: 24)

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(GameCell.self, forCellWithReuseIdentifier: "GameCell")
        view.addSubview(collectionView)

        let lp = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        lp.minimumPressDuration = 0.5
        collectionView.addGestureRecognizer(lp)

        // 空列表可爱引导
        let empty = UILabel()
        empty.numberOfLines = 0
        empty.textAlignment = .center
        empty.font = Theme.roundedFont(size: 15)
        empty.textColor = Theme.textSub
        empty.text = "🎀 这里还空空哒 🎀\n\n把游戏文件夹放进\n/var/mobile/Documents/Galgames/\n\n再点右上角 ⟳ 刷新，游戏就会出现啦～"
        empty.frame = CGRect(x: 24, y: 0, width: view.bounds.width - 48, height: 320)
        empty.autoresizingMask = [.flexibleWidth]
        empty.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        collectionView.backgroundView = empty
    }

    /// iPad 横屏 4 列，窄屏自适应降列
    private func columnCount(for width: CGFloat) -> Int {
        width >= 1000 ? 4 : (width >= 700 ? 3 : 2)
    }

    // -------------------------------------------------------------------------
    // 数据
    // -------------------------------------------------------------------------
    private func rescan(force: Bool) {
        entries = Scanner.shared.rescan(force: force)
        collectionView.reloadData()
        collectionView.backgroundView?.isHidden = !entries.isEmpty
    }

    private func showFirstRunGuideIfNeeded() {
        guard Scanner.shared.isFirstRun else { return }
        Scanner.shared.markFirstRunDone()
        let alert = UIAlertController(
            title: "欢迎使用 GalPlayer",
            message: """
            请将游戏文件夹放入设备目录:
            /var/mobile/Documents/Galgames/<游戏名>/

            支持引擎:
            · Kirikiri2  —— 目录内含 *.xp3（如 data.xp3）
            · ONScripter —— 目录内含 nscript.dat 或 0.txt

            放好后回到本页点右上角刷新。
            """,
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }

    // -------------------------------------------------------------------------
    // 动作
    // -------------------------------------------------------------------------
    @objc private func refreshTapped() {
        rescan(force: true)
    }

    @objc private func settingsTapped() {
        navigationController?.pushViewController(GlobalSettingsViewController(), animated: true)
    }

    @objc private func libraryChanged() {
        rescan(force: false)
    }

    @objc private func engineStopped() {
        // 遮罩层关闭 + 主窗口重新成为 key window
        if let presented = presentedViewController, presented is EngineOverlayViewController {
            presented.dismiss(animated: false)
        }
        (UIApplication.shared.delegate as? AppDelegate)?.restoreMainWindow()
    }

    @objc private func handleLongPress(_ gr: UILongPressGestureRecognizer) {
        guard gr.state == .began else { return }
        let p = gr.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: p) else { return }
        let entry = entries[indexPath.item]
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
                case .failure(let msg):
                    self?.presentedViewController?.dismiss(animated: false)
                    let alert = UIAlertController(title: "启动失败", message: msg, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "好的", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }
}

// =============================================================================
// UICollectionViewDataSource / Delegate
// =============================================================================
extension GameListViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        entries.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GameCell", for: indexPath) as! GameCell
        cell.configure(with: entries[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        launch(entries[indexPath.item])
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let insets: CGFloat = 48 + 16 * CGFloat(columnCount(for: view.bounds.width) - 1)
        let cols = CGFloat(columnCount(for: view.bounds.width))
        let w = (view.bounds.width - insets) / cols
        return CGSize(width: w, height: w * 1.45) // 封面 + 名称 + 角标
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
