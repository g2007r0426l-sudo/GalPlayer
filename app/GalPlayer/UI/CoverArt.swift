import UIKit

// =============================================================================
// 封面图池 —— 内置 8 张二次元插画，按游戏名稳定分配（同一游戏每次同一张）
// =============================================================================
enum CoverArt {
    static let count = 8

    /// 稳定哈希（Swift 的 hashValue 每进程随机，不能用）
    private static func stableHash(_ s: String) -> Int {
        var h = 5381
        for u in s.unicodeScalars {
            h = ((h << 5) &+ h) &+ Int(u.value)
        }
        return abs(h)
    }

    /// 启动时把封面临时加载进内存（按 Bundle 路径直取，最稳）
    private static let cache: [UIImage] = {
        var imgs: [UIImage] = []
        for i in 1...count {
            if let p = Bundle.main.path(forResource: "cover\(i)", ofType: "jpg"),
               let img = UIImage(contentsOfFile: p) {
                imgs.append(img)
            } else if let p2 = Bundle.main.path(forResource: "cover\(i)", ofType: "jpg", inDirectory: "covers"),
                      let img2 = UIImage(contentsOfFile: p2) {
                imgs.append(img2)
            }
        }
        NSLog("[GalPlayer] 封面池加载: \(imgs.count)/\(count) 张")
        return imgs
    }()

    static var isAvailable: Bool { !cache.isEmpty }

    static func index(for name: String) -> Int {
        stableHash(name) % max(cache.count, 1)
    }

    static func image(for name: String) -> UIImage? {
        guard !cache.isEmpty else { return nil }
        return cache[stableHash(name) % cache.count]
    }
}

// =============================================================================
// 封面视图：有插画用插画（等比填充 + 底部渐变保障文字可读），无图用渐变兜底
// =============================================================================
final class PlaceholderCoverView: UIView {

    var title: String = "" { didSet { setNeedsDisplay() } }
    var coverImage: UIImage? { didSet { setNeedsDisplay() } }
    var isDimmed: Bool = false { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.cardBg
        isOpaque = false
        clipsToBounds = true
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("纯代码 UI，禁用 storyboard") }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        if let img = coverImage, bounds.width > 1, bounds.height > 1 {
            // 等比填充裁切
            let scale = max(bounds.width / img.size.width, bounds.height / img.size.height)
            let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
            img.draw(in: CGRect(x: (bounds.width - size.width) / 2,
                                y: (bounds.height - size.height) / 2,
                                width: size.width, height: size.height))
            // 底部暗渐变（文字可读）
            let colors = [UIColor.black.withAlphaComponent(0).cgColor,
                          UIColor.black.withAlphaComponent(0.62).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors, locations: [0.42, 1]) {
                ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: 0),
                                       end: CGPoint(x: 0, y: bounds.height), options: [])
            }
            // 顶部轻微暗角，让角标更清晰
            let topColors = [UIColor.black.withAlphaComponent(0.28).cgColor,
                             UIColor.clear.cgColor] as CFArray
            if let g2 = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                   colors: topColors, locations: [0, 1]) {
                ctx.drawLinearGradient(g2, start: CGPoint(x: 0, y: 0),
                                       end: CGPoint(x: 0, y: bounds.height * 0.35), options: [])
            }
        } else {
            // 兜底渐变 + 软萌小脸
            let colors = [Theme.coverTop.cgColor, Theme.coverBottom.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors, locations: [0, 1]) {
                ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0),
                                       end: CGPoint(x: bounds.width, y: bounds.height), options: [])
            }
            drawKawaiiFace(ctx)
        }

        if isDimmed {
            UIColor(white: 0.06, alpha: 0.55).setFill()
            ctx.fill(bounds)
        }
    }

    private func drawKawaiiFace(_ ctx: CGContext) {
        let faceY = bounds.height * 0.44
        let eyeDX = bounds.width * 0.17
        let eyeR = max(3, bounds.width * 0.045)
        let ink = UIColor(white: 0.18, alpha: 0.85)

        for sign: CGFloat in [-1, 1] {
            let ex = bounds.midX + sign * eyeDX
            let eyeRect = CGRect(x: ex - eyeR, y: faceY - eyeR * 1.35, width: eyeR * 2, height: eyeR * 2.7)
            let eye = UIBezierPath(roundedRect: eyeRect, cornerRadius: eyeR)
            ink.setFill(); eye.fill()
            let hl = UIBezierPath(arcCenter: CGPoint(x: ex - eyeR * 0.32, y: faceY - eyeR * 0.8),
                                  radius: eyeR * 0.3, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            UIColor.white.withAlphaComponent(0.9).setFill(); hl.fill()
            let blush = UIBezierPath(arcCenter: CGPoint(x: bounds.midX + sign * bounds.width * 0.26,
                                                        y: faceY + eyeR * 1.5),
                                     radius: bounds.width * 0.055, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            UIColor(red: 1, green: 0.55, blue: 0.65, alpha: 0.45).setFill(); blush.fill()
        }
        let mouth = UIBezierPath(arcCenter: CGPoint(x: bounds.midX, y: faceY + eyeR * 1.05),
                                 radius: bounds.width * 0.05,
                                 startAngle: .pi * 0.15, endAngle: .pi * 0.85, clockwise: true)
        ink.setStroke()
        mouth.lineWidth = max(1.5, bounds.width * 0.02)
        mouth.lineCapStyle = .round
        mouth.stroke()
        _ = ctx
    }
}

// =============================================================================
// 角标（时间 / 引擎）
// =============================================================================
final class ChipLabel: UILabel {
    init() {
        super.init(frame: .zero)
        font = Theme.roundedFont(size: 10, weight: .heavy)
        textColor = .white
        textAlignment = .center
        layer.cornerRadius = 9
        clipsToBounds = true
        translatesAutoresizingMaskIntoConstraints = false
    }
    required init?(coder: NSCoder) { fatalError("纯代码 UI") }

    func set(text value: String, color: UIColor) {
        self.text = "  \(value)  "
        backgroundColor = color
        isHidden = false
    }
}
