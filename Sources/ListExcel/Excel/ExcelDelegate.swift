//
//  ExcelDelegate.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

public protocol ExcelDelegate: UIScrollViewDelegate {
    var numberOfRows: Int { get }
    var numberOfColumns: Int { get }
    var leadingLockCount: Int { get }
    var trailingLockCount: Int { get }

    var headerHeight: CGFloat { get }
    var footerHeight: CGFloat { get }

    /// 行高控制（行高不同时使用excel:rowHeightAt:）推荐使用 rowHeight
    var rowHeight: CGFloat { get }
    func excel(_ excel: Excel, rowHeightAt row: Int) -> CGFloat?

    /// 列宽控制（列宽不同时使用excel:columnWidthAt:）推荐使用 excel(_:columnWidthAt:)
    var columnWidth: CGFloat { get }
    func excel(_ excel: Excel, columnWidthAt column: Int) -> CGFloat?

    func excel(_ excel: Excel, dequeueReusableCellAt matrix: Excel.Matrix) -> Excel.Cell.ClassType?
    func excel(_ excel: Excel, handle cell: some Excel.Cell, at matrix: Excel.Matrix)
    func excel(_ excel: Excel, backgroundColorAt row: Excel.Matrix.Row) -> UIColor?

    func excel(_ excel: Excel, didSelectHeaderAt column: Int)
    func excel(_ excel: Excel, didSelectRowAt row: Excel.Matrix.Row, column: Int?)
    func excel(_ excel: Excel, didSelectFooterAt column: Int)
}

public extension ExcelDelegate {
    var rowHeight: CGFloat { 44 }
    var columnWidth: CGFloat { 0 }
    func excel(_ excel: Excel, rowHeightAt row: Int) -> CGFloat? { nil }
    func excel(_ excel: Excel, columnWidthAt column: Int) -> CGFloat? { nil }
    func excel(_ excel: Excel, backgroundColorAt row: Excel.Matrix.Row) -> UIColor? { nil }
    func excel(_ excel: Excel, didSelectHeaderAt column: Int) { }
    func excel(_ excel: Excel, didSelectRowAt row: Excel.Matrix.Row, column: Int?) { }
    func excel(_ excel: Excel, didSelectFooterAt column: Int) { }
}
