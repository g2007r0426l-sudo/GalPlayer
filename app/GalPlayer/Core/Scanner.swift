import Foundation

// =============================================================================
// 游戏扫描 + 引擎识别
//
// 规则（一期）:
//   任意 *.xp3          -> Kirikiri2
//   nscript.dat / 0.txt -> ONScripter
//   root.pfs            -> Artemis（一期不支持，标灰）
//   都不满足            -> 未知（可手动指定）
// =============================================================================

final class Scanner {
    static let shared = Scanner()

    /// 游戏统一存放目录（越狱环境 App 以 mobile 用户运行，可直接读写）
    static let gamesRoot = "/var/mobile/Documents/Galgames"

    static var indexURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("GalPlayer/index.json")
    }

    private var index = ScanIndex()
    private let fm = FileManager.default

    private init() {
        loadIndex()
    }

    /// 首次运行创建目录；返回目录是否可用
    @discardableResult
    func ensureRootExists() -> Bool {
        if !fm.fileExists(atPath: Self.gamesRoot) {
            do {
                try fm.createDirectory(atPath: Self.gamesRoot, withIntermediateDirectories: true, attributes: nil)
                return true
            } catch {
                NSLog("[Scanner] 创建游戏目录失败: \(error)")
                return false
            }
        }
        return true
    }

    var isFirstRun: Bool {
        !UserDefaults.standard.bool(forKey: "gp.firstRunDone")
    }

    func markFirstRunDone() {
        UserDefaults.standard.set(true, forKey: "gp.firstRunDone")
    }

    // -------------------------------------------------------------------------
    // 扫描
    // -------------------------------------------------------------------------

    /// 强制重扫 or 按 mtime 增量刷新；返回按名称排序的列表
    func rescan(force: Bool = false) -> [GameEntry] {
        ensureRootExists()

        var result: [GameEntry] = []
        let contents: [URL]
        do {
            contents = try fm.contentsOfDirectory(at: URL(fileURLWithPath: Self.gamesRoot),
                                                  includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                                                  options: [.skipsHiddenFiles, .skipsPackageDescendants])
        } catch {
            NSLog("[Scanner] 读取游戏目录失败: \(error)")
            return sorted(index.entries)
        }

        for url in contents {
            var isDir: ObjCBool = false
            fm.fileExists(atPath: url.path, isDirectory: &isDir)
            guard isDir.boolValue else { continue }   // 只扫一级子文件夹

            let name = url.lastPathComponent
            let mtime = directoryMtime(url) ?? Date.distantPast

            if !force, let cached = index.entries.first(where: { $0.name == name }),
               cached.dirMtime == mtime {
                result.append(cached)                 // 目录没变，用缓存
            } else {
                let detected = detectEngine(in: url)
                result.append(GameEntry(name: name, path: url.path, detected: detected, dirMtime: mtime))
            }
        }

        index.entries = result
        index.updatedAt = Date()
        saveIndex()
        return sorted(result)
    }

    /// 单游戏目录识别缓存失效（手动指定引擎后重扫）
    func invalidate(name: String) {
        index.entries.removeAll { $0.name == name }
        saveIndex()
    }

    func findFirstXp3(inDir path: String) -> String? {
        let names = (try? fm.contentsOfDirectory(atPath: path)) ?? []
        return names
            .filter { $0.lowercased().hasSuffix(".xp3") }
            .sorted()
            .first
    }

    // -------------------------------------------------------------------------
    // 引擎识别
    // -------------------------------------------------------------------------
    private func detectEngine(in dir: URL) -> GameEngine {
        guard let names = try? fm.contentsOfDirectory(atPath: dir.path) else { return .unknown }
        let lower = names.map { $0.lowercased() }

        if lower.contains(where: { $0.hasSuffix(".xp3") }) { return .kirikiri }
        if lower.contains("nscript.dat") || lower.contains("0.txt") { return .onscripter }
        if lower.contains("root.pfs") { return .artemis }
        return .unknown
    }

    private func directoryMtime(_ url: URL) -> Date? {
        let attrs = try? fm.attributesOfItem(atPath: url.path)
        return attrs?[.modificationDate] as? Date
    }

    private func sorted(_ entries: [GameEntry]) -> [GameEntry] {
        entries.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // -------------------------------------------------------------------------
    // index.json 读写
    // -------------------------------------------------------------------------
    private func loadIndex() {
        guard let data = try? Data(contentsOf: Self.indexURL) else { return }
        if let decoded = try? JSONDecoder().decode(ScanIndex.self, from: data) {
            index = decoded
        }
    }

    private func saveIndex() {
        let dir = Self.indexURL.deletingLastPathComponent()
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(index) {
            try? data.write(to: Self.indexURL, options: .atomic)
        }
    }
}
