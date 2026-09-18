//
//  ExcelModels.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension Excel {
    /// 排序方向。表头循环点击默认从 ``default``（降序）开始。
    public enum OrderType: String, Codable {
        /// 无排序 / 清除后的态（序列化空串）。
        case none = ""
        /// 升序。
        case ascending = "ASC"
        /// 降序。
        case descending = "DESC"

        /// 首次点排序时使用的方向。
        public static var `default`: Self { .descending }
    }

    /// 格子坐标：列下标 + 行（表头 / 表尾 / 内容行）。
    public struct Matrix {
        /// 行类别。内容行用 `.cell(行下标)`，`rawValue ≥ 0`。
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

    /// 内容区点击高亮形态（不含表头 / 表尾）。配置于 ``Excel/Configuration/selectionType``。
    public enum SelectionType {
        /// 无高亮、不拦截为选中。
        case none
        /// 仅高亮点中的单元格。
        case cell(UIColor = UIColor(red: 247 / 255, green: 247 / 255, blue: 247 / 255, alpha: 1))
        /// 高亮整行；`ListExcelView` 仍可能把点击交给业务。
        case row(UIColor = UIColor(red: 247 / 255, green: 247 / 255, blue: 247 / 255, alpha: 1))
        /// 整行点选由列表接管为多选切换（需行实现 ``RowSelection``）。
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

    /// 列描述。`ListExcelView` 的泛型参数须遵循本协议。
    public protocol Header {
        /// 表头默认文案（Delegate 未覆盖时）。
        var title: String { get }
        /// 排序键；非空且表头 Content 为 text 时，点击由表头排序接管。空串表示不可排序。
        var sortBy: String { get }
        /// 为 `false` 时该列不进入可见 `headers`。
        var hasPermission: Bool { get }
        /// 列最小宽度；`nil` 不额外限制。
        var minWidth: CGFloat? { get }
        /// 列最大宽度。
        var maxWidth: CGFloat { get }
        /// 文案对齐；绑定 Content 时可注入 Cell。
        var textAlignment: NSTextAlignment? { get }
        /// 当前列在内容行的声明式 Content；返回 `nil` 时再问 Delegate。
        func content(for model: RowModel, row: Int) -> Content?
    }

    /// 当前排序（以 `header.sortBy` 标识列；可见下标由当前 `headers` 反查）。
    public struct SortColumn<T> where T: Excel.Header {
        public let header: T
        public let type: Excel.OrderType

        public init(header: T, type: Excel.OrderType) {
            self.header = header
            self.type = type
        }
    }

    /// 内容行模型标记协议；具体字段由业务定义。
    public protocol RowModel {}
    /// 提供稳定 id，供多选集合与列宽增量缓存关联。
    public protocol ModelIdentifier {
        var identifier: String { get }
    }
    /// 可参与多选的行：同时是 ``RowModel`` 与 ``ModelIdentifier``。
    public typealias RowSelection = RowModel & ModelIdentifier

    /// Delegate `contentAt` 的上下文：行列、列头与行模型。
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

    /// 单元格展示内容；决定 dequeue 的 `ClassType` 与默认绑定。
    public enum Content {
        public typealias Tuple = DecimalLabel.DecimalTuple
        public typealias NumberStyle = DecimalLabel.NumberStyle
        public typealias IconStyle = Excel.IconTextCell.IconStyle
        /// 多选勾选格（`SelectCell`）。
        case select
        /// 单值数字（`TextCell`）。
        case decimal(Decimal?, _ style: NumberStyle = .none, _ hiddenZero: Bool = false)
        /// 多行数字（`TextCell`）。
        case decimals([Tuple])
        /// 纯文本（`TextCell` 或表头 `HeaderTextCell`）。
        case text(String?)
        /// 图片格（`ImageCell`）；图片内容由业务在 `handle*` 中配置。
        case image
        /// 图标 + 文案（`IconTextCell`）。
        case iconText(IconStyle, String?)
        /// 可编辑文本框（`TextFieldCell`）。
        case textField(String?)
        /// 主文案 + 左右角标数字（`CornerTextCell`）。
        case cornerText(String?, leadingCorner: Tuple? = nil, trailingCorner: Tuple? = nil)
        /// 主数字 + 左右角标（`CornerTextCell`）。
        case cornerDecimal(Decimal?, _ style: NumberStyle = .none, leadingCorner: Tuple? = nil, trailingCorner: Tuple? = nil)
        /// 可编辑主文案 + 左右角标（`CornerTextFieldCell`）。
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

        /// 按字体与配置估算内容理想宽度；无法估算时返回 `nil`（由列宽策略兜底）。
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
    /// 默认不可排序。
    var sortBy: String { "" }
    /// 默认有权限。
    var hasPermission: Bool { true }
    /// 默认不设最小宽。
    var minWidth: CGFloat? { nil }
    /// 默认最大宽 300。
    var maxWidth: CGFloat { 300 }
    /// 默认由 Cell / Content 决定对齐。
    var textAlignment: NSTextAlignment? { nil }
    /// 默认不提供列内容，回退到 `ListExcelDelegate.contentAt`
    func content(for model: Excel.RowModel, row: Int) -> Excel.Content? { nil }
}

extension Excel.SortColumn: Codable where T: Codable {}

public extension Excel.Header where Self: RawRepresentable, RawValue == String {
    /// 默认用 `rawValue` 作为表头文案。
    var title: String { rawValue }
}
