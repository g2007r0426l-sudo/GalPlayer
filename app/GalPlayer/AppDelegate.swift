import UIKit

// =============================================================================
// AppDelegate — 纯代码构建（禁用 storyboard/XIB：旧系统 + 新 SDK storyboard 会启动即崩）
// =============================================================================

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Theme.configureAppearance()

        Scanner.shared.ensureRootExists()

        let win = UIWindow(frame: UIScreen.main.bounds)
        win.backgroundColor = Theme.background
        win.rootViewController = UINavigationController(rootViewController: GameListViewController())
        window = win
        win.makeKeyAndVisible()

        // 引擎退出后主窗口重新成为 key window（SDL 窗口被销毁）
        GameSession.shared.onStopped = { [weak self] in
            self?.restoreMainWindow()
        }

        return true
    }

    /// 引擎退出后恢复主 UI（GameListViewController 也可能在退出时调用）
    // 播放器退出后通过 galplayer://return 把我们叫回前台
    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        NotificationCenter.default.post(name: .libraryChanged, object: nil)
        restoreMainWindow()
        return true
    }

    func restoreMainWindow() {
        window?.makeKeyAndVisible()
        window?.bringSubviewToFront(window?.rootViewController?.view ?? UIView())
    }

    // -------------------------------------------------------------------------
    // 锁定横屏（与 Info.plist 一致；SDL 的 UIApplicationDelegate 接管时以此兜底）
    // -------------------------------------------------------------------------
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        .landscape
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // 引擎 SDL 音频会话由 SDL 自身暂停逻辑处理；此处仅保证列表状态一致
        if GameSession.shared.isRunning {
            NSLog("[GalPlayer] 进入后台，游戏仍在运行")
        }
    }
}
