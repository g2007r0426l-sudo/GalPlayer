# -*- coding: utf-8 -*-
"""KRKR 交接目标改为 Kirikiroid2（免费开源），咔咔喵做后备"""
import pathlib

p = pathlib.Path(r"app/GalPlayer/Core/ExternalPlayer.swift")
s = p.read_text(encoding="utf-8")

if "kirikiroid2" not in s:
    s = s.replace(
'''    static let artroid = ExternalPlayer(bundleID: "com.artemis.artroid",
                                        subDir: "ARTEMIS",
                                        displayName: "Artroid+")''',
'''    static let artroid = ExternalPlayer(bundleID: "com.artemis.artroid",
                                        subDir: "ARTEMIS",
                                        displayName: "Artroid+")
    // 免费开源的 Kirikiroid2（zeas2 官方 IPA + ldid 重签），KRKR 首选目标
    static let kirikiroid2 = ExternalPlayer(bundleID: "tvp.XP3Player.free",
                                            subDir: "",
                                            displayName: "Kirikiroid2")

    /// KRKR 游戏的交接目标：Kirikiroid2 优先，咔咔喵后备
    static func krkrTarget() -> ExternalPlayer {
        return kirikiroid2.isInstalled ? kirikiroid2 : krkrCat
    }''')
    p.write_text(s, encoding="utf-8")
    print("ExternalPlayer updated")

g = pathlib.Path(r"app/GalPlayer/Core/GameSession.swift")
t = g.read_text(encoding="utf-8")
t = t.replace("let player: ExternalPlayer = (engine == .kirikiri) ? .krkrCat : .artroid",
              "let player: ExternalPlayer = (engine == .kirikiri) ? ExternalPlayer.krkrTarget() : .artroid")
g.write_text(t, encoding="utf-8")
print("GameSession updated")

c = pathlib.Path(r"app/GalPlayer/UI/GameCell.swift")
u = c.read_text(encoding="utf-8")
u = u.replace("(engine == .kirikiri && ExternalPlayer.krkrCat.isInstalled)",
              "(engine == .kirikiri && ExternalPlayer.krkrTarget().isInstalled)")
u = u.replace('metaLabel.text = ExternalPlayer.krkrCat.isInstalled\n                ? "点卡片 → 交给咔咔喵播放" : "需要安装咔咔喵"',
              'metaLabel.text = ExternalPlayer.krkrTarget().isInstalled\n                ? "点卡片 → 交给 Kirikiroid2 播放" : "需要安装 Kirikiroid2"')
c.write_text(u, encoding="utf-8")
print("GameCell updated")

l = pathlib.Path(r"app/GalPlayer/UI/GameListViewController.swift")
v = l.read_text(encoding="utf-8")
v = v.replace("let player: ExternalPlayer = (engine == .kirikiri) ? .krkrCat : .artroid",
              "let player: ExternalPlayer = (engine == .kirikiri) ? ExternalPlayer.krkrTarget() : .artroid")
l.write_text(v, encoding="utf-8")
print("GameList updated")
