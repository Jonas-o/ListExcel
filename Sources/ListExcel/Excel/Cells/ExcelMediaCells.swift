//
//  ExcelMediaCells.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension Excel {
    public class IconTextCell: Cell {
        public enum IconStyle {
            case delete
            case clear
            case custom(UIImage)

            public var image: UIImage {
                switch self {
                case .delete: return UIImage.lex("excel_delete")
                case .clear: return UIImage.lex("clear")
                case let .custom(image): return image
                }
            }
        }

        public enum IconPosition {
            case leading
            case trailing
        }

        public let textLabel = UILabel()
        public let iconImageView = UIImageView()

        /// icon 样式，默认 .delete
        public var style: IconStyle = .delete {
            didSet {
                iconImageView.image = style.image
                setNeedsLayout()
            }
        }

        /// icon 位置，默认 .leading
        public var iconPosition: IconPosition = .leading {
            didSet {
                setNeedsLayout()
            }
        }

        public override func initSubviews() {
            super.initSubviews()
            textLabel.resetAppearance()
            contentView.addSubview(textLabel)

            iconImageView.resetAppearance()
            contentView.addSubview(iconImageView)
            style = .delete
            iconPosition = .leading
        }

        public override func applyAppearance() {
            super.applyAppearance()
            textLabel.textColor = appearance.textColor
            textLabel.font = appearance.font
        }

        public override func bindContent(_ content: Content?, context: ContentBindContext = .init()) {
            guard case let .iconText(style, text) = content else { return }
            self.style = style
            textLabel.text = text
            if let alignment = context.textAlignment {
                textLabel.textAlignment = alignment
            }
        }

        public override func layoutSubviews() {
            super.layoutSubviews()
            var paddingLeft = padding.left
            var paddingRight = padding.right
            if !iconImageView.isHidden {
                iconImageView.sizeToFit()
                iconImageView.centerY = contentView.height / 2
                switch iconPosition {
                case .leading:
                    iconImageView.x = paddingLeft
                    paddingLeft += iconImageView.width + margin
                case .trailing:
                    iconImageView.right = contentView.width - paddingRight
                    paddingRight += iconImageView.width + margin
                }
            }
            textLabel.frame = contentView.bounds.inset(by: .init(padding.top, paddingLeft, padding.bottom, paddingRight))
        }
    }

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
            imageView.frame = contentView.bounds
        }
    }

    public class SelectCell: Cell {
        public enum SelectStyle {
            case square(_ isSelected: Bool)
            case circle(_ isSelected: Bool)

            public var image: UIImage {
                switch self {
                case let .square(isSelected):
                    return UIImage.lex(isSelected ? "switch_on" : "switch_off")
                case let .circle(isSelected):
                    return UIImage.lex(isSelected ? "round_selected" : "round_unselected")
                }
            }
        }

        private let imageView = UIImageView()

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
            imageView.frame = contentView.bounds
        }
    }
}
