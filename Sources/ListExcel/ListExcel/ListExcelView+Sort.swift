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
}
