//
//  ExcelMediaCells.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension Excel {
    /// 图标 + 文案格（`Content.iconText`）。
    open class IconTextCell: Cell {
        /// 内置图标或自定义图。
        public enum IconStyle {
            case delete
            case clear
            case custom(UIImage)

            public var image: UIImage {
                switch self {
                    case .delete: return UIImage.lex("lex_delete")
                    case .clear: return UIImage.lex("lex_clear")
                    case let .custom(image): return image
                }
            }
        }

        /// 图标相对文案的左右位置。
        public enum IconPosition {
            case leading
            case trailing
        }

        public let textLabel = UILabel()
        public let iconImageView = UIImageView()

        /// 图标样式，默认 `.delete`。
        public var style: IconStyle = .delete {
            didSet {
                iconImageView.image = style.image
                setNeedsLayout()
            }
        }

        /// icon 位置，默认 .leading
        /// 图标相对文案的位置，默认左侧。
        public var iconPosition: IconPosition = .leading {
            didSet {
                setNeedsLayout()
            }
        }

        open override func initSubviews() {
            super.initSubviews()
            textLabel.resetAppearance()
            contentView.addSubview(textLabel)

            iconImageView.resetAppearance()
            contentView.addSubview(iconImageView)
            style = .delete
            iconPosition = .leading
        }

        open override func applyAppearance() {
            super.applyAppearance()
            textLabel.textColor = appearance.textColor
            textLabel.font = appearance.font
        }

        open override func bindContent(_ content: Content?, context: ContentBindContext = .init()) {
            guard case let .iconText(style, text) = content else { return }
            self.style = style
            textLabel.text = text
            if let alignment = context.textAlignment {
                textLabel.textAlignment = alignment
            }
        }

        open override func layoutSubviews() {
            super.layoutSubviews()
            var paddingLeft = padding.left
            var paddingRight = padding.right
            if !iconImageView.isHidden {
                iconImageView.sizeToFit()
                iconImageView.centerY = contentView.height / 2
                // 仅当 icon 与 title 同时存在时计入 `iconTitleSpacing`
                let spacing = !(textLabel.text ?? "").isEmpty ? iconTitleSpacing : 0
                switch iconPosition {
                    case .leading:
                        iconImageView.x = paddingLeft
                        paddingLeft += iconImageView.width + spacing
                    case .trailing:
                        iconImageView.right = contentView.width - paddingRight
                        paddingRight += iconImageView.width + spacing
                }
            }
            textLabel.frame = contentView.bounds.inset(by: .init(padding.top, paddingLeft, padding.bottom, paddingRight))
        }
    }

    /// 纯图片格（`Content.image`）；图片由业务在 `handle*` 中设置，不走 `cellPadding`。
    public class ImageCell: Cell {
        public let imageView = UIImageView()

        public override func initSubviews() {
            super.initSubviews()
            imageView.resetAppearance()
            imageView.contentMode = .scaleAspectFit
            contentView.addSubview(imageView)
        }

        public override func layoutSubviews() {
            super.layoutSubviews()
            // 纯 image：不走 cellPadding，铺满 contentView
            imageView.frame = contentView.bounds
        }
    }

    /// 多选勾选格（`Content.select`）。
    public class SelectCell: Cell {
        public enum SelectStyle {
            case square(_ isSelected: Bool)
            case circle(_ isSelected: Bool)

            public var image: UIImage {
                switch self {
                    case let .square(isSelected):
                        return UIImage.lex(isSelected ? "lex_switch_on" : "lex_switch_off")
                    case let .circle(isSelected):
                        return UIImage.lex(isSelected ? "lex_round_selected" : "lex_round_unselected")
                }
            }
        }

        private let imageView = UIImageView()

        /// 勾选外观（方 / 圆 × 选中态）。
        public var style: SelectStyle = .square(false) {
            didSet {
                imageView.image = style.image
                setNeedsLayout()
            }
        }

        public override func initSubviews() {
            super.initSubviews()
            imageView.resetAppearance()
            imageView.contentMode = .center
            contentView.addSubview(imageView)
            style = .square(false)
        }

        public override func bindContent(_ content: Content?, context: ContentBindContext = .init()) {
            guard case .select = content else { return }
            style = .square(context.isSelected)
        }

        public override func layoutSubviews() {
            super.layoutSubviews()
            // 纯选中图：不走 cellPadding，铺满 contentView
            imageView.frame = contentView.bounds
        }
    }
}
