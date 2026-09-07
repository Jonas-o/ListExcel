//
//  ExcelTotalView.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

public class ExcelTotalView: UIView {
    public enum Indicator {
        case yellow(String)
        case red(String)
        case green(String)
        case custom(String, UIImage)

        public var title: String {
            switch self {
                case let .yellow(title): return title
                case let .red(title): return title
                case let .green(title): return title
                case let .custom(title, _): return title
            }
        }

        /// 指示圆点填充色（保持不透明，避免回前台 / system tint 后几乎看不见）
        public var color: UIColor {
            switch self {
                case .yellow: return .softYellow
                case .red: return .softRed
                case .green: return .softGreen
                case .custom: return .clear
            }
        }

        /// Indicator 指示色与列表行高亮色在视觉上会略有差异，但可一一对应
        public static let yellowColor = UIColor.softYellow.withAlphaComponent(0.05)
        public static let redColor = UIColor.softRed.withAlphaComponent(0.05)
        public static let greenColor = UIColor.softGreen.withAlphaComponent(0.05)
    }

    public init() {
        super.init(frame: .init(.screenWidth, 44))
        backgroundColor = .white
        setupAccessoryScrollView()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAccessoryScrollView()
    }

    public var padding: UIEdgeInsets = .init(0, 20)

    /// 左侧 action 与右侧合计/指示器之间的中间区域；内容过长时可横向滑动。隐藏的 view 会跳过。
    public var leadingAccessoryViews: [UIView] = [] {
        didSet {
            for view in oldValue where !leadingAccessoryViews.contains(where: { $0 === view }) {
                if view.superview === accessoryScrollView {
                    view.removeFromSuperview()
                }
            }
            for view in leadingAccessoryViews {
                accessoryScrollView.addSubview(view)
            }
            setNeedsLayout()
        }
    }

    private var actionButton: ActionButton?
    private var contentButtons: [NormalButton] = []
    private var indicatorItems: [Indicator] = []

    private lazy var totalLabel: UILabel = {
        let label = UILabel()
        label.font = .default
        label.textColor = .textBlack
        addSubview(label)
        return label
    }()

