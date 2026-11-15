import UIKit
import Metal

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

        probeGPU()   // 启动时探测 GPU（判断 KRKR 是否还有希望）
        probeXP3()

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


    /// GPU 可用性探针（判断本机是否全局禁用 Metal）
    private func probeGPU() {
        let dev = MTLCreateSystemDefaultDevice()
        let msg = "MTLDevice=\(dev?.name ?? "nil")\n"
        let sandboxDocs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? "/tmp"
        let path = sandboxDocs + "/gp_gpu.log"
        if let fh = FileHandle(forWritingAtPath: path) {
            fh.seekToEndOfFile(); fh.write(msg.data(using: .utf8) ?? Data()); try? fh.close()
        } else {
            try? msg.write(toFile: path, atomically: true, encoding: .utf8)
            try? FileManager.default.setAttributes([.posixPermissions: 0o666], ofItemAtPath: path)
        }
        NSLog("[GalPlayer] %@", msg)
    }


    /// 临时探针：验证 Swift 版 XP3 解析能否读出游戏名
    private func probeXP3() {
        let candidates = [
            "/var/mobile/Containers/Data/Application/5BB7D713-3C56-4E92-A0FA-0E5FD75B63C5/Documents/Games/Galgame/data.xp3",
            GameImporter.gamesRoot + "/Games/Galgame/data.xp3"
        ]
        var msg = "XP3 probe\n"
        for p in candidates where FileManager.default.fileExists(atPath: p) {
            let t0 = Date()
            let title = XP3.gameTitle(at: p)
            let n = (try? XP3.entries(at: p).count) ?? -1
            msg += "path=\(p)\nentries=\(n) title=\(title ?? "nil") cost=\(String(format: "%.2f", Date().timeIntervalSince(t0)))s\n"
        }
        let out = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? "/tmp") + "/gp_xp3.log"
        try? msg.write(toFile: out, atomically: true, encoding: .utf8)
        NSLog("[GalPlayer] %@", msg)
    }

    func restoreMainWindow() {
        window?.makeKeyAndVisible()
        probeGPU()
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
