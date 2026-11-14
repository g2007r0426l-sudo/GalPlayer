import Foundation
import UIKit

// =============================================================================
// 游戏会话 —— 统一的引擎生命周期管理
//
//   进入游戏: 主 UI 暂停 -> SDL 窗口由引擎线程全屏接管
//   退出游戏: 引擎收到 SDL_QUIT 自然退出 -> 回调 -> 回到列表
// =============================================================================

final class GameSession {
    static let shared = GameSession()

    private(set) var current: GameEntry?
    /// 引擎完全退出后的 UI 收尾（主线程）
    var onStopped: (() -> Void)?

    private init() {
        GP_SetStoppedCallback {
            // 引擎线程上回调，转主线程
            DispatchQueue.main.async {
                GameSession.shared.handleEngineStopped()
            }
        }
    }

    var isRunning: Bool { GP_EngineIsRunning() != 0 }

    func start(entry: GameEntry, completion: @escaping (Result<Void, String>) -> Void) {
        let engine = EngineRegistry.shared.effectiveEngine(for: entry)
        guard engine.playable else {
            if engine == .artemis {
                completion(.failure("Artemis 引擎（root.pfs）一期暂不支持，建议用 Artroid+ 打开"))
            } else {
                completion(.failure("无法识别引擎，请在长按菜单中手动指定"))
            }
            return
        }

        // KRKR 引擎: 双 App 架构 —— 写启动标记文件并拉起 Kirikinux2 独立 App
        if engine == .kirikiri {
            do {
                let marker = try krkrLaunchMarker(for: entry)
                try marker.write(to: URL(fileURLWithPath: "/var/mobile/Documents/Galgames/.krkr_launch"),
                                 atomically: true, encoding: .utf8)
                openBundle("com.yg.kirikinux2")
                completion(.success(()))
            } catch {
                completion(.failure("启动标记写入失败: \(error.localizedDescription)"))
            }
            return
        }

        // ONScripter: 进程内 SDL2 会话
        guard !isRunning else {
            completion(.failure("已有游戏在运行，请先退出"))
            return
        }

        let settings = AppSettings.shared
        let fontPath = Bundle.main.path(forResource: "DroidSansFallback", ofType: "ttf")

        var dataFile: String? = nil
        if engine == .kirikiri {
            dataFile = Scanner.shared.findFirstXp3(inDir: entry.path)
        }

        let kind = (engine == .kirikiri) ? GP_ENGINE_KIRIKIRI : GP_ENGINE_ONSCRIPTER
        let rc = GP_EngineStart(kind,
                                entry.path,
                                fontPath,
                                dataFile,
                                settings.stretchFullscreen ? 1 : 0,
                                settings.textSpeed)

        if rc == 0 {
            current = entry
            completion(.success(()))
        } else {
            completion(.failure(rc == -1 ? "引擎已在运行" : "启动失败（错误码 \(rc)），详见 TROUBLESHOOTING.md"))
        }
    }

    /// Kirikinux2 启动规则（与引擎 TVPCheckStartupArg 一致）:
    /// 目录含 startup.tjs → 传目录；否则传第一个 xp3 文件路径
    private func krkrLaunchMarker(for entry: GameEntry) throws -> String {
        let fm = FileManager.default
        let dirURL = URL(fileURLWithPath: entry.path)
        let hasStartupTJS = (try? fm.contentsOfDirectory(atPath: entry.path))?.contains(where: {
            $0.lowercased() == "startup.tjs"
        }) ?? false

        if hasStartupTJS {
            return entry.path
        }
        if let xp3 = Scanner.shared.findFirstXp3(inDir: entry.path) {
            return entry.path + "/" + xp3
        }
        return dirURL.path
    }

    /// 越狱环境私有 API: 拉起另一个 App（LSApplicationWorkspace）
    private func openBundle(_ bundleID: String) {
        guard let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
              let workspace = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject else {
            NSLog("[GalPlayer] LSApplicationWorkspace 不可用")
            return
        }
        _ = workspace.perform(NSSelectorFromString("openApplicationWithBundleID:"), with: bundleID)
    }

    func stop() {
        guard isRunning else { return }
        GP_EngineStop()
    }

    private func handleEngineStopped() {
        current = nil
        NotificationCenter.default.post(name: .engineStopped, object: nil)
        onStopped?()
    }
}
