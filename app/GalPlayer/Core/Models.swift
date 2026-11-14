import Foundation

// =============================================================================
// 数据模型
// =============================================================================

/// 引擎类型
enum GameEngine: String, Codable, CaseIterable {
    case kirikiri
    case onscripter
    case artemis      // 一期不支持
    case unknown

    var displayName: String {
        switch self {
        case .kirikiri:   return "KRKR"
        case .onscripter: return "ONS"
        case .artemis:    return "不支持"
        case .unknown:    return "未知"
        }
    }

    var playable: Bool { self == .kirikiri || self == .onscripter }
}

/// 列表项
struct GameEntry: Codable, Equatable, Identifiable {
    var id: String { name }
    let name: String
    let path: String
    var detected: GameEngine
    var dirMtime: Date
}

/// 扫描缓存 index.json
struct ScanIndex: Codable {
    var entries: [GameEntry] = []
    var updatedAt: Date = Date()
}

/// 全局设置（UserDefaults 持久化）
final class AppSettings {
    static let shared = AppSettings()
    private let d = UserDefaults.standard

    var stretchFullscreen: Bool {
        get { d.object(forKey: "gp.stretch") as? Bool ?? false }   // 默认原始比例
        set { d.set(newValue, forKey: "gp.stretch") }
    }

    /// 0.25 ~ 4.0（作用于长按快进节流）
    var textSpeed: Float {
        get { d.object(forKey: "gp.textSpeed") as? Float ?? 1.0 }
        set { d.set(newValue, forKey: "gp.textSpeed") }
    }

    /// 0.0 ~ 1.0（系统媒体音量）
    var volume: Float {
        get { d.object(forKey: "gp.volume") as? Float ?? 0.75 }
        set { d.set(newValue, forKey: "gp.volume") }
    }
}

extension Notification.Name {
    static let engineStopped = Notification.Name("gp.engineStopped")
    static let libraryChanged = Notification.Name("gp.libraryChanged")
}
