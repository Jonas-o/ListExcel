//
//  ListExcelView+Bridge.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

/// 将 `ExcelDelegate` 隔离在模块内，避免 `ListExcelView` 对外暴露 Excel 回调。
final class ListExcelExcelBridge<T: Excel.Header>: NSObject, ExcelDelegate {
    unowned let owner: ListExcelView<T>

    init(owner: ListExcelView<T>) {
        self.owner = owner
        super.init()
    }

    func numberOfRows(in excel: Excel) -> Int {
        owner.numberOfRows
    }

    func numberOfColumns(in excel: Excel) -> Int {
        owner.numberOfColumns
    }

    func excel(_ excel: Excel, columnWidthAt column: Int) -> CGFloat {
        owner.excel(excel, columnWidthAt: column)
    }

    func excel(_ excel: Excel, dequeueReusableCellAt matrix: Excel.Matrix) -> Excel.Cell.ClassType? {
        owner.excel(excel, dequeueReusableCellAt: matrix)
    }

    func excel(_ excel: Excel, handle cell: some Excel.Cell, at matrix: Excel.Matrix) {
        owner.excel(excel, handle: cell, at: matrix)
    }

    func excel(_ excel: Excel, backgroundColorAt row: Excel.Matrix.Row) -> UIColor? {
        owner.excel(excel, backgroundColorAt: row)
    }

    func excel(_ excel: Excel, didSelectHeaderAt column: Int) {
        owner.excel(excel, didSelectHeaderAt: column)
    }

    func excel(_ excel: Excel, didSelectRowAt row: Excel.Matrix.Row, column: Int?) {
        owner.excel(excel, didSelectRowAt: row, column: column)
    }

    func excel(_ excel: Excel, didSelectFooterAt column: Int) {
        owner.excel(excel, didSelectFooterAt: column)
    }

    func excel(_ excel: Excel, scrollViewDidScroll scrollView: UIScrollView) {
        owner.handleExcelScrollViewDidScroll(scrollView)
    }
}
