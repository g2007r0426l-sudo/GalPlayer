import Foundation
import UIKit

// =============================================================================
// 外部播放器交接
//
// 本机 GPU 权限只给「正规安装」的 App（咔咔喵就是），我们侧载的 App 拿不到，
// 因此 KRKR / Artemis 这两类游戏交给已安装的专用播放器去跑：
//
//   KRKR(.xp3)  -> 咔咔喵   com.xpzdev.KrKrCat    Documents/Games/<名>/
//   Artemis     -> Artroid+ com.artemis.artroid   Documents/ARTEMIS/<名>/
//
// 本类负责：找目标 App 的数据容器 -> 搬目录（同卷 rename，秒完成不占双份）-> 拉起目标 App
// =============================================================================
struct ExternalPlayer {

    let bundleID: String
    let subDir: String       // 容器内 Documents 下的子目录
    let displayName: String

    static let krkrCat = ExternalPlayer(bundleID: "com.xpzdev.KrKrCat",
                                        subDir: "Games",
                                        displayName: "咔咔喵")
    static let artroid = ExternalPlayer(bundleID: "com.artemis.artroid",
                                        subDir: "ARTEMIS",
                                        displayName: "Artroid+")

    private static let containersRoot = "/var/mobile/Containers/Data/Application"

    enum HandoffError: LocalizedError {
        case notInstalled(String)
        case noContainer(String)
        case writeFailed(String)
        var errorDescription: String? {
            switch self {
            case .notInstalled(let n): return "没找到「\(n)」，请先安装它"
            case .noContainer(let n):  return "找不到「\(n)」的数据目录"
            case .writeFailed(let p):  return "无法写入：\(p)"
            }
        }
    }

    /// 在 /var/mobile/Containers/Data/Application 下按 bundle id 找数据容器
    func containerPath() -> String? {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(atPath: Self.containersRoot) else { return nil }
        for d in dirs {
            let meta = Self.containersRoot + "/" + d + "/.com.apple.mobile_container_manager.metadata.plist"
            if let dict = NSDictionary(contentsOfFile: meta),
               let ident = dict["MCMMetadataIdentifier"] as? String,
               ident == bundleID {
                return Self.containersRoot + "/" + d
            }
        }
        return nil
    }

    var isInstalled: Bool { containerPath() != nil }

    /// 搬游戏目录进去并拉起目标 App
    @discardableResult
    func handOff(gamePath: String, gameName: String) throws -> String {
        guard let container = containerPath() else { throw HandoffError.notInstalled(displayName) }
        let fm = FileManager.default
        let destRoot = container + "/Documents/" + subDir
        if !fm.fileExists(atPath: destRoot) {
            do { try fm.createDirectory(atPath: destRoot, withIntermediateDirectories: true) }
            catch { throw HandoffError.writeFailed(destRoot) }
        }

        // 目标同名目录已存在 -> 直接复用（避免重复搬运 3.6GB）
        var dest = destRoot + "/" + gameName
        if fm.fileExists(atPath: dest) {
            NSLog("[GalPlayer] %@ 已存在同名游戏，直接拉起", displayName)
            open()
            return dest
        }
        // 避免重名冲突
        var i = 2
        while fm.fileExists(atPath: dest) {
            dest = destRoot + "/" + gameName + " (\(i))"
            i += 1
            if i > 50 { break }
        }

        do {
            try fm.moveItem(atPath: gamePath, toPath: dest)     // 同卷 rename
        } catch {
            do {
                try fm.copyItem(atPath: gamePath, toPath: dest)
                try? fm.removeItem(atPath: gamePath)
            } catch {
                throw HandoffError.writeFailed(dest)
            }
        }
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest)
        NSLog("[GalPlayer] 已交给 %@: %@", displayName, dest)
        open()
        return dest
    }

    func open() {
        guard let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
              let ws = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject else {
            return
        }
        _ = ws.perform(NSSelectorFromString("openApplicationWithBundleID:"), with: bundleID)
    }
}
