import Foundation
import Compression

// =============================================================================
// XP3 归档读取（Kirikiri2 容器格式）
//
// 结构：
//   [0..11)    magic "XP3\r\n \n\x1a\x8b\x67\x01"
//   [11..19)   u64 index_offset (LE)
//   index:     u8 flag(method) + [u64 csize + u64 rawsize]? + data
//              data = 若干 "File" chunk：
//                 4B "File" + u64 size + { 4B "info" + u64 size + info,
//                                          4B "segm" + u64 size + segm,
//                                          4B "aldr" + u64 size + 4B }
//              info = u32 flags, u64 orgSize, u64 arcSize, u16 nameLen(chars), name(UTF-16LE)
//              segm = 每项 28B: u32 flags, u64 start, u64 orgSize, u64 arcSize
// =============================================================================
enum XP3 {

    struct Entry {
        let name: String                 // 原始名（可能含反斜杠）
        let segments: [(start: Int, orgSize: Int, arcSize: Int, compressed: Bool)]
    }

    enum XP3Error: LocalizedError {
        case notXP3, badIndex, inflateFailed
        var errorDescription: String? {
            switch self {
            case .notXP3: return "不是 XP3 归档"
            case .badIndex: return "XP3 索引损坏"
            case .inflateFailed: return "XP3 数据解压失败"
            }
        }
    }

    private static let magic = Data([0x58, 0x50, 0x33, 0x0D, 0x0A, 0x20, 0x0A, 0x1A, 0x8B, 0x67, 0x01])

    // MARK: - 读取索引
    static func entries(at path: String) throws -> [Entry] {
        guard let fh = FileHandle(forReadingAtPath: path) else { throw XP3Error.notXP3 }
        defer { try? fh.close() }

        let head = fh.readData(ofLength: 11)
        guard head == magic else { throw XP3Error.notXP3 }
        guard let indexOfs = readU64(fh, at: 11) else { throw XP3Error.badIndex }

        let fsize = fileSize(path)
        guard indexOfs >= 11, indexOfs < fsize else { throw XP3Error.badIndex }

        fh.seek(toFileOffset: UInt64(indexOfs))
        guard let flagData = readData(fh, 1) else { throw XP3Error.badIndex }
        let method = Int(flagData[0]) & 0x07

        var index = Data()
        if method == 0 {
            guard let isize = readU64(fh, at: nil) else { throw XP3Error.badIndex }
            guard let d = readData(fh, isize) else { throw XP3Error.badIndex }
            index = d
        } else if method == 1 {
            guard let csize = readU64(fh, at: nil), let rsize = readU64(fh, at: nil) else { throw XP3Error.badIndex }
            guard let comp = readData(fh, csize) else { throw XP3Error.badIndex }
            guard let raw = inflate(data: comp, expected: rsize) else { throw XP3Error.inflateFailed }
            index = raw
        } else {
            throw XP3Error.badIndex
        }

        var out: [Entry] = []
        var p = 0
        while p + 12 <= index.count {
            guard index.str(p, 4) == "File" else { break }
            let csize = Int(index.u64(p + 4))
            let bodyStart = p + 12
            let bodyEnd = min(bodyStart + csize, index.count)
            guard bodyStart < bodyEnd else { break }
            let body = index.subdata(in: bodyStart..<bodyEnd)

            var name = ""
            var segs: [(Int, Int, Int, Bool)] = []
            var q = 0
            while q + 12 <= body.count {
                let tag = body.str(q, 4)
                let size = Int(body.u64(q + 4))
                let dStart = q + 12
                let dEnd = min(dStart + size, body.count)
                guard dStart <= dEnd else { break }
                let payload = body.subdata(in: dStart..<dEnd)

                if tag == "info", payload.count >= 22 {
                    let nlen = Int(payload.u16(20))
                    if payload.count >= 22 + nlen * 2 {
                        let nameData = payload.subdata(in: 22..<(22 + nlen * 2))
                        name = String(data: nameData, encoding: .utf16LittleEndian) ?? ""
                    }
                } else if tag == "segm" {
                    var k = 0
                    while k + 28 <= payload.count {
                        let flags = payload.u32(k)
                        let start = Int(payload.u64(k + 4))
                        let org = Int(payload.u64(k + 12))
                        let arc = Int(payload.u64(k + 20))
                        segs.append((start, org, arc, (flags & 0x07) == 1))
                        k += 28
                    }
                } else if tag == "aldr" {
                    break
                }
                q = dEnd
            }
            if !name.isEmpty { out.append(Entry(name: name, segments: segs)) }
            p = bodyEnd
        }
        return out
    }

