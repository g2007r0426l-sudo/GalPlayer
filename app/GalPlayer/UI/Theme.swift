import UIKit

// =============================================================================
// 主题（深色）—— 背景深色 + 主强调色蓝，全部纯代码，禁 storyboard/XIB
// =============================================================================

enum Theme {
    // 咔咔喵风格深色主题
    static let background   = UIColor(red: 0x0E/255.0, green: 0x0F/255.0, blue: 0x13/255.0, alpha: 1) // #0E0F13
    static let card         = UIColor(red: 0x1A/255.0, green: 0x1C/255.0, blue: 0x22/255.0, alpha: 1) // #1A1C22
    static let accent       = UIColor(red: 0x5B/255.0, green: 0x8C/255.0, blue: 0xFF/255.0, alpha: 1) // #5B8CFF
    static let text         = UIColor(red: 0xE8/255.0, green: 0xEA/255.0, blue: 0xED/255.0, alpha: 1) // #E8EAED
    static let textSub      = UIColor(red: 0x9A/255.0, green: 0xA0/255.0, blue: 0xA8/255.0, alpha: 1)
    static let badgeKRKR    = accent
    static let badgeONS     = UIColor(red: 0x3E/255.0, green: 0xC4/255.0, blue: 0x7B/255.0, alpha: 1)
    static let badgeOff     = UIColor(red: 0x55/255.0, green: 0x5A/255.0, blue: 0x62/255.0, alpha: 1)

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
}
