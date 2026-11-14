import UIKit

// =============================================================================
// 侧边栏导航行：图标 + 文字 严格对齐（修复"图标与文字不协调"）
//   图标固定 22pt 容器、垂直居中；文字 16pt 霞鹜文楷；间距 12；行高 52
// =============================================================================
final class SidebarRow: UIControl {

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let pill = UIView()

    var isChosen: Bool = false {
        didSet { updateStyle(animated: true) }
    }

    init(icon: String, title: String) {
        super.init(frame: .zero)

        // 选中态胶囊（粉色渐变）
        pill.isUserInteractionEnabled = false
        pill.layer.cornerRadius = 16
        pill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pill)

        let gradient = CAGradientLayer()
        gradient.colors = [Theme.pillSelectedTop.cgColor, Theme.pillSelectedBottom.cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.cornerRadius = 16
        gradient.name = "pillGradient"
        pill.layer.addSublayer(gradient)

        let cfg = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        iconView.image = UIImage(systemName: icon, withConfiguration: cfg)?
            .withRenderingMode(.alwaysTemplate)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        titleLabel.text = title
        titleLabel.font = Theme.uiFont(size: 16)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            self.heightAnchor.constraint(equalToConstant: 52),

            pill.leadingAnchor.constraint(equalTo: leadingAnchor),
            pill.trailingAnchor.constraint(equalTo: trailingAnchor),
            pill.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            pill.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),

            // 图标：固定 22 宽，垂直居中，左边距 16
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            // 文字：紧跟图标 12pt，垂直居中（保证基线视觉居中）
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        updateStyle(animated: false)
    }

    required init?(coder: NSCoder) { fatalError("纯代码 UI") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let g = pill.layer.sublayers?.first(where: { $0.name == "pillGradient" }) as? CAGradientLayer {
            g.frame = pill.bounds
        }
    }

    private func updateStyle(animated: Bool) {
        let apply = {
            self.pill.alpha = self.isChosen ? 1 : 0
            self.iconView.tintColor = self.isChosen ? .white : Theme.textSub
            self.titleLabel.textColor = self.isChosen ? .white : Theme.text
        }
        if animated {
            UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut], animations: apply)
        } else {
            apply()
        }
    }

    // 按下轻微缩放
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.14, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.97, y: 0.97)
                    : .identity
            }
        }
    }
}
