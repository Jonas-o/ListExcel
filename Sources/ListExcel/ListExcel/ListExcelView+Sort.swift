//
//  ListExcelView+Sort.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension ListExcelView {
    /// 清除排序
    public func clearSorts() {
        sortColumn = nil
        reloadHeader()
        didSortHeader()
    }

    /// apply sort（不触发 `didSortAt`，避免回写循环）。
    public func applySortColumn(_ column: Excel.SortColumn<T>?) {
        sortColumn = column
        reloadHeader()
    }
}
