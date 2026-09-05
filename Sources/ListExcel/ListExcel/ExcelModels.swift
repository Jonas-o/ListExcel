//
//  ExcelModels.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension Excel {
    // 支持缓存
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

    /// 排序信息
    public struct SortColumn<T> where T: Excel.Header {
        public let column: Int
        public let header: T
        public let type: Excel.OrderType

        public init(column: Int, header: T, type: Excel.OrderType) {
            self.column = column
            self.header = header
            self.type = type
        }
    }

    public protocol RowModel { }
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

        func contentWidth(with font: UIFont, configuration: Excel.Configuration = .init()) -> CGFloat? {
            let horizontalPadding = configuration.cellPadding.horizontalValue
            let cellMargin = configuration.cellMargin
            switch self {
                case let .decimal(decimal, style, hiddenZero):
                    let text = DecimalLabel.DecimalTuple(decimal, style: style, hiddenZero: hiddenZero).text
                    if !text.isEmpty {
                        // 计算加上默认间隔（修改 Cell 间隔时此处需要变化）
                        return text.width(font: font) + horizontalPadding
                    }
                case let .decimals(values):
                    if !values.isEmpty {
                        // 计算加上默认间隔（修改 Cell 间隔时此处需要变化）
                        let widths = values.compactMap { $0.text }.map { $0.width(font: font) }
                        if let max = widths.max() {
                            return max + horizontalPadding
                        }
                    }
                case let .text(text):
                    if let text, !text.isEmpty {
                        // 计算加上默认间隔（修改 Cell 间隔时此处需要变化）
                        return text.width(font: font) + horizontalPadding
                    }
                case let .iconText(style, text):
                    if let text, !text.isEmpty {
                        // 计算加上默认间隔（修改 Cell 间隔时此处需要变化）
                        return text.width(font: font) + horizontalPadding + cellMargin + style.image.size.width
                    } else {
                        return style.image.size.width + horizontalPadding
                    }
                case let .textField(text):
                    if let text, !text.isEmpty {
                        // 计算加上默认间隔（修改 Cell 间隔时此处需要变化）
                        return text.width(font: font) + 24
                    }
                case let .cornerText(text, leadingCorner, trailingCorner):
                    var cornerContentWidth: CGFloat = 0
                    if let width = leadingCorner?.text.width(font: CornerTextCell.cornerFont) {
                        cornerContentWidth += width
                    }
                    if let width = trailingCorner?.text.width(font: CornerTextCell.cornerFont) {
                        cornerContentWidth += width
                    }
                    if let text, !text.isEmpty {
                        return max(text.width(font: font) + horizontalPadding, cornerContentWidth)
                    }
                    if cornerContentWidth > 0 {
                        return cornerContentWidth
                    }
                case let .cornerDecimal(decimal, style, leadingCorner, trailingCorner):
                    var cornerContentWidth: CGFloat = 0
                    if let width = leadingCorner?.text.width(font: CornerTextCell.cornerFont) {
                        cornerContentWidth += width
                    }
                    if let width = trailingCorner?.text.width(font: CornerTextCell.cornerFont) {
                        cornerContentWidth += width
                    }
                    if let text = style.string(with: decimal), !text.isEmpty {
                        return max(text.width(font: font) + horizontalPadding, cornerContentWidth)
                    }
                    if cornerContentWidth > 0 {
                        return cornerContentWidth
                    }
                case let .cornerTextField(text, leadingCorner, trailingCorner):
                    var cornerContentWidth: CGFloat = 0
                    if let width = leadingCorner?.text.width(font: Excel.DefaultCornerTextFieldCell.cornerFont) {
                        cornerContentWidth += width
                    }
                    if let width = trailingCorner?.text.width(font: Excel.DefaultCornerTextFieldCell.cornerFont) {
                        cornerContentWidth += width
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
    /// 是否又去权限显示
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