    // MARK: - 读取单个条目
    static func read(_ entry: Entry, from path: String) throws -> Data {
        guard let fh = FileHandle(forReadingAtPath: path) else { throw XP3Error.notXP3 }
        defer { try? fh.close() }
        var out = Data()
        for seg in entry.segments {
            fh.seek(toFileOffset: UInt64(seg.start))
            guard let blob = readData(fh, seg.arcSize) else { throw XP3Error.badIndex }
            if seg.compressed {
                guard let raw = inflate(data: blob, expected: seg.orgSize) else { throw XP3Error.inflateFailed }
                out.append(raw)
            } else {
                out.append(blob)
            }
        }
        return out
    }

    // MARK: - 从 XP3 里找游戏名（appconfig.tjs 的 ENV_GameName）
    static func gameTitle(at path: String) -> String? {
        guard let list = try? entries(at: path) else { return nil }
        // 优先 appconfig.tjs，其次任意 config 类脚本
        let key = list.first { $0.name.lowercased().hasSuffix("appconfig.tjs") }
            ?? list.first { $0.name.lowercased().contains("config") && $0.name.lowercased().hasSuffix(".tjs") }
        guard let e = key, let data = try? read(e, from: path) else { return nil }

        let text = decodeText(data)
        guard let range = text.range(of: "ENV_GameName") else { return nil }
        let tail = text[range.upperBound...].prefix(300)
        if let q1 = tail.firstIndex(of: "\"") {
            let after = tail[tail.index(after: q1)...]
            if let q2 = after.firstIndex(of: "\"") {
                let title = String(after[..<q2]).trimmingCharacters(in: .whitespacesAndNewlines)
                return title.isEmpty ? nil : title
            }
        }
        return nil
    }

    // MARK: - 工具
    private static func decodeText(_ d: Data) -> String {
        if let s = String(data: d, encoding: .utf16LittleEndian), !s.isEmpty, s.contains("ENV_") { return s }
        if let s = String(data: d, encoding: .utf8), !s.isEmpty { return s }
        return String(data: d, encoding: .utf16LittleEndian) ?? ""
    }

    private static func fileSize(_ path: String) -> Int {
        (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
    }

    private static func readData(_ fh: FileHandle, _ n: Int) -> Data? {
        guard n >= 0, n < 200 * 1024 * 1024 else { return nil }
        let d = fh.readData(ofLength: n)
        return d.count == n ? d : (d.isEmpty ? nil : d)
    }

    private static func readU64(_ fh: FileHandle, at offset: UInt64?) -> Int? {
        if let o = offset { fh.seek(toFileOffset: o) }
        guard let d = readData(fh, 8), d.count == 8 else { return nil }
        return Int(d.u64(0))
    }

    /// zlib 解压（XP3 段数据是 zlib 包装：2 字节头 + deflate + 4 字节 adler）
    static func inflate(data: Data, expected: Int) -> Data? {
        guard data.count > 6 else { return nil }
        let body = data.subdata(in: 2..<(data.count - 4))
        let cap = max(expected, body.count * 6, 4096)
        var out = Data(count: cap)
        let written: Int = out.withUnsafeMutableBytes { dst in
            body.withUnsafeBytes { src in
                compression_decode_buffer(dst.bindMemory(to: UInt8.self).baseAddress!, cap,
                                          src.bindMemory(to: UInt8.self).baseAddress!, body.count,
                                          nil, COMPRESSION_ZLIB)
            }
        }
        guard written > 0 else { return nil }
        return out.prefix(written)
    }
}

// MARK: - 小端读取
extension Data {
    func u16(_ off: Int) -> UInt16 {
        guard off + 2 <= count else { return 0 }
        return withUnsafeBytes { $0.loadUnaligned(fromByteOffset: off, as: UInt16.self) }
    }
    func u32(_ off: Int) -> UInt32 {
        guard off + 4 <= count else { return 0 }
        return withUnsafeBytes { $0.loadUnaligned(fromByteOffset: off, as: UInt32.self) }
    }
    func u64(_ off: Int) -> UInt64 {
        guard off + 8 <= count else { return 0 }
        return withUnsafeBytes { $0.loadUnaligned(fromByteOffset: off, as: UInt64.self) }
    }
    func str(_ off: Int, _ len: Int) -> String {
        guard off + len <= count else { return "" }
        return String(data: subdata(in: off..<(off + len)), encoding: .ascii) ?? ""
    }
}
