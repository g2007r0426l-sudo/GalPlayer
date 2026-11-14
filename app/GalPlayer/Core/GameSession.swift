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
        guard !isRunning else {
            completion(.failure("已有游戏在运行，请先退出"))
            return
        }

        let engine = EngineRegistry.shared.effectiveEngine(for: entry)
        guard engine.playable else {
            if engine == .artemis {
                completion(.failure("Artemis 引擎（root.pfs）一期暂不支持，建议用 Artroid+ 打开"))
            } else {
                completion(.failure("无法识别引擎，请在长按菜单中手动指定"))
            }
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
