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
    static let accentColor: UIColor = .softGreen
    static let headerBackgroundColor: UIColor = .hex("#F4F6F8")
    static let highlightColor: UIColor = .backgroundGray
    static let separatorColor: UIColor = UIColor(white: 0.85, alpha: 1)
    static let warnTextColor: UIColor = .systemRed

    static var defaultSelectionType: Excel.SelectionType { .row(highlightColor) }

    static let showsSortHint = true
    static let loadMoreThreshold: CGFloat = 100
    static let showsTotalView = true

    static let defaultFractionDigits = 2
    static let noneMaximumFractionDigits = 4

    private enum LanguageBucket {
        case zh
        case en
        case ja
    }

    private static func languageBucket(for locale: Foundation.Locale) -> LanguageBucket {
        let code: String?
        if #available(iOS 16, *) {
            code = locale.language.languageCode?.identifier
        } else {
            code = locale.languageCode
        }
        switch code {
            case "zh": return .zh
            case "ja": return .ja
            default: return .en
        }
    }

    static func footerSumTitle(locale: Foundation.Locale) -> String {
        switch languageBucket(for: locale) {
            case .zh: return "合计"
            case .ja: return "合計"
            case .en: return "Total"
        }
    }

    static func clearSortTitle(locale: Foundation.Locale) -> String {
        switch languageBucket(for: locale) {
            case .zh: return "清除"
            case .ja: return "クリア"
            case .en: return "Clear"
        }
    }

    static func totalText(for count: Int, locale: Foundation.Locale) -> String {
        switch languageBucket(for: locale) {
            case .zh: return "共计\(count)条"
            case .ja: return "全\(count)件"
            case .en: return "Total \(count)"
        }
    }

    static func sortHint<T: Excel.Header>(for column: Excel.SortColumn<T>, locale: Foundation.Locale) -> String {
        let title = column.header.title
        switch languageBucket(for: locale) {
            case .zh:
                let order = column.type == .ascending ? "升序" : "降序"
                return "当前按【\(title)】\(order)"
            case .ja:
                let order = column.type == .ascending ? "昇順" : "降順"
                return "【\(title)】で\(order)"
            case .en:
                let order = column.type == .ascending ? "ascending" : "descending"
                return "Sorted by 【\(title)】 \(order)"
        }
    }
}
