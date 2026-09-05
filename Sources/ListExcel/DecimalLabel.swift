//
//  DecimalLabel.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

// MARK: - Warn Style

public enum WarnLabel {
    public struct WarnStyle: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let zero = WarnStyle(rawValue: 1 << 1)
        public static let negative = WarnStyle(rawValue: 1 << 2)
        public static let all: WarnStyle = [.zero, .negative]
    }
}

// MARK: - DecimalLabel

public class DecimalLabel: UILabel {
    public enum NumberStyle {
        case none
        case decimal
        case currency
        case percent

        public func string(with decimal: Decimal?) -> String? {
            switch self {
            case .none: return decimal?.stringValue
            case .decimal: return decimal?.priceValue
            case .currency: return decimal?.priceValueForRMB
            case .percent: return decimal?.percentString
            }
        }
    }

    public struct DecimalTuple {
        public let decimal: Decimal?
        public let style: NumberStyle
        public let hiddenZero: Bool

        public init(_ decimal: Decimal?, style: NumberStyle = .none, hiddenZero: Bool = false) {
            self.decimal = decimal
            self.style = style
            self.hiddenZero = hiddenZero
        }

        public var text: String {
            if hiddenZero, decimal == 0 { return "" }
            return style.string(with: decimal) ?? ""
        }
    }

    private var normalTextColor: UIColor = .textBlack
    public var warnTextColor: UIColor = .red {
        didSet { resetTextColor() }
    }
    public var warnStyle: WarnLabel.WarnStyle = .negative {
        didSet { resetTextColor() }
    }
    private var decimals: [DecimalTuple] = []

    public override init(frame: CGRect) {
        super.init(frame: frame)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public func setDecimal(_ decimals: [DecimalTuple]) {
        self.decimals = decimals
        text = decimals.isEmpty ? nil : decimals.map(\.text).joined(separator: "\n")
        resetTextColor()
    }

    private func resetTextColor() {
        guard decimals.count > 1 else {
            var color = normalTextColor
            if let first = decimals.first?.decimal, warnStyle.contains(.negative), first < 0 {
                color = warnTextColor
            } else if let first = decimals.first?.decimal, warnStyle.contains(.zero), first == 0 {
                color = warnTextColor
            }
            super.textColor = color
            return
        }
        let joined = decimals.map(\.text).joined(separator: "\n")
        let att = NSMutableAttributedString(string: joined)
        var location = 0
        for tuple in decimals {
            let text = tuple.text
            if let decimal = tuple.decimal,
               (warnStyle.contains(.negative) && decimal < 0) || (warnStyle.contains(.zero) && decimal == 0) {
                att.addAttribute(.foregroundColor, value: warnTextColor, range: NSRange(location: location, length: text.count))
            }
            location += text.count + 1
        }
        super.attributedText = att
    }

    public override var textColor: UIColor! {
        didSet { normalTextColor = textColor }
    }
}