    private lazy var accessoryScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.isDirectionalLockEnabled = true
        scrollView.clipsToBounds = true
        return scrollView
    }()

    /// 中间区域左缘阴影：有向左可滑内容时显示（略淡于表格锁定列阴影）
    private let leftAccessoryShadowView: UIImageView = {
        let image = UIImage.lex("lex_side_blur").lex_image(with: .down)
        let view = UIImageView(image: image?.resizableImage(withCapInsets: .init(10, 0), resizingMode: .stretch))
        view.alpha = 0.6
        view.isUserInteractionEnabled = false
        view.isHidden = true
        return view
    }()

    /// 中间区域右缘阴影：有向右可滑内容时显示
    private let rightAccessoryShadowView: UIImageView = {
        let view = UIImageView(image: UIImage.lex("lex_side_blur").resizableImage(withCapInsets: .init(10, 0), resizingMode: .stretch))
        view.alpha = 0.6
        view.isUserInteractionEnabled = false
        view.isHidden = true
        return view
    }()

    @discardableResult
    public func resetActionButton(_ title: String, action: @escaping (UIButton) -> Void) -> UIButton {
        actionButton?.button.removeFromSuperview()
        let button = genButton(title: title)
        actionButton = ActionButton(button: button, action: { action($0) })
        setNeedsLayout()
        return button
    }

    public func resetIndicators(_ items: [Indicator] = []) {
        indicatorItems = items
        rebuildIndicatorButtons()
    }

    public func resetTotalText(_ text: String?) {
        totalLabel.text = text
        totalLabel.isHidden = text == nil
        if text != nil {
            totalLabel.sizeToFit()
        }
        setNeedsLayout()
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // 回前台 / 外观变化后重绘纯色圆点，避免 system button tint 把指示色洗掉
        if !indicatorItems.isEmpty {
            rebuildIndicatorButtons()
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        lex_refreshBorderLayers()

        let centerY = height / 2

        // 右侧：totalLabel + contentButtons 从右往左固定
        var rightBlockLeft = width - padding.right
        if !totalLabel.isHidden {
            totalLabel.sizeToFit()
            totalLabel.right = rightBlockLeft
            totalLabel.centerY = centerY
            rightBlockLeft = totalLabel.x
        }
        for button in contentButtons.reversed() {
            button.sizeToFit()
            button.isHidden = false
            if rightBlockLeft < width - padding.right {
                rightBlockLeft -= 16
            }
            button.right = rightBlockLeft
            button.centerY = centerY
            rightBlockLeft = button.x
        }

        // 左侧：actionButton 固定
        var leftBlockRight = padding.left
        if let button = actionButton?.button {
            button.sizeToFit()
            button.x = padding.left
            button.centerY = centerY
            leftBlockRight = button.right
        }

        // 中间：leadingAccessoryViews 落在左右之间，可横滑
        let gapLeading: CGFloat = actionButton != nil ? 12 : 0
        let gapTrailing: CGFloat = 8
        let scrollX = leftBlockRight + gapLeading
        let scrollWidth = max(0, rightBlockLeft - gapTrailing - scrollX)
        accessoryScrollView.frame = .init(scrollX, 0, scrollWidth, height)
        accessoryScrollView.isHidden = scrollWidth <= 0

        var cursor: CGFloat = 0
        let visibleAccessories = leadingAccessoryViews.filter { !$0.isHidden }
        for (index, view) in visibleAccessories.enumerated() {
            view.sizeToFit()
            view.x = cursor
            view.centerY = accessoryScrollView.bounds.midY
            cursor = view.right
            if index < visibleAccessories.count - 1 {
                cursor += 8
            }
        }
        accessoryScrollView.contentSize = .init(max(cursor, scrollWidth), height)

        let shadowWidth: CGFloat = 10
        leftAccessoryShadowView.frame = .init(scrollX, 0, shadowWidth, height)
        rightAccessoryShadowView.frame = .init(scrollX + scrollWidth - shadowWidth, 0, shadowWidth, height)
        reloadAccessoryEdgeShadows()
    }

    private func setupAccessoryScrollView() {
        accessoryScrollView.delegate = self
        addSubview(accessoryScrollView)
        addSubview(leftAccessoryShadowView)
        addSubview(rightAccessoryShadowView)
    }

    private func reloadAccessoryEdgeShadows() {
        let scroll = accessoryScrollView
        guard !scroll.isHidden, scroll.bounds.width > 0 else {
            leftAccessoryShadowView.isHidden = true
            rightAccessoryShadowView.isHidden = true
            return
        }
        let notFull = scroll.contentSize.width <= scroll.bounds.width + 0.5
        let atLeading = scroll.contentOffset.x <= 0.5
        let atTrailing = scroll.contentSize.width <= scroll.contentOffset.x + scroll.bounds.width + 0.5
        leftAccessoryShadowView.isHidden = notFull || atLeading
        rightAccessoryShadowView.isHidden = notFull || atTrailing
    }

    private func rebuildIndicatorButtons() {
        contentButtons.forEach { $0.removeFromSuperview() }
        contentButtons.removeAll(keepingCapacity: true)
        for item in indicatorItems {
            let image = indicatorImage(for: item)
            // alwaysOriginal：避免 template tint 把指示圆点洗掉
            let button = NormalButton(title: item.title, image: image, style: .light, usesOriginalImage: true)
            button.sizeToFit()
            button.isUserInteractionEnabled = false
            contentButtons.append(button)
            addSubview(button)
        }
        setNeedsLayout()
    }

    private func indicatorImage(for item: Indicator) -> UIImage {
        if case let .custom(_, img) = item {
            return (img.lex_imageResized(inLimitedSize: .square(14)) ?? img)
                .withRenderingMode(.alwaysOriginal)
        }
        return UIImage.lex_image(with: item.color, size: .square(14), cornerRadius: 7)
            .withRenderingMode(.alwaysOriginal)
    }
}

extension ExcelTotalView: UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === accessoryScrollView else { return }
        reloadAccessoryEdgeShadows()
    }
}

extension ExcelTotalView {
    fileprivate func genButton(title: String) -> NormalButton {
        let button = NormalButton(title: title)
        button.setTitleColor(.softGreen, for: .normal)
        button.addTarget(self, action: #selector(buttonAction(_:)), for: .touchUpInside)
        addSubview(button)
        return button
    }

    @objc private func buttonAction(_ sender: NormalButton) {
        actionButton?.action(sender)
    }
}
