import Foundation
import Compression

// =============================================================================
// 极简 ZIP 解压（只依赖系统 Compression 框架，无第三方库）
//
// 支持：store(0) / deflate(8)，单层或多层目录，中文文件名（UTF-8 或 CP437 兜底）
// 不支持：加密 zip、zip64（>4GB）、分卷
// =============================================================================
enum ZipReader {

    struct Entry {
        let name: String
        let method: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    enum ZipError: LocalizedError {
        case notZip, badCentral, unsupported(String), inflateFailed
        var errorDescription: String? {
            switch self {
            case .notZip: return "不是有效的 zip 文件"
            case .badCentral: return "zip 目录结构损坏"
            case .unsupported(let m): return "不支持的压缩方式：\(m)"
            case .inflateFailed: return "解压数据失败"
            }
        }
    }

    static func unzip(_ zipURL: URL, to destDir: URL) throws -> Int {
        let data = try Data(contentsOf: zipURL, options: .mappedIfSafe)
        let entries = try centralDirectory(data)
        let fm = FileManager.default
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)

        var count = 0
        for e in entries {
            // Windows 打的 zip 可能用反斜杠分隔，统一成 /
            let safeName = e.name.replacingOccurrences(of: "\\", with: "/")
            if safeName.hasSuffix("/") { continue }
            let full = destDir.appendingPathComponent(safeName)
            // 防目录穿越
            guard full.standardizedFileURL.path.hasPrefix(destDir.standardizedFileURL.path) else { continue }
            try fm.createDirectory(at: full.deletingLastPathComponent(),
                                   withIntermediateDirectories: true)
            let payload = try extract(data, entry: e)
            try payload.write(to: full)
            count += 1
        }
        return count
    }

    // ------------------------------------------------------------------ 中央目录
    private static func centralDirectory(_ d: Data) throws -> [Entry] {
        guard d.count > 22 else { throw ZipError.notZip }
        // 找 EOCD: 0x06054b50（从尾部往前 64KB 内）
        let minPos = max(0, d.count - 65557)
        var eocd = -1
        var i = d.count - 22
        while i >= minPos {
            if d.u32(i) == 0x06054b50 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { throw ZipError.notZip }

        let total = Int(d.u16(eocd + 10))
        var off = Int(d.u32(eocd + 16))
        var out: [Entry] = []
        for _ in 0..<total {
            guard off + 46 <= d.count, d.u32(off) == 0x02014b50 else { throw ZipError.badCentral }
            let method = d.u16(off + 10)
            let csize = Int(d.u32(off + 20))
            let usize = Int(d.u32(off + 24))
            let nameLen = Int(d.u16(off + 28))
            let extraLen = Int(d.u16(off + 30))
            let commentLen = Int(d.u16(off + 32))
            let localOff = Int(d.u32(off + 42))
            let nameData = d.subdata(in: (off + 46)..<(off + 46 + nameLen))
            let name = String(data: nameData, encoding: .utf8)
                ?? String(data: nameData, encoding: .isoLatin1)
                ?? "file\(out.count)"
            out.append(Entry(name: name, method: method, compressedSize: csize,
                             uncompressedSize: usize, localHeaderOffset: localOff))
            off += 46 + nameLen + extraLen + commentLen
        }
        return out
    }

    // ------------------------------------------------------------------ 单个条目
    private static func extract(_ d: Data, entry e: Entry) throws -> Data {
        let lo = e.localHeaderOffset
        guard lo + 30 <= d.count, d.u32(lo) == 0x04034b50 else { throw ZipError.badCentral }
        let nameLen = Int(d.u16(lo + 26))
        let extraLen = Int(d.u16(lo + 28))
        let start = lo + 30 + nameLen + extraLen
        let end = start + e.compressedSize
        guard end <= d.count else { throw ZipError.badCentral }
        let raw = d.subdata(in: start..<end)

        switch e.method {
        case 0:
            return raw
        case 8:
            // zlib 原始 deflate 流
            let capacity = max(e.uncompressedSize, raw.count * 4, 1024)
            var out = Data(count: capacity)
            let written: Int = out.withUnsafeMutableBytes { dst in
                raw.withUnsafeBytes { src in
                    compression_decode_buffer(dst.bindMemory(to: UInt8.self).baseAddress!, capacity,
                                              src.bindMemory(to: UInt8.self).baseAddress!, raw.count,
                                              nil, COMPRESSION_ZLIB)
                }
            }
            guard written > 0 else {
                // 空文件合法情况
                if e.uncompressedSize == 0 { return Data() }
                throw ZipError.inflateFailed
            }
            return out.prefix(written)
        default:
            throw ZipError.unsupported("method \(e.method)")
        }
    }
}

// 小端读取工具
private extension Data {
    func u16(_ off: Int) -> UInt16 {
        guard off + 2 <= count else { return 0 }
        return withUnsafeBytes { $0.loadUnaligned(fromByteOffset: off, as: UInt16.self) }
    }
    func u32(_ off: Int) -> UInt32 {
        guard off + 4 <= count else { return 0 }
        return withUnsafeBytes { $0.loadUnaligned(fromByteOffset: off, as: UInt32.self) }
    }
}
