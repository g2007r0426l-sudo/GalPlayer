import Foundation
import UIKit
import UniformTypeIdentifiers

// =============================================================================
// 游戏导入
//
//   两条入口：
//   1. 「导入游戏」按钮 -> UIDocumentPicker 选文件夹（可多选）-> 拷进 Galgames
//   2. App 自己的 Documents（文件 App 里能看到 GalPlayer）-> 一键收进去
//
//   目标目录：/var/mobile/Documents/Galgames/<游戏名>/
// =============================================================================
final class GameImporter: NSObject {

    static let shared = GameImporter()

    static let gamesRoot = "/var/mobile/Documents/Galgames"

    var onFinished: ((_ imported: Int, _ message: String?) -> Void)?

    private weak var presenter: UIViewController?

    // ---------------------------------------------------------------------
    // 1. 文件 App 选择器
    // ---------------------------------------------------------------------
    func presentPicker(from vc: UIViewController) {
        presenter = vc
        var types: [UTType] = [.folder]
        if let zip = UTType(filenameExtension: "zip") { types.append(zip) }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = self
        vc.present(picker, animated: true)
    }

    // ---------------------------------------------------------------------
    // 2. 收编 App 自身 Documents 里用户投放的内容
    // ---------------------------------------------------------------------
    func importFromInbox(completion: @escaping (Int, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
                DispatchQueue.main.async { completion(0, "找不到 App 文档目录") }
                return
            }
            var imported = 0
            var notes: [String] = []
            if let items = try? fm.contentsOfDirectory(at: docs, includingPropertiesForKeys: [.isDirectoryKey]) {
                for url in items {
                    // 跳过 App 自己产生的目录
                    if url.lastPathComponent.hasPrefix(".") { continue }
                    let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    // 跳过：游戏库自身、隐藏项、看起来不是游戏的目录
                    if url.lastPathComponent == "Galgames" { continue }
                    if isDir && !self.looksLikeGame(url) { continue }
                    if !isDir && url.pathExtension.lowercased() != "zip" { continue }
                    do { try self.importAny(url); imported += 1 }
                    catch {
                        let msg = "\(url.lastPathComponent)：\(error.localizedDescription)"
                        notes.append(msg)
                        GameImporter.log("FAILED " + msg)
                    }
                }
            }
            DispatchQueue.main.async {
                completion(imported, notes.isEmpty ? nil : notes.prefix(2).joined(separator: "\n"))
            }
        }
    }




    static func log(_ msg: String) {
        NSLog("[GalPlayer-import] %@", msg)
        let line = ISO8601DateFormatter().string(from: Date()) + " " + msg + "\n"
        let path = "/var/mobile/Documents/gp_import.log"
        if let fh = FileHandle(forWritingAtPath: path) {
            fh.seekToEndOfFile()
            fh.write(line.data(using: .utf8) ?? Data())
            try? fh.close()
        } else {
            try? line.write(toFile: path, atomically: true, encoding: .utf8)
            try? FileManager.default.setAttributes([.posixPermissions: 0o666], ofItemAtPath: path)
        }
    }

    /// 判定目录是否像一个游戏（避免把系统目录 / Galgames 自身误导入）
    func looksLikeGame(_ dir: URL) -> Bool {
        let fm = FileManager.default
        let names = (try? fm.contentsOfDirectory(atPath: dir.path))?.map { $0.lowercased() } ?? []
        if names.contains("nscript.dat") || names.contains("0.txt")
            || names.contains("00.txt") || names.contains("nscript.___")
            || names.contains("root.pfs") {
            return true
        }
        return names.contains { $0.hasSuffix(".xp3") }
    }

    /// 统一导入：文件夹直接拷；zip 先解压（若压缩包内只有一层目录，则把该目录当游戏）
    func importAny(_ src: URL) throws {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: src.path, isDirectory: &isDir) else { return }
        GameImporter.log("importAny start: \(src.lastPathComponent)")
        if isDir.boolValue {
            try copyFolder(src)
            GameImporter.log("folder copied: \(src.lastPathComponent)")
            return
        }
        guard src.pathExtension.lowercased() == "zip" else {
            throw NSError(domain: "GalPlayer", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "只支持文件夹或 zip 压缩包"])
        }
        let stem = src.deletingPathExtension().lastPathComponent
        let tmp = fm.temporaryDirectory.appendingPathComponent("gp_unzip_\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tmp) }
        GameImporter.log("unzip begin: \(src.lastPathComponent) size=\(((try? FileManager.default.attributesOfItem(atPath: src.path)[.size] as? Int) ?? 0))")
        let n = try ZipReader.unzip(src, to: tmp)
        GameImporter.log("unzip ok: \(n) entries")

        let children = (try? fm.contentsOfDirectory(at: tmp, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        try fm.createDirectory(atPath: GameImporter.gamesRoot, withIntermediateDirectories: true)
        if children.count == 1,
           let only = children.first,
           (try? only.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            // 压缩包里就是一层游戏目录：直接用它的名字
            let dest = uniqueDestination(for: only.lastPathComponent)
            try fm.moveItem(at: only, to: dest)
        } else {
            let dest = uniqueDestination(for: stem)
            try fm.moveItem(at: tmp, to: dest)
        }
        NSLog("[GalPlayer] zip 导入完成: %@", src.lastPathComponent)
    }

    // ---------------------------------------------------------------------
    private func uniqueDestination(for name: String) -> URL {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: GameImporter.gamesRoot, isDirectory: true)
        var candidate = root.appendingPathComponent(name, isDirectory: true)
        var i = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = root.appendingPathComponent("\(name) (\(i))", isDirectory: true)
            i += 1
        }
        return candidate
    }

    /// 把外部文件夹完整拷进游戏库（递归）
    func copyFolder(_ src: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(atPath: GameImporter.gamesRoot, withIntermediateDirectories: true)
        let dest = uniqueDestination(for: src.lastPathComponent)
        try fm.copyItem(at: src, to: dest)
        // 让 mobiles 用户有读写权限（引擎以 mobile 运行）
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest.path)
        NSLog("[GalPlayer] 导入完成: %@ -> %@", src.lastPathComponent, dest.path)
    }
}

// =============================================================================
extension GameImporter: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController,
                        didPickDocumentsAt urls: [URL]) {
        DispatchQueue.global(qos: .userInitiated).async {
            var imported = 0
            var notes: [String] = []
            for url in urls {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }
                do { try self.importAny(url); imported += 1 }
                catch { notes.append("\(url.lastPathComponent)：\(error.localizedDescription)") }
                _ = isDir
            }
            DispatchQueue.main.async {
                self.onFinished?(imported, notes.isEmpty ? nil : notes.prefix(2).joined(separator: "\n"))
                self.onFinished = nil
            }
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        onFinished?(0, nil)
        onFinished = nil
    }
}
