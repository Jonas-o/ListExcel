//
//  ExcelModels.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension Excel {
    /// 排序类型
    public enum OrderType: String, Codable {
        case none = ""
        /// 升序
        case ascending = "ASC"
        /// 降序
        case descending = "DESC"

        public static var `default`: Self { .descending }
    }

    public struct Matrix {
        public enum Row {
            case header
            case footer
            case cell(Int)

            public var rawValue: Int {
                switch self {
                    case .header: return -1
                    case .footer: return -2
                    case let .cell(value): return value
                }
            }

            public var isHeader: Bool { rawValue == Row.header.rawValue }
            public var isFooter: Bool { rawValue == Row.footer.rawValue }
            public var isCell: Bool { rawValue >= 0 }
        }

        public let column: Int
        public let row: Row

        public init(column: Int, row: Row) {
            self.column = column
            self.row = row
        }
    }

    /// Cell 的点击效果, 不包括 header & footer
    public enum SelectionType {
        case none
        case cell(UIColor = UIColor(red: 247 / 255, green: 247 / 255, blue: 247 / 255, alpha: 1))
        case row(UIColor = UIColor(red: 247 / 255, green: 247 / 255, blue: 247 / 255, alpha: 1))
        /// 接管所有的 row 点击
        case rowSelection(UIColor = UIColor(red: 247 / 255, green: 247 / 255, blue: 247 / 255, alpha: 1))

        public var color: UIColor? {
            switch self {
                case let .cell(color), let .row(color), let .rowSelection(color):
                    return color
                default: return nil
            }
        }

        public var isNone: Bool {
            switch self {
                case .none: return true
                default: return false
            }
        }

        public var isCell: Bool {
            switch self {
                case .cell: return true
                default: return false
            }
        }

        public var isRow: Bool {
            switch self {
                case .row, .rowSelection: return true
                default: return false
            }
        }
    }

    // MARK: - Header / Content

    public protocol Header {
        /// 表头文案
        var title: String { get }
        /// 排序列的Key (仅 text 类型的 Content 才支持排序)
        var sortBy: String { get }
        /// 是否有权限显示
        var hasPermission: Bool { get }
        /// 列最小宽度
        var minWidth: CGFloat? { get }
        /// 列最大宽度
        var maxWidth: CGFloat { get }
        /// 文案对齐方式
        var textAlignment: NSTextAlignment? { get }
        /// 当前列的【行】内容（不包括表头）
        func content(for model: RowModel, row: Int) -> Content?
    }

    /// 排序信息（以 `header.sortBy` 标识列；可见下标由当前 `headers` 反查）。
    public struct SortColumn<T> where T: Excel.Header {
        public let header: T
        public let type: Excel.OrderType

        public init(header: T, type: Excel.OrderType) {
            self.header = header
            self.type = type
        }
    }

    public protocol RowModel {}
    public protocol ModelIdentifier {
        var identifier: String { get }
    }
    public typealias RowSelection = RowModel & ModelIdentifier

    public struct CellUnion<T> where T: Excel.Header {
        public let row: Int
        public let column: Int
        public let header: T
        public let rowModel: RowModel

        public init(row: Int, column: Int, header: T, rowModel: RowModel) {
            self.row = row
            self.column = column
            self.header = header
            self.rowModel = rowModel
        }
    }

    public enum Content {
        public typealias Tuple = DecimalLabel.DecimalTuple
        public typealias NumberStyle = DecimalLabel.NumberStyle
        public typealias IconStyle = Excel.IconTextCell.IconStyle
        /// SelectCell
        case select
        /// TextCell
        case decimal(Decimal?, _ style: NumberStyle = .none, _ hiddenZero: Bool = false)
        case decimals([Tuple])
        /// TextCell or HeaderTextCell
        case text(String?)
        /// ImageCell（图片内容由业务在 handleRow / handleHeader / handleFooter 中自行配置）
        case image
        /// IconTextCell
        case iconText(IconStyle, String?)
        /// TextFieldCell
        case textField(String?)
        /// CornerTextCell
        case cornerText(String?, leadingCorner: Tuple? = nil, trailingCorner: Tuple? = nil)
        case cornerDecimal(Decimal?, _ style: NumberStyle = .none, leadingCorner: Tuple? = nil, trailingCorner: Tuple? = nil)
        /// CornerTextFieldCell
        case cornerTextField(String?, leadingCorner: Tuple? = nil, trailingCorner: Tuple? = nil)

        var targetClassType: Excel.Cell.ClassType {
            switch self {
                case .select: return .select
                case .decimal, .decimals, .text: return .text
                case .image: return .image
                case .iconText: return .iconText
                case .textField: return .textField
                case .cornerText, .cornerDecimal: return .cornerText
                case .cornerTextField: return .cornerTextField
            }
        }

        public func contentWidth(with font: UIFont, configuration: Excel.Configuration = .init()) -> CGFloat? {
            let horizontalPadding = configuration.cellPadding.horizontalValue
            let iconTitleSpacing = configuration.iconTitleSpacing
            let locale = configuration.locale

            func cornerChromeWidth(hasLeading: Bool, hasTrailing: Bool) -> CGFloat {
                let metrics = Excel.CornerLabelMetrics.self
                var chrome = metrics.horizontalInset * 2
                if hasLeading, hasTrailing {
                    chrome += metrics.dualGap
                }
                return chrome
            }

            switch self {
                case let .decimal(decimal, style, hiddenZero):
                    let text = DecimalLabel.DecimalTuple(decimal, style: style, hiddenZero: hiddenZero).text(locale: locale)
                    if !text.isEmpty {
                        return text.width(font: font) + horizontalPadding
                    }
                case let .decimals(values):
                    if !values.isEmpty {
                        let widths = values.map { $0.text(locale: locale) }.map { $0.width(font: font) }
                        if let max = widths.max() {
                            return max + horizontalPadding
                        }
                    }
                case let .text(text):
                    if let text, !text.isEmpty {
                        return text.width(font: font) + horizontalPadding
                    }
                case let .iconText(style, text):
                    // 有 title：padding + iconTitleSpacing + icon；仅 icon：padding + icon（不加 spacing）
                    if let text, !text.isEmpty {
                        return text.width(font: font) + horizontalPadding + iconTitleSpacing + style.image.size.width
                    } else {
                        return style.image.size.width + horizontalPadding
                    }
                case let .textField(text):
                    if let text, !text.isEmpty {
                        // TextField 不走 cellPadding；预留输入态边距（与布局 pixelOne / textRect 对齐的经验值）
                        return text.width(font: font) + 24
                    }
                case let .cornerText(text, leadingCorner, trailingCorner):
                    let hasLeading = leadingCorner != nil
                    let hasTrailing = trailingCorner != nil
                    var cornerContentWidth: CGFloat = 0
                    if let width = leadingCorner?.text(locale: locale).width(font: CornerLabelMetrics.font) {
                        cornerContentWidth += width
                    }
                    if let width = trailingCorner?.text(locale: locale).width(font: CornerLabelMetrics.font) {
                        cornerContentWidth += width
                    }
                    if cornerContentWidth > 0 {
                        cornerContentWidth += cornerChromeWidth(hasLeading: hasLeading, hasTrailing: hasTrailing)
                    }
                    if let text, !text.isEmpty {
                        return max(text.width(font: font) + horizontalPadding, cornerContentWidth)
                    }
                    if cornerContentWidth > 0 {
                        return cornerContentWidth
                    }
                case let .cornerDecimal(decimal, style, leadingCorner, trailingCorner):
                    let hasLeading = leadingCorner != nil
                    let hasTrailing = trailingCorner != nil
                    var cornerContentWidth: CGFloat = 0
                    if let width = leadingCorner?.text(locale: locale).width(font: CornerLabelMetrics.font) {
                        cornerContentWidth += width
                    }
                    if let width = trailingCorner?.text(locale: locale).width(font: CornerLabelMetrics.font) {
                        cornerContentWidth += width
                    }
                    if cornerContentWidth > 0 {
                        cornerContentWidth += cornerChromeWidth(hasLeading: hasLeading, hasTrailing: hasTrailing)
                    }
                    if let text = decimal?.formatted(style, locale: locale), !text.isEmpty {
                        return max(text.width(font: font) + horizontalPadding, cornerContentWidth)
                    }
                    if cornerContentWidth > 0 {
                        return cornerContentWidth
                    }
                case let .cornerTextField(text, leadingCorner, trailingCorner):
                    let hasLeading = leadingCorner != nil
                    let hasTrailing = trailingCorner != nil
                    var cornerContentWidth: CGFloat = 0
                    if let width = leadingCorner?.text(locale: locale).width(font: CornerLabelMetrics.font) {
                        cornerContentWidth += width
                    }
                    if let width = trailingCorner?.text(locale: locale).width(font: CornerLabelMetrics.font) {
                        cornerContentWidth += width
                    }
                    if cornerContentWidth > 0 {
                        cornerContentWidth += cornerChromeWidth(hasLeading: hasLeading, hasTrailing: hasTrailing)
                    }
                    if let text, !text.isEmpty {
                        return max(text.width(font: font) + 24, cornerContentWidth)
                    }
                    if cornerContentWidth > 0 {
                        return cornerContentWidth
                    }
                default: break
            }
            return nil
        }
    }
}

public extension Excel.Header {
    /// 排序列的Key
    var sortBy: String { "" }
    /// 是否有权限显示
    var hasPermission: Bool { true }
    /// 列最小宽度
    var minWidth: CGFloat? { nil }
    /// 列最大宽度
    var maxWidth: CGFloat { 300 }
    /// 文案对齐方式
    var textAlignment: NSTextAlignment? { nil }
    /// 默认不提供列内容，回退到 `ListExcelDelegate.contentAt`
    func content(for model: Excel.RowModel, row: Int) -> Excel.Content? { nil }
}

extension Excel.SortColumn: Codable where T: Codable {}

public extension Excel.Header where Self: RawRepresentable, RawValue == String {
    var title: String { rawValue }
}
