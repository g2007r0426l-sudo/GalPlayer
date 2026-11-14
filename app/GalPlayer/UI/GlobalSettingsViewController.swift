import UIKit
import MediaPlayer

// =============================================================================
// 全局设置页: 屏幕适配 / 快进文字速度 / 音量 / 关于
// =============================================================================

final class GlobalSettingsViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let stretchSegment = UISegmentedControl(items: ["原始比例", "拉伸全屏"])
    private let speedSlider = UISlider()
    private let speedLabel = UILabel()
    private let volumeSlider = UISlider()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "设置"
        view.backgroundColor = Theme.background
        buildUI()
        loadValues()
    }

    // -------------------------------------------------------------------------
    private func buildUI() {
        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scrollView)

        var y: CGFloat = 24
        let pad: CGFloat = 24

        y += addHeader("🎀 屏幕适配", to: y)
        stretchSegment.selectedSegmentTintColor = Theme.accent
        stretchSegment.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        stretchSegment.setTitleTextAttributes([.foregroundColor: Theme.textSub], for: .normal)
        stretchSegment.addTarget(self, action: #selector(stretchChanged), for: .valueChanged)
        y += addControl(stretchSegment, top: y, height: 40, note: "原始比例: 引擎画面等比缩放（居中黑边）\n拉伸全屏: 铺满整个屏幕（画面变形）", pad: pad)

        y += addHeader("🍬 快进 / 文字速度", to: y)
        speedSlider.minimumValue = 0.25
        speedSlider.maximumValue = 4.0
        speedSlider.tintColor = Theme.accent
        speedSlider.addTarget(self, action: #selector(speedChanged), for: .valueChanged)
        speedLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        speedLabel.textColor = Theme.textSub
        speedLabel.textAlignment = .right
        y += addControl(speedSlider, top: y, height: 36, note: "作用于\"长按快进\"的节奏；游戏内逐字速度请用引擎自带菜单调整", pad: pad, trailing: speedLabel)

        y += addHeader("🔊 音量", to: y)
        volumeSlider.minimumValue = 0
        volumeSlider.maximumValue = 1.0
        volumeSlider.tintColor = Theme.accent
        volumeSlider.addTarget(self, action: #selector(volumeChanged), for: .valueChanged)
        y += addControl(volumeSlider, top: y, height: 36, note: "调节系统媒体音量（引擎内部音量用游戏菜单调节）", pad: pad)

        // 关于 / 协议声明（GPL 署名必须保留）
        let about = UILabel()
        about.numberOfLines = 0
        about.font = .systemFont(ofSize: 12)
        about.textColor = Theme.textSub
        about.text = """
        🌸 GalPlayer 0.1.0 — 本地视觉小说播放器（无联网 / 无账号 / 无广告）

        本应用基于以下开源引擎构建，感谢上游作者：
        · Kirikiri2 / Kirikiroid2 (zzz-ooo) — GPL-2.0
        · ONScripter (ogapee) / ONScripter-JH — GPL-2.0
        · Simple DirectMedia Layer (SDL2) — zlib
        · DroidSansFallback 字体 — Apache-2.0

        引擎署名与协议声明保留于「关于」页与随包文档 THIRD_PARTY.md，
        源码依据 GPL-2.0 要求随构建脚本一同分发。
        """
        about.frame = CGRect(x: pad, y: y + 24, width: view.bounds.width - pad * 2, height: 1)
        about.sizeToFit()
        scrollView.addSubview(about)
        scrollView.contentSize = CGSize(width: view.bounds.width, height: about.frame.maxY + 40)
    }

    private func addHeader(_ text: String, to y: CGFloat) -> CGFloat {
        let label = UILabel()
        label.text = text
        label.font = .boldSystemFont(ofSize: 15)
        label.textColor = Theme.text
        label.frame = CGRect(x: 24, y: y, width: view.bounds.width - 48, height: 22)
        scrollView.addSubview(label)
        return 34
    }

    @discardableResult
    private func addControl(_ control: UIView, top: CGFloat, height: CGFloat,
                            note: String, pad: CGFloat, trailing: UILabel? = nil) -> CGFloat {
        control.frame = CGRect(x: pad, y: top, width: view.bounds.width - pad * 2, height: height)
        scrollView.addSubview(control)
        var bottom = top + height + 6
        if let noteLabel = makeNote(note, top: bottom, width: view.bounds.width - pad * 2) {
            scrollView.addSubview(noteLabel)
            bottom = noteLabel.frame.maxY
        }
        if let trailing = trailing {
            trailing.frame = CGRect(x: view.bounds.width - pad - 60, y: top - 20, width: 60, height: 18)
        }
        return bottom - top + 16
    }

    private func makeNote(_ text: String, top: CGFloat, width: CGFloat) -> UILabel? {
        guard !text.isEmpty else { return nil }
        let l = UILabel()
        l.numberOfLines = 0
        l.font = .systemFont(ofSize: 12)
        l.textColor = Theme.textSub
        l.text = text
        l.frame = CGRect(x: 24, y: top, width: width, height: 1)
        l.sizeToFit()
        return l
    }

    private func loadValues() {
        let s = AppSettings.shared
        stretchSegment.selectedSegmentIndex = s.stretchFullscreen ? 1 : 0
        speedSlider.value = s.textSpeed
        speedLabel.text = String(format: "%.2fx", s.textSpeed)
        volumeSlider.value = s.volume
    }

    // -------------------------------------------------------------------------
    @objc private func stretchChanged() {
        AppSettings.shared.stretchFullscreen = stretchSegment.selectedSegmentIndex == 1
    }

    @objc private func speedChanged() {
        let v = speedSlider.value
        AppSettings.shared.textSpeed = v
        speedLabel.text = String(format: "%.2fx", v)
    }

    @objc private func volumeChanged() {
        let v = volumeSlider.value
        AppSettings.shared.volume = v
        SystemVolume.shared.setVolume(v)
    }
}
