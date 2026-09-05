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

        public var color: UIColor {
            switch self {
            case .yellow: return .softYellow
            case .red: return UIColor.softRed.withAlphaComponent(0.3)
            case .green: return UIColor.lightGreen.withAlphaComponent(0.3)
            case .custom: return .clear
            }
        }

        /// Indicator 指示色与列表行高亮色在视觉上会略有差异，但可一一对应
        public static let yellowColor = UIColor.softYellow.withAlphaComponent(0.05)
        public static let redColor = UIColor.softRed.withAlphaComponent(0.05)
        public static let greenColor = UIColor.lightGreen.withAlphaComponent(0.05)
    }

    public init() {
        super.init(frame: .init(.screenWidth, 44))
        backgroundColor = .white
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public var padding: UIEdgeInsets = .init(0, 20)

    private var actionButton: ActionButton?
    private var contentButtons: [NormalButton] = []

    private lazy var totalLabel: UILabel = {
        let label = UILabel()
        label.font = .default
        label.textColor = .textBlack
        addSubview(label)
        return label
    }()

    @discardableResult
    public func resetActionButton(_ title: String, action: @escaping (UIButton) -> Void) -> UIButton {
        let button = genButton(title: title)
        actionButton = ActionButton(button: button, action: { action($0) })
        setNeedsLayout()
        return button
    }

    public func resetIndicators(_ items: [Indicator] = []) {
        contentButtons.forEach { $0.removeFromSuperview() }
        contentButtons.removeAll(keepingCapacity: true)
        for item in items {
            var image = UIImage.lex_image(with: item.color, size: .square(14), cornerRadius: 7)
            if case let .custom(_, img) = item {
                image = img.lex_imageResized(inLimitedSize: .square(14)) ?? UIImage()
            }
            let button = NormalButton(title: item.title, image: image, style: .light)
            button.sizeToFit()
            button.isUserInteractionEnabled = false
            contentButtons.append(button)
            addSubview(button)
        }
        setNeedsLayout()
    }

    public func resetTotalText(_ text: String) {
        totalLabel.text = text
        totalLabel.sizeToFit()
        setNeedsLayout()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let centerY = height / 2

        actionButton?.button.sizeToFit()
        actionButton?.button.centerY = centerY
        actionButton?.button.x = padding.left

        totalLabel.right = width - padding.right
        totalLabel.centerY = centerY
        var startRight = totalLabel.x - 20
        contentButtons.reversed().forEach { button in
            button.right = startRight
            button.centerY = centerY
            startRight = button.x - 20
        }
    }
}

extension ExcelTotalView {
    fileprivate func genButton(title: String) -> NormalButton {
        let button = NormalButton(title: title)
        button.setTitleColor(.lightGreen, for: .normal)
        button.addTarget(self, action: #selector(buttonAction(_:)), for: .touchUpInside)
        addSubview(button)
        return button
    }

    @objc private func buttonAction(_ sender: NormalButton) {
        actionButton?.action(sender)
    }
}
