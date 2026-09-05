//
//  ListExcelConfiguration.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension ListExcelView {
    /// 列表级配置（内含 `Excel.Configuration`）
    public struct Configuration {
        public var excel = Excel.Configuration()

        public var footerSumTitle: String? = ExcelTheme.footerSumTitle
        public var totalTextProvider: ((Int) -> String)?
        /// 排序提示文案；为 `nil` 时使用库内默认中文句式。
        public var sortHintProvider: ((Excel.SortColumn<T>) -> String)?
        public var showsSortHint: Bool = ExcelTheme.showsSortHint
        public var clearSortTitle: String = ExcelTheme.clearSortTitle
        public var enlargeImageRows: Bool = false
        public var loadMoreThreshold: CGFloat = ExcelTheme.loadMoreThreshold
        public var showsTotalView: Bool = ExcelTheme.showsTotalView

        public init() {}

        public func totalText(for count: Int) -> String {
            totalTextProvider?(count) ?? ExcelTheme.totalText(for: count)
        }

        public func sortHint(for column: Excel.SortColumn<T>) -> String {
            sortHintProvider?(column) ?? ExcelTheme.sortHint(for: column)
        }

        public var resolvedRowHeight: CGFloat {
            enlargeImageRows ? excel.enlargedRowHeight : excel.rowHeight
        }
    }
}
