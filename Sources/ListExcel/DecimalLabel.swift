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
        /// 无分组纯数字（locale 小数点；最多 4 位小数）
        case none
        /// 分组小数；`nil` → 默认 2 位
        case decimal(fractionDigits: Int?)
        /// 货币；`code == nil` → locale 默认货币
        case currency(code: String?)
        /// 百分比（Decimal 为比率，如 0.15 → 15%）；`nil` → 默认 2 位
        case percent(fractionDigits: Int?)
        case custom((Decimal, Locale) -> String)

        public static var decimal: NumberStyle { .decimal(fractionDigits: nil) }
        public static var currency: NumberStyle { .currency(code: nil) }
        public static var percent: NumberStyle { .percent(fractionDigits: nil) }
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

        public func text(locale: Locale) -> String {
            if hiddenZero, decimal == 0 { return "" }
            return decimal?.formatted(style, locale: locale) ?? ""
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
    private var formatLocale: Locale = .current

    public override init(frame: CGRect) {
        super.init(frame: frame)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public func setDecimal(_ decimals: [DecimalTuple], locale: Locale = .current) {
        self.decimals = decimals
        formatLocale = locale
        text = decimals.isEmpty ? nil : decimals.map { $0.text(locale: locale) }.joined(separator: "\n")
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
        let joined = decimals.map { $0.text(locale: formatLocale) }.joined(separator: "\n")
        let att = NSMutableAttributedString(string: joined)
        var location = 0
        for tuple in decimals {
            let text = tuple.text(locale: formatLocale)
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
