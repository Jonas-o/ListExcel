//
//  ExcelTextCells.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension Excel {
    public class TextCell: Cell {
        public let textLabel = DecimalLabel()

        public override func initSubviews() {
            super.initSubviews()
            textLabel.resetAppearance()
            textLabel.setDecimal([])
            textLabel.warnStyle = .negative
            contentView.addSubview(textLabel)
        }

        public override func applyAppearance() {
            super.applyAppearance()
            textLabel.textColor = appearance.textColor
            textLabel.warnTextColor = appearance.warnTextColor
            textLabel.font = appearance.font
        }

        public override func bindContent(_ content: Content?, context: ContentBindContext = .init()) {
            switch content {
            case let .decimal(decimal, style, hiddenZero):
                textLabel.setDecimal([.init(decimal, style: style, hiddenZero: hiddenZero)])
            case let .decimals(decimals):
                textLabel.setDecimal(decimals)
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

        public override func layoutSubviews() {
            super.layoutSubviews()
            textLabel.frame = contentView.bounds.inset(by: padding)
        }
    }

    public class CornerTextCell: Cell {
        public static let cornerFont = UIFont.systemFont(ofSize: 12)
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
                $0.font = Self.cornerFont
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
                textLabel.setDecimal([.init(decimal, style: style)])
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
                leadingCornerLabel.setDecimal([leading])
            }
            if let trailing {
                trailingCornerLabel.isHidden = false
                trailingCornerLabel.setDecimal([trailing])
            }
        }

        public override func layoutSubviews() {
            super.layoutSubviews()
            var cornerLabelWidth = contentView.width - 10
            if !leadingCornerLabel.isHidden, !trailingCornerLabel.isHidden {
                cornerLabelWidth = (cornerLabelWidth - 5) / 2
            }
            if !leadingCornerLabel.isHidden {
                leadingCornerLabel.sizeToFit()
                leadingCornerLabel.width = cornerLabelWidth
                leadingCornerLabel.origin = .init(5, 0)
            }
            if !trailingCornerLabel.isHidden {
                trailingCornerLabel.sizeToFit()
                trailingCornerLabel.width = cornerLabelWidth
                trailingCornerLabel.y = 0
                trailingCornerLabel.right = contentView.width - 5
            }

            textLabel.frame = contentView.bounds.inset(by: padding)
        }
    }

    public class HeaderTextCell: Cell {
        public let textLabel = UILabel()
        private let sortImageView = UIImageView(image: UIImage.lex("lex_arrow_desc"))

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
                paddingRight += sortImageView.width + margin
            }
            textLabel.frame = contentView.bounds.inset(by: padding.withRight(paddingRight))
        }
    }
}
