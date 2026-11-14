import UIKit

// =============================================================================
// 主题 ——「暖阳樱粉」浅色主题（对标咔咔喵：暖奶油渐变 + 樱粉强调 + 白卡）
// =============================================================================

enum Theme {
    // 文字
    static let text     = UIColor(red: 0x1C/255.0, green: 0x1C/255.0, blue: 0x1E/255.0, alpha: 1) // #1C1C1E
    static let textSub  = UIColor(red: 0x8E/255.0, green: 0x8E/255.0, blue: 0x93/255.0, alpha: 1) // #8E8E93
    static let textOnDark = .white

    // 强调（樱粉）
    static let accent     = UIColor(red: 0xFF/255.0, green: 0x7E/255.0, blue: 0xB6/255.0, alpha: 1) // #FF7EB6
    static let accentDeep = UIColor(red: 0xF2/255.0, green: 0x6D/255.0, blue: 0x9F/255.0, alpha: 1) // #F26D9F
    static let accentSoft = UIColor(red: 0xFF/255.0, green: 0x8F/255.0, blue: 0xB8/255.0, alpha: 1)

    // 结构色
    static let background = UIColor.systemBackground          // 兼容别名（设置页等）
    static let card       = UIColor.secondarySystemBackground // 兼容别名
    static let sidebarBg = UIColor(red: 0xF4/255.0, green: 0xF4/255.0, blue: 0xF7/255.0, alpha: 1) // #F4F4F7
    static let cardBg    = UIColor.white
    static let searchBarBg = UIColor(white: 1, alpha: 0.65)
    static let pillSelectedTop = UIColor(red: 0xFF/255.0, green: 0x8F/255.0, blue: 0xB8/255.0, alpha: 1)
    static let pillSelectedBottom = UIColor(red: 0xF2/255.0, green: 0x6D/255.0, blue: 0x9F/255.0, alpha: 1)

    // 内容区暖色渐变（奶油 → 薰衣草 → 浅灰）
    static let gradWarm = UIColor(red: 0xFF/255.0, green: 0xF3/255.0, blue: 0xE0/255.0, alpha: 1) // #FFF3E0
    static let gradMid  = UIColor(red: 0xF2/255.0, green: 0xED/255.0, blue: 0xFA/255.0, alpha: 1) // #F2EDFA
    static let gradCool = UIColor(red: 0xEC/255.0, green: 0xEC/255.0, blue: 0xF2/255.0, alpha: 1) // #ECECF2

    // 封面渐变（暮紫 → 樱粉）
    static let coverTop    = UIColor(red: 0x5A/255.0, green: 0x48/255.0, blue: 0x7E/255.0, alpha: 1)
    static let coverBottom = UIColor(red: 0xE8/255.0, green: 0x7E/255.0, blue: 0xB2/255.0, alpha: 1)

    // 角标
    static let badgeKRKR = accent
    static let badgeONS  = UIColor(red: 0x5F/255.0, green: 0xB9/255.0, blue: 0x8F/255.0, alpha: 1) // #5FB98F
    static let badgeOff  = UIColor(red: 0xB0/255.0, green: 0xB3/255.0, blue: 0xBA/255.0, alpha: 1)
    static let chipDark  = UIColor(white: 0, alpha: 0.5)

    static func configureAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        navAppearance.backgroundColor = .systemBackground
        navAppearance.titleTextAttributes = [.foregroundColor: text]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = accentDeep
    }

    /// 圆润字体（可爱系）
    static func roundedFont(size: CGFloat, weight: UIFont.Weight = .bold) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let desc = base.fontDescriptor.withDesign(.rounded)
        return desc.map { UIFont(descriptor: $0, size: size) } ?? base
    }
}

/// 相对时间（"30分钟前" 风格）
enum TimeAgo {
    static func string(from date: Date) -> String {
        let sec = Int(Date().timeIntervalSince(date))
        if sec < 90 { return "刚刚" }
        let min = sec / 60
        if min < 60 { return "\(min)分钟前" }
        let hr = min / 60
        if hr < 24 { return "\(hr)小时前" }
        let day = hr / 24
        if day < 30 { return "\(day)天前" }
        let df = DateFormatter()
        df.dateFormat = "M月d日"
        return df.string(from: date)
    }
}
