//
//  ListExcelDelegate.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

// MARK: - Data Source

/// 列表内容与行背景。实现类型须为 `NSObject` 子类。
///
/// 单元格 `Content` 解析优先级（命中即停）：
/// 1. `Header.content(for:row:)`（列上声明式）
/// 2. 本协议的 `contentAt` / `headerContentAt` / `footerContentAt`
/// 3. 表头默认 `.text(header.title)`；Footer 第 0 列在皆空且 `configuration.footerSumTitle != nil` 时用合计标题
public protocol ListExcelDataSource<T>: NSObjectProtocol where T: Excel.Header {
    associatedtype T

    /// 表头格内容；`nil` 时回退到 `.text(header.title)`（见协议优先级说明）。
    func listExcelView(_ excelView: ListExcelView<T>, headerContentAt header: T, column: Int) -> Excel.Content?

    /// 内容行；仅在对应列的 `Header.content(for:)` 返回 `nil` 时才会问到这里。
    func listExcelView(_ excelView: ListExcelView<T>, contentAt union: Excel.CellUnion<T>) -> Excel.Content?

    /// 表尾格；`nil` 且为第 0 列时可能显示 `footerSumTitle`（见协议优先级说明）。
    func listExcelView(_ excelView: ListExcelView<T>, footerContentAt header: T, column: Int) -> Excel.Content?

    func listExcelView(headerBackgroundColor excelView: ListExcelView<T>) -> UIColor?
    func listExcelView(_ excelView: ListExcelView<T>, backgroundColorAt row: Int, rowModel: Excel.RowModel) -> UIColor?
    func listExcelView(footerBackgroundColor excelView: ListExcelView<T>) -> UIColor?
}

public extension ListExcelDataSource {
    func listExcelView(_ excelView: ListExcelView<T>, headerContentAt header: T, column: Int) -> Excel.Content? { nil }
    func listExcelView(_ excelView: ListExcelView<T>, contentAt union: Excel.CellUnion<T>) -> Excel.Content? { nil }
    func listExcelView(_ excelView: ListExcelView<T>, footerContentAt header: T, column: Int) -> Excel.Content? { nil }
    func listExcelView(headerBackgroundColor excelView: ListExcelView<T>) -> UIColor? { nil }
    func listExcelView(_ excelView: ListExcelView<T>, backgroundColorAt row: Int, rowModel: Excel.RowModel) -> UIColor? { nil }
    func listExcelView(footerBackgroundColor excelView: ListExcelView<T>) -> UIColor? { nil }
}

// MARK: - Cell Handling

/// Cell 二次配置。库已按 `Content` 完成 `bindContent` 后再调用，适合设图、键盘、回调等 Content 表达不了的属性。
public protocol ListExcelCellHandling<T>: NSObjectProtocol where T: Excel.Header {
    associatedtype T

    func listExcelView(_ excelView: ListExcelView<T>, handleHeader cell: some Excel.Cell, at header: T, column: Int)
    func listExcelView(_ excelView: ListExcelView<T>, handleRow cell: some Excel.Cell, union: Excel.CellUnion<T>)
    func listExcelView(_ excelView: ListExcelView<T>, handleFooter cell: some Excel.Cell, at header: T, column: Int)
}

public extension ListExcelCellHandling {
    func listExcelView(_ excelView: ListExcelView<T>, handleHeader cell: some Excel.Cell, at header: T, column: Int) { }
    func listExcelView(_ excelView: ListExcelView<T>, handleRow cell: some Excel.Cell, union: Excel.CellUnion<T>) { }
    func listExcelView(_ excelView: ListExcelView<T>, handleFooter cell: some Excel.Cell, at header: T, column: Int) { }
}

// MARK: - Interaction

/// 点击 / 排序 / 多选 / 分页。部分手势会被列表内部接管，不一定落到下列回调。
public protocol ListExcelInteractionDelegate<T>: NSObjectProtocol where T: Excel.Header {
    associatedtype T

    /// 表头点击。若该列可排序（`sortBy` 非空且为 text 头）或为 `.select` / 图片列头切换行高，列表会先内部处理并 **不再** 调用本方法。
    func listExcelView(_ excelView: ListExcelView<T>, didSelectHeaderAt header: T, column: Int)

    /// 行或单元格点击。
    /// - Parameter column: 点中的列；整行点选时可能为 `nil`。
    /// - Note: 若点中 `.select` 列，或 `selectionType == .rowSelection` 时点中行，列表会切换选中态并刷新，**不**再调用本方法。
    func listExcelView(_ excelView: ListExcelView<T>, didSelectRowAt row: Int, rowModel: Excel.RowModel, column: Int?, header: T?)

    func listExcelView(_ excelView: ListExcelView<T>, didSelectFooterAt header: T, column: Int)

    /// 排序变化；`column == nil` 表示已清除排序（如点「清除排序」）。
    func listExcelView(_ excelView: ListExcelView<T>, didSortAt column: Excel.SortColumn<T>?)

    /// 多选集合变化；元素为行的 `ModelIdentifier.identifier`（无 id 的行不会进入集合）。
    func listExcelView(_ excelView: ListExcelView<T>, selectedRowsChanged identifiers: Set<String>)

    /// 触底加载。参数为 **下一页页码**（当前 `page + 1`），不是已加载完的页。宿主应请求该页并 `append`，再更新 `page` / `total`。
    func listExcelView(_ excelView: ListExcelView<T>, requestNext page: Int)
}

public extension ListExcelInteractionDelegate {
    func listExcelView(_ excelView: ListExcelView<T>, didSelectHeaderAt header: T, column: Int) { }
    func listExcelView(_ excelView: ListExcelView<T>, didSelectRowAt row: Int, rowModel: Excel.RowModel, column: Int?, header: T?) { }
    func listExcelView(_ excelView: ListExcelView<T>, didSelectFooterAt header: T, column: Int) { }
    func listExcelView(_ excelView: ListExcelView<T>, didSortAt column: Excel.SortColumn<T>?) { }
    func listExcelView(_ excelView: ListExcelView<T>, selectedRowsChanged identifiers: Set<String>) { }
    func listExcelView(_ excelView: ListExcelView<T>, requestNext page: Int) { }
}

/// 数据源 + Cell 处理 + 交互的组合别名；可只遵循子集协议。
public typealias ListExcelDelegate<T> = ListExcelDataSource<T> & ListExcelCellHandling<T> & ListExcelInteractionDelegate<T> where T: Excel.Header
