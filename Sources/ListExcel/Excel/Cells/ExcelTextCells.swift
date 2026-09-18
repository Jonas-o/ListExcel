//
//  ExcelTextCells.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension Excel {
    /// 角标 Label 专用布局（不接入 `cellPadding` / `iconTitleSpacing`，刻意贴边以多留正文空间）。
    enum CornerLabelMetrics {
        static let font = UIFont.systemFont(ofSize: 12)
        static let horizontalInset: CGFloat = 5
        static let dualGap: CGFloat = 5
        /// `CornerTextFieldCell`：相对顶边下移，避免被 TextField border 盖住。
        static let textFieldVerticalOffset: CGFloat = 1
    }
}

extension Excel {
    /// 文本 / 数字格（`Content.text` / `.decimal` / `.decimals`）。
    open class TextCell: Cell {
        public let textLabel = DecimalLabel()

        open override func initSubviews() {
            super.initSubviews()
            textLabel.resetAppearance()
            textLabel.setDecimal([])
            textLabel.warnStyle = .negative
            contentView.addSubview(textLabel)
        }

        open override func applyAppearance() {
            super.applyAppearance()
            textLabel.textColor = appearance.textColor
            textLabel.warnTextColor = appearance.warnTextColor
            textLabel.font = appearance.font
        }

        open override func bindContent(_ content: Content?, context: ContentBindContext = .init()) {
            switch content {
            case let .decimal(decimal, style, hiddenZero):
                textLabel.setDecimal([.init(decimal, style: style, hiddenZero: hiddenZero)], locale: appearance.locale)
            case let .decimals(decimals):
                textLabel.setDecimal(decimals, locale: appearance.locale)
                textLabel.numberOfLines = max(decimals.count, 1)
            case let .text(text):
                textLabel.text = text
            default:
                return
            }
            if let alignment = context.textAlignment {
                textLabel.textAlignment = alignment
            }
        }

        open override func layoutSubviews() {
            super.layoutSubviews()
            textLabel.frame = contentView.bounds.inset(by: padding)
        }
    }

    /// 主文案 / 数字 + 左右角标（`Content.cornerText` / `.cornerDecimal`）。
    public class CornerTextCell: Cell {
        public let textLabel = DecimalLabel()
        public let leadingCornerLabel = DecimalLabel()
        public let trailingCornerLabel = DecimalLabel()

        public override func initSubviews() {
            super.initSubviews()
            textLabel.resetAppearance()
            textLabel.setDecimal([])
            textLabel.warnStyle = .negative
            contentView.addSubview(textLabel)

            [leadingCornerLabel, trailingCornerLabel].forEach {
                $0.resetAppearance()
                $0.setDecimal([])
                $0.warnStyle = .all
                $0.font = CornerLabelMetrics.font
                $0.isHidden = true
                contentView.addSubview($0)
            }
            trailingCornerLabel.textAlignment = .right
        }

        public override func applyAppearance() {
            super.applyAppearance()
            textLabel.textColor = appearance.textColor
            textLabel.warnTextColor = appearance.warnTextColor
            textLabel.font = appearance.font
            leadingCornerLabel.textColor = appearance.accentColor
            leadingCornerLabel.warnTextColor = appearance.warnTextColor
            trailingCornerLabel.textColor = appearance.accentColor
            trailingCornerLabel.warnTextColor = appearance.warnTextColor
        }

        public override func bindContent(_ content: Content?, context: ContentBindContext = .init()) {
            leadingCornerLabel.isHidden = true
            trailingCornerLabel.isHidden = true
            switch content {
            case let .cornerText(text, leadingCorner, trailingCorner):
                textLabel.text = text
                applyCorners(leading: leadingCorner, trailing: trailingCorner)
            case let .cornerDecimal(decimal, style, leadingCorner, trailingCorner):
                textLabel.setDecimal([.init(decimal, style: style)], locale: appearance.locale)
                applyCorners(leading: leadingCorner, trailing: trailingCorner)
            default:
                return
            }
            if let alignment = context.textAlignment {
                textLabel.textAlignment = alignment
            }
        }

        private func applyCorners(leading: Content.Tuple?, trailing: Content.Tuple?) {
            if let leading {
                leadingCornerLabel.isHidden = false
                leadingCornerLabel.setDecimal([leading], locale: appearance.locale)
            }
            if let trailing {
                trailingCornerLabel.isHidden = false
                trailingCornerLabel.setDecimal([trailing], locale: appearance.locale)
            }
        }

        public override func layoutSubviews() {
            super.layoutSubviews()
            let inset = CornerLabelMetrics.horizontalInset
            let gap = CornerLabelMetrics.dualGap
            var cornerLabelWidth = contentView.width - inset * 2
            if !leadingCornerLabel.isHidden, !trailingCornerLabel.isHidden {
                cornerLabelWidth = (cornerLabelWidth - gap) / 2
            }
            if !leadingCornerLabel.isHidden {
                leadingCornerLabel.sizeToFit()
                leadingCornerLabel.width = cornerLabelWidth
                leadingCornerLabel.origin = .init(inset, 0)
            }
            if !trailingCornerLabel.isHidden {
                trailingCornerLabel.sizeToFit()
                trailingCornerLabel.width = cornerLabelWidth
                trailingCornerLabel.y = 0
                trailingCornerLabel.right = contentView.width - inset
            }

            textLabel.frame = contentView.bounds.inset(by: padding)
        }
    }

    /// 表头文本格；可展示排序箭头（`Content.text` 且列可排序时）。
    public class HeaderTextCell: Cell {
        public let textLabel = UILabel()
        private let sortImageView = UIImageView(image: UIImage.lex("lex_arrow_desc"))

        /// 当前排序方向；非 `.none` 时显示排序图。
        public var orderType: Excel.OrderType = .none {
            didSet {
                let image: UIImage?
                switch orderType {
                case .none:
                    image = nil
                case .ascending:
                    image = UIImage.lex("lex_arrow_asc")
                case .descending:
                    image = UIImage.lex("lex_arrow_desc")
                }
                sortImageView.image = image
                sortImageView.isHidden = orderType == .none
                setNeedsLayout()
            }
        }

        public override func initSubviews() {
            super.initSubviews()
            textLabel.resetAppearance()
            contentView.addSubview(textLabel)

            sortImageView.resetAppearance()
            contentView.addSubview(sortImageView)

            orderType = .none
        }

        public override func applyAppearance() {
            super.applyAppearance()
            textLabel.textColor = appearance.textColor
            textLabel.font = appearance.font
        }

        public override func bindContent(_ content: Content?, context: ContentBindContext = .init()) {
            guard case let .text(text) = content else { return }
            textLabel.text = text
            if let alignment = context.textAlignment {
                textLabel.textAlignment = alignment
            }
        }

        public override func layoutSubviews() {
            super.layoutSubviews()
            var paddingRight = padding.right
            if !sortImageView.isHidden {
                sortImageView.sizeToFit()
                sortImageView.right = contentView.width - paddingRight
                sortImageView.centerY = contentView.height / 2
                // 排序图与 title 同时存在时才计入间距
                let hasTitle = !(textLabel.text ?? "").isEmpty
                paddingRight += sortImageView.width + (hasTitle ? iconTitleSpacing : 0)
            }
            textLabel.frame = contentView.bounds.inset(by: padding.withRight(paddingRight))
        }
    }
}
