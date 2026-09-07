//
//  ExcelCell.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension Excel.Cell {
    public enum ClassType: CaseIterable, Hashable {
        case text
        case cornerText
        case headerText
        case iconText
        case image
        case select
        case textField
        case cornerTextField

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

        public override func prepareForReuse() {
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

        /// 由 Excel 在 `handle` 前注入
        public var appearance = Appearance(configuration: .init(), row: .cell(0))

        public var padding: UIEdgeInsets { appearance.padding }
        public var margin: CGFloat { appearance.margin }

        public var showLineLayer = false {
            didSet {
                // 只画右边线，避免相邻 cell 左右各一条叠成「双竖线」
                contentView.lex_borderPosition = showLineLayer ? [.right] : []
            }
        }

        private var highlightedView: UIView?
        public var highlightedColor: UIColor = Configuration().highlightColor {
            didSet {
                highlightedView?.backgroundColor = highlightedColor
            }
        }

        /// 子类实现方便初始化（结构重置；颜色/字体在 `applyAppearance`）
        @objc open func initSubviews() {
            backgroundColor = .clear
            contentView.backgroundColor = .clear
            showLineLayer = false
            highlightedView?.alpha = 0
        }

        /// 应用当前 `appearance`（Excel 注入后调用）
        @objc open func applyAppearance() {
            highlightedColor = appearance.highlightColor
            showLineLayer = appearance.showsColumnLines
        }

        /// 将 `Content` 绑定到 Cell（List / 自定义引擎在 `handle` 中调用）
        public struct ContentBindContext {
            public var textAlignment: NSTextAlignment?
            public var isSelected: Bool

            public init(textAlignment: NSTextAlignment? = nil, isSelected: Bool = false) {
                self.textAlignment = textAlignment
                self.isSelected = isSelected
            }
        }

        open func bindContent(_ content: Content?, context: ContentBindContext = .init()) {}

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
