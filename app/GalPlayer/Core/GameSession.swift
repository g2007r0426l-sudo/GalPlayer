import Foundation
import UIKit

// =============================================================================
// 游戏会话 —— 统一启动器
//
// 架构（实测得出的唯一可行方案）:
//   引擎跑在**独立 App**里（SDL2/cocos2d-x 都需要自己拥有 UIApplication 生命周期，
//   在已有 UIKit App 里进程内启动会因重复调用 UIApplicationMain 而崩溃）。
//
//   GalPlayer 只做三件事:
//     1. 把目标路径写入标记文件 /var/mobile/Documents/Galgames/.<engine>_launch
//     2. 通过 LSApplicationWorkspace 拉起对应播放器 App
//     3. 播放器读取标记（一次性消费）后直接全屏进游戏
// =============================================================================

struct SessionError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

final class GameSession {
    static let shared = GameSession()

    private(set) var current: GameEntry?
    var onStopped: (() -> Void)?

    private let gamesRoot = "/var/mobile/Documents/Galgames"

    private init() {}

    /// 引擎是否在本进程内运行（独立 App 架构下恒为 false，保留接口以兼容旧调用）
    var isRunning: Bool { false }

    func start(entry: GameEntry, completion: @escaping (Result<Void, SessionError>) -> Void) {
        let engine = EngineRegistry.shared.effectiveEngine(for: entry)

        // Artemis 引擎：本机我们跑不了，但可以把游戏交给 Artroid+（Artemis 官方 iOS 播放器）
        if engine == .artemis {
            guard ArtroidHandoff.isInstalled() else {
                completion(.failure(SessionError("这是 Artemis 引擎游戏（root.pfs）。\n本机需要安装 Artroid+ 才能玩，装好后我再帮你交接。")))
                return
            }
            do {
                try ArtroidHandoff.handOff(gamePath: entry.path, gameName: entry.name)
                completion(.success(()))
            } catch {
                completion(.failure(SessionError("交给 Artroid+ 失败：\(error.localizedDescription)")))
            }
            return
        }

        guard engine.playable else {
            completion(.failure(SessionError("无法识别引擎，请检查游戏目录里是否有 nscript.dat / 0.txt / *.xp3 / root.pfs")))
            return
        }

        // 引擎 → (标记文件, 播放器 Bundle ID)
        let markerName: String
        let bundleID: String
        switch engine {
        case .kirikiri:
            completion(.failure(SessionError("这台设备暂不支持 Kirikiri2（.xp3）：\nApp 进程拿不到 GPU，cocos 渲染起不来。\n请优先玩 ONScripter 引擎的游戏。")))
            return
        case .onscripter:
            markerName = ".ons_launch"
            bundleID = "com.yg.onsplayer"
        default:
            completion(.failure(SessionError("引擎不可用")))
            return
        }

        // 播放器是否已安装
        guard isInstalled(bundleID) else {
            let name = engine == .kirikiri ? "Kirikinux2" : "ONS 播放器"
            completion(.failure(SessionError("未找到「\(name)」App。请重新安装完整 .deb（应包含三个 App）")))
            return
        }

        do {
            let target = try launchTarget(for: entry, engine: engine)
            let markerPath = gamesRoot + "/" + markerName
            // 标记文件:
            //   1 行 启动目标
            //   2 行 拉伸全屏 1/0
            //   3 行 快进间隔毫秒（由「快进文字速度」换算）
            //   4 行 音量 0-100
            let settings = AppSettings.shared
            let stretch = settings.stretchFullscreen ? "1" : "0"
            let speed = max(0.25, min(4.0, settings.textSpeed))
            let skipMs = Int(160.0 / speed)
            let volume = Int(max(0, min(1, settings.volume)) * 100)
            let payload = target + "\n" + stretch + "\n" + String(skipMs) + "\n" + String(volume) + "\n"
            try payload.write(to: URL(fileURLWithPath: markerPath), atomically: true, encoding: .utf8)
            openBundle(bundleID)
            AppSettings.shared.markPlayed(entry.name)
            current = entry
            completion(.success(()))
        } catch {
            completion(.failure(SessionError("启动标记写入失败: \(error.localizedDescription)")))
        }
    }

    func stop() {
        // 独立进程由播放器自己的退出逻辑处理
    }

    // -------------------------------------------------------------------------
    /// 引擎启动入口规则（与各引擎的自动探测一致）
    private func launchTarget(for entry: GameEntry, engine: GameEngine) throws -> String {
        let fm = FileManager.default
        let names = (try? fm.contentsOfDirectory(atPath: entry.path)) ?? []
        let lower = names.map { $0.lowercased() }

        if engine == .kirikiri {
            if lower.contains("startup.tjs") { return entry.path }
            if let xp3 = Scanner.shared.findFirstXp3(inDir: entry.path) {
                return entry.path + "/" + xp3
            }
            return entry.path
        }
        // ONScripter: 传给引擎的是一个已 chdir 的目录，脚本由其自行探测
        return entry.path
    }

    /// 是否安装了指定 bundle 的 App（越狱环境私有 API）
    private func isInstalled(_ bundleID: String) -> Bool {
        guard let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
              let ws = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject else {
            return false
        }
        let sel = NSSelectorFromString("applicationIsInstalled:")
        if ws.responds(to: sel) {
            typealias Fn = @convention(c) (AnyObject, Selector, NSString) -> Bool
            let imp = ws.method(for: sel)
            let fn = unsafeBitCast(imp, to: Fn.self)
            return fn(ws, sel, bundleID as NSString)
        }
        return true // 无法判断时不阻塞
    }

    private func openBundle(_ bundleID: String) {
        guard let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
              let ws = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject else {
            NSLog("[GalPlayer] LSApplicationWorkspace 不可用")
            return
        }
        _ = ws.perform(NSSelectorFromString("openApplicationWithBundleID:"), with: bundleID)
    }
}
