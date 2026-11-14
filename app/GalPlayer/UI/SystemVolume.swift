import UIKit
import MediaPlayer

// =============================================================================
// 系统媒体音量控制（MPVolumeView 隐藏滑杆方案，iOS 14~17 可用）
// =============================================================================

final class SystemVolume {
    static let shared = SystemVolume()

    private let volumeView = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))

    private init() {}

    func setVolume(_ value: Float) {
        attachIfNeeded()
        let slider = volumeView.subviews.compactMap { $0 as? UISlider }.first
        slider?.setValue(max(0, min(1, value)), animated: false)
    }

    private func attachIfNeeded() {
        guard volumeView.window == nil else { return }
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else {
            return
        }
        volumeView.alpha = 0.001
        volumeView.isUserInteractionEnabled = false
        window.addSubview(volumeView)
    }
}
