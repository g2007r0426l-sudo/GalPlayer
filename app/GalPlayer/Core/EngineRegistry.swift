import Foundation

// =============================================================================
// 引擎注册表 —— 手动指定覆盖自动识别（单游戏设置弹层用）
// =============================================================================

final class EngineRegistry {
    static let shared = EngineRegistry()

    private var overrides: [String: GameEngine] = [:]
    private let fm = FileManager.default

    static var overridesURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("GalPlayer/overrides.json")
    }

    private init() {
        load()
    }

    /// 实际生效引擎: 手动指定 > 自动识别
    func effectiveEngine(for entry: GameEntry) -> GameEngine {
        overrides[entry.name] ?? entry.detected
    }

    /// 是否被手动覆盖
    func hasOverride(for name: String) -> Bool {
        overrides[name] != nil
    }

    /// 覆盖值原始枚举（UI 弹层回显用）
    func overrideRaw(for name: String) -> GameEngine? {
        overrides[name]
    }

    /// 手动指定引擎（nil = 恢复自动）
    func setOverride(_ engine: GameEngine?, for name: String) {
        if let e = engine, e.playable || e == .artemis {
            overrides[name] = e
        } else {
            overrides.removeValue(forKey: name)
        }
        save()
        Scanner.shared.invalidate(name: name)
        NotificationCenter.default.post(name: .libraryChanged, object: nil)
    }

    /// 清除识别缓存（触发重扫）
    func clearDetectionCache(for name: String) {
        Scanner.shared.invalidate(name: name)
        NotificationCenter.default.post(name: .libraryChanged, object: nil)
    }

    // -------------------------------------------------------------------------
    private func load() {
        guard let data = try? Data(contentsOf: Self.overridesURL) else { return }
        let raw = (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        overrides = raw.compactMapValues { GameEngine(rawValue: $0) }
    }

    private func save() {
        let dir = Self.overridesURL.deletingLastPathComponent()
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let raw = overrides.mapValues { $0.rawValue }
        if let data = try? JSONEncoder().encode(raw) {
            try? data.write(to: Self.overridesURL, options: .atomic)
        }
    }
}
