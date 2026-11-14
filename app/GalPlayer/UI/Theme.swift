import UIKit

// =============================================================================
// 主题（夜樱）—— 深夜底色 + 樱粉强调，全部纯代码，禁 storyboard/XIB
// =============================================================================

enum Theme {
    // 夜樱深色主题
    static let background   = UIColor(red: 0x0E/255.0, green: 0x0F/255.0, blue: 0x13/255.0, alpha: 1) // #0E0F13
    static let card         = UIColor(red: 0x1B/255.0, green: 0x1D/255.0, blue: 0x26/255.0, alpha: 1) // #1B1D26
    static let accent       = UIColor(red: 0xFF/255.0, green: 0x7E/255.0, blue: 0xB6/255.0, alpha: 1) // #FF7EB6 樱粉
    static let accentSoft   = UIColor(red: 0xFF/255.0, green: 0xA8/255.0, blue: 0xCF/255.0, alpha: 1) // #FFA8CF
    static let mint         = UIColor(red: 0x7F/255.0, green: 0xE3/255.0, blue: 0xC0/255.0, alpha: 1) // #7FE3C0 薄荷
    static let text         = UIColor(red: 0xE8/255.0, green: 0xEA/255.0, blue: 0xED/255.0, alpha: 1) // #E8EAED
    static let textSub      = UIColor(red: 0x9A/255.0, green: 0xA0/255.0, blue: 0xA8/255.0, alpha: 1)
    static let badgeKRKR    = accent
    static let badgeONS     = mint
    static let badgeOff     = UIColor(red: 0x55/255.0, green: 0x5A/255.0, blue: 0x62/255.0, alpha: 1)

    // 封面渐变（暮紫 → 樱粉）
    static let coverTop     = UIColor(red: 0x5A/255.0, green: 0x48/255.0, blue: 0x7E/255.0, alpha: 1) // #5A487E
    static let coverBottom  = UIColor(red: 0xE8/255.0, green: 0x7E/255.0, blue: 0xB2/255.0, alpha: 1) // #E87EB2

    static func configureAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = background
        navAppearance.titleTextAttributes = [.foregroundColor: text]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: text]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = accent
    }

    /// 圆润字体（可爱系）
    static func roundedFont(size: CGFloat, weight: UIFont.Weight = .bold) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let desc = base.fontDescriptor.withDesign(.rounded)
        return desc.map { UIFont(descriptor: $0, size: size) } ?? base
    }
}
