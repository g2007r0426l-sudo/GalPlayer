# -*- coding: utf-8 -*-
"""ExternalPlayer.containerPath：多个同名容器时选最近修改的那个（避开孤儿容器）"""
import pathlib

p = pathlib.Path(r"app/GalPlayer/Core/ExternalPlayer.swift")
s = p.read_text(encoding="utf-8")

old = '''    func containerPath() -> String? {
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
    }'''

new = '''    func containerPath() -> String? {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(atPath: Self.containersRoot) else { return nil }
        // 同一 bundle id 可能有多个（残留）容器：取「元数据最新修改」的那个
        // （实机教训：孤儿容器也带同样的 metadata，选第一个会写进 App 看不到的目录）
        var best: (path: String, date: Date)?
        for d in dirs {
            let meta = Self.containersRoot + "/" + d + "/.com.apple.mobile_container_manager.metadata.plist"
            guard let dict = NSDictionary(contentsOfFile: meta),
                  let ident = dict["MCMMetadataIdentifier"] as? String,
                  ident == bundleID else { continue }
            let date = (try? fm.attributesOfItem(atPath: meta)[.modificationDate] as? Date) ?? .distantPast
            if best == nil || (date ?? .distantPast) > (best?.date ?? .distantPast) {
                best = (Self.containersRoot + "/" + d, date ?? .distantPast)
            }
        }
        return best?.path
    }'''

assert old in s, "containerPath anchor missing"
s = s.replace(old, new, 1)
p.write_text(s, encoding="utf-8")
print("containerPath fixed")
