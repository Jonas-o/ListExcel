//
//  ListExcelDelegate.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

// MARK: - Data Source

public protocol ListExcelDataSource<T>: NSObjectProtocol where T: Excel.Header {
    associatedtype T

    func listExcelView(_ excelView: ListExcelView<T>, headerContentAt header: T, column: Int) -> Excel.Content?
    func listExcelView(_ excelView: ListExcelView<T>, contentAt union: Excel.CellUnion<T>) -> Excel.Content?
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

public protocol ListExcelInteractionDelegate<T>: NSObjectProtocol where T: Excel.Header {
    associatedtype T

    func listExcelView(_ excelView: ListExcelView<T>, didSelectHeaderAt header: T, column: Int)
    func listExcelView(_ excelView: ListExcelView<T>, didSelectRowAt row: Int, rowModel: Excel.RowModel, column: Int?, header: T?)
    func listExcelView(_ excelView: ListExcelView<T>, didSelectFooterAt header: T, column: Int)

    func listExcelView(_ excelView: ListExcelView<T>, didSortAt column: Excel.SortColumn<T>?)
    func listExcelView(_ excelView: ListExcelView<T>, selectedRowsChanged identifiers: Set<String>)
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

/// 一站式 Delegate（数据源 + Cell 处理 + 交互）
public typealias ListExcelDelegate<T> = ListExcelDataSource<T> & ListExcelCellHandling<T> & ListExcelInteractionDelegate<T> where T: Excel.Header
