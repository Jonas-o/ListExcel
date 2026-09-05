//
//  ExcelTheme.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

/// 模块内默认主题（不对外暴露）；`Configuration` 默认值引用此处。
enum ExcelTheme {
    static let headerHeight: CGFloat = 40
    static let footerHeight: CGFloat = 40
    static let rowHeight: CGFloat = 44
    static let enlargedRowHeight: CGFloat = 66
    static let leadingLockCount: Int = 1
    static let trailingLockCount: Int = 0
    static let cellPadding: UIEdgeInsets = .init(0, 8)
    static let cellMargin: CGFloat = 8

    static let headerFont: UIFont = .defaultBold
    static let rowFont: UIFont = .default
    static let footerFont: UIFont = .default

    static let textColor: UIColor = .textBlack
    static let accentColor: UIColor = .lightGreen
    static let headerBackgroundColor: UIColor = .hex("#F4F6F8")
    static let highlightColor: UIColor = .backgroundGray
    static let separatorColor: UIColor = UIColor(white: 0.85, alpha: 1)
    static let warnTextColor: UIColor = .systemRed

    static var defaultSelectionType: Excel.SelectionType { .row(highlightColor) }

    static let footerSumTitle = "合计"
    static let clearSortTitle = "清除"
    static let showsSortHint = true
    static let loadMoreThreshold: CGFloat = 100
    static let showsTotalView = true

    static func totalText(for count: Int) -> String {
        "共计\(count)条"
    }

    static func sortHint<T: Excel.Header>(for column: Excel.SortColumn<T>) -> String {
        let order = column.type == .ascending ? "升序" : "降序"
        return "当前按【\(column.header.title)】\(order)"
    }
}
