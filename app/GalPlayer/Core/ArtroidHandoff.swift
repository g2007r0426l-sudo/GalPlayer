import Foundation
import UIKit

// =============================================================================
// Artroid+ 交接（Artemis 引擎游戏）
//
// 本机 GPU 受限，我们自己的 App 跑不了 Artemis；但用户已安装 Artroid+（com.artemis.artroid），
// 它是 Artemis 引擎的官方 iOS 播放器。这里负责：
//   1. 找到 Artroid+ 的数据容器
//   2. 把游戏目录搬进 <container>/Documents/ARTEMIS/<游戏名>/
//   3. 拉起 Artroid+
// =============================================================================
enum ArtroidHandoff {

    static let bundleID = "com.artemis.artroid"
    private static let containersRoot = "/var/mobile/Containers/Data/Application"

    enum HandoffError: LocalizedError {
        case notInstalled
        case noContainer
        case noPermission(String)
        var errorDescription: String? {
            switch self {
            case .notInstalled: return "没找到 Artroid+（com.artemis.artroid），请先安装它"
            case .noContainer: return "找不到 Artroid+ 的数据目录"
            case .noPermission(let p): return "无权写入：\(p)"
            }
        }
    }

    /// 找到 Artroid+ 的数据容器路径
    static func containerPath() -> String? {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(atPath: containersRoot) else { return nil }
        for d in dirs {
            let meta = containersRoot + "/" + d + "/.com.apple.mobile_container_manager.metadata.plist"
            if let dict = NSDictionary(contentsOfFile: meta),
               let ident = dict["MCMMetadataIdentifier"] as? String,
               ident == bundleID {
                return containersRoot + "/" + d
            }
        }
        return nil
    }

    static func isInstalled() -> Bool { containerPath() != nil }

    /// 把游戏目录搬进 Artroid+ 的 Documents/ARTEMIS/ 并拉起 App
    @discardableResult
    static func handOff(gamePath: String, gameName: String) throws -> String {
        guard let container = containerPath() else { throw HandoffError.notInstalled }
        let fm = FileManager.default
        let artemisDir = container + "/Documents/ARTEMIS"
        if !fm.fileExists(atPath: artemisDir) {
            do { try fm.createDirectory(atPath: artemisDir, withIntermediateDirectories: true) }
            catch { throw HandoffError.noPermission(artemisDir) }
        }

        // 同名目标存在时先清掉（Artroid 每次只认一个当前游戏目录也安全）
        var dest = artemisDir + "/" + gameName
        var i = 2
        while fm.fileExists(atPath: dest) {
            dest = artemisDir + "/" + gameName + " (\(i))"
            i += 1
            if i > 50 { break }
        }

        do {
            try fm.moveItem(atPath: gamePath, toPath: dest)     // 同卷 rename，瞬间完成且不占双份空间
        } catch {
            // 跨卷或权限问题：退回复制
            do {
                try fm.copyItem(atPath: gamePath, toPath: dest)
                try? fm.removeItem(atPath: gamePath)
            } catch {
                throw HandoffError.noPermission(dest)
            }
        }
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest)
        NSLog("[GalPlayer] 已交给 Artroid+: %@ -> %@", gameName, dest)

        openArtroid()
        return dest
    }

    static func openArtroid() {
        guard let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
              let ws = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject else {
            return
        }
        _ = ws.perform(NSSelectorFromString("openApplicationWithBundleID:"), with: bundleID)
    }
}
