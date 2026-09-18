//
//  Support/DecimalLabel.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

// MARK: - Warn Style

/// 数值告警选项（零 / 负）。
public enum WarnLabel {
    /// 控制 ``DecimalLabel`` 在何种数值下改用 `warnTextColor`。
    public struct WarnStyle: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        /// 值为 0 时告警。
        public static let zero = WarnStyle(rawValue: 1 << 1)
        /// 值为负时告警。
        public static let negative = WarnStyle(rawValue: 1 << 2)
        public static let all: WarnStyle = [.zero, .negative]
    }
}

// MARK: - DecimalLabel

/// 按 Locale 格式化展示 `Decimal` 的 Label；支持多行元组与零/负告警色。
public class DecimalLabel: UILabel {
    /// 数字格式风格。
    public enum NumberStyle {
        /// 无分组纯数字（locale 小数点；最多 4 位小数）。
        case none
        /// 分组小数；`nil` → 默认 2 位。
        case decimal(fractionDigits: Int?)
        /// 货币；`code == nil` → locale 默认货币。
        case currency(code: String?)
        /// 百分比（Decimal 为比率，如 0.15 → 15%）；`nil` → 默认 2 位。
        case percent(fractionDigits: Int?)
        /// 宿主自定义格式化。
        case custom((Decimal, Locale) -> String)

        public static var decimal: NumberStyle { .decimal(fractionDigits: nil) }
        public static var currency: NumberStyle { .currency(code: nil) }
        public static var percent: NumberStyle { .percent(fractionDigits: nil) }
    }

    /// 单行数字展示单元；多行时用数组拼 `\n`。
    public struct DecimalTuple {
        public let decimal: Decimal?
        public let style: NumberStyle
        /// 为 `true` 且值为 0 时输出空串。
        public let hiddenZero: Bool

        public init(_ decimal: Decimal?, style: NumberStyle = .none, hiddenZero: Bool = false) {
            self.decimal = decimal
            self.style = style
            self.hiddenZero = hiddenZero
        }

        /// 按给定 Locale 格式化为字符串。
        public func text(locale: Locale) -> String {
            if hiddenZero, decimal == 0 { return "" }
            return decimal?.formatted(style, locale: locale) ?? ""
        }
    }

    private var normalTextColor: UIColor = .textBlack
    /// 命中 ``warnStyle`` 时使用的文字色。
    public var warnTextColor: UIColor = .red {
        didSet { resetTextColor() }
    }
    /// 何种数值改用 `warnTextColor`；默认仅负数。
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

    /// 设置要展示的数字行；空数组清空文案。多行以换行拼接，并按 ``warnStyle`` 着色。
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
