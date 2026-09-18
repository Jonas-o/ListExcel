//
//  ExcelCell.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension Excel.Cell {
    /// 内置 Cell 种类；`Content.targetClassType` 与 init 的 `cellClasses` 覆盖均按此键。
    public enum ClassType: CaseIterable, Hashable {
        case text
        case cornerText
        case headerText
        case iconText
        case image
        case select
        case textField
        case cornerTextField

        /// 未自定义映射时使用的默认 Cell 类型。
        public var defaultCellClass: Excel.Cell.Type {
            switch self {
            case .text: return Excel.TextCell.self
            case .cornerText: return Excel.CornerTextCell.self
            case .headerText: return Excel.HeaderTextCell.self
            case .iconText: return Excel.IconTextCell.self
            case .image: return Excel.ImageCell.self
            case .select: return Excel.SelectCell.self
            case .textField: return Excel.DefaultTextFieldCell.self
            case .cornerTextField: return Excel.DefaultCornerTextFieldCell.self
            }
        }
    }

    class Register {
        let type: ClassType
        let `class`: Excel.Cell.Type
        let identifier: String

        init(_ type: ClassType, cellClass: Excel.Cell.Type? = nil, custom: String? = nil) {
            self.type = type
            `class` = cellClass ?? type.defaultCellClass
            let value = "\(custom ?? "Class")_\(String(reflecting: `class`))"
            identifier = value.replacingOccurrences(of: ".", with: "_").uppercased()
        }
    }
}

extension Excel {
    /// 矩阵格基类（`UICollectionViewCell`）。子类 override `initSubviews` / `bindContent` / `applyAppearance`。
    open class Cell: UICollectionViewCell {
        public override init(frame: CGRect) {
            super.init(frame: frame)
            initSubviews()
        }

        public required init?(coder: NSCoder) {
            super.init(coder: coder)
        }

        public override func awakeFromNib() {
            super.awakeFromNib()
            initSubviews()
        }

        open override func prepareForReuse() {
            super.prepareForReuse()
            initSubviews()
        }

        open override func layoutSubviews() {
            super.layoutSubviews()
            highlightedView?.frame = contentView.bounds
            if showLineLayer {
                contentView.lex_refreshBorderLayers()
            }
        }

        /// 由 Excel 在 `handle` 前注入的外观快照。
        public var appearance = Appearance(configuration: .init(), row: .cell(0))

        /// 等价于 `appearance.padding`。
        public var padding: UIEdgeInsets { appearance.padding }
        /// 等价于 `appearance.iconTitleSpacing`。
        public var iconTitleSpacing: CGFloat { appearance.iconTitleSpacing }

        /// 是否绘制右边列竖线（表头常用）。
        public var showLineLayer = false {
            didSet {
                // 只画右边线，避免相邻 cell 左右各一条叠成「双竖线」
                contentView.lex_borderPosition = showLineLayer ? [.right] : []
            }
        }

        private var highlightedView: UIView?
        /// 点按高亮色。
        public var highlightedColor: UIColor = Configuration().highlightColor {
            didSet {
                highlightedView?.backgroundColor = highlightedColor
            }
        }

        /// 子类初始化子视图（结构重置；颜色 / 字体在 `applyAppearance`）。
        @objc open func initSubviews() {
            backgroundColor = .clear
            contentView.backgroundColor = .clear
            showLineLayer = false
            highlightedView?.alpha = 0
        }

        /// 应用当前 `appearance`（Excel 注入后调用）。
        @objc open func applyAppearance() {
            highlightedColor = appearance.highlightColor
            showLineLayer = appearance.showsColumnLines
        }

        /// 绑定 ``Excel/Content`` 时的附加上下文。
        public struct ContentBindContext {
            public var textAlignment: NSTextAlignment?
            public var isSelected: Bool

            public init(textAlignment: NSTextAlignment? = nil, isSelected: Bool = false) {
                self.textAlignment = textAlignment
                self.isSelected = isSelected
            }
        }

        /// 将 `Content` 绑定到界面；子类 override。引擎在 `handle` 前调用。
        open func bindContent(_ content: Content?, context: ContentBindContext = .init()) {}

        /// 显示或隐藏点按高亮层。
        public func setHighlighted(_ highlighted: Bool, animated: Bool) {
            if highlightedView == nil {
                let view = UIView()
                view.alpha = 0
                view.backgroundColor = highlightedColor
                view.frame = contentView.bounds
                contentView.insertSubview(view, at: 0)
                highlightedView = view
            }
            if animated {
                UIView.animate(withDuration: 0.2) {
                    self.highlightedView?.alpha = highlighted ? 1 : 0
                }
            } else {
                highlightedView?.alpha = highlighted ? 1 : 0
            }
        }
    }
}
