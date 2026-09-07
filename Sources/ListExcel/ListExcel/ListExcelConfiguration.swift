//
//  ListExcelConfiguration.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension ListExcelView {
    /// 静态文案策略：跟 `excel.locale` 内置表，或宿主固定串。
    public enum LocalizedText {
        /// 使用 `ExcelTheme` 按当前 locale 生成的默认文案。
        case localeDefault
        /// 宿主指定的固定文案（不随 locale 变化）。
        case custom(String)

        /// 带上下文的文案策略（如合计条数、当前排序列）。
        public enum Source<Context> {
            /// 使用 `ExcelTheme` 按当前 locale + 上下文生成。
            case localeDefault
            /// 宿主闭包动态生成；固定文案可用 `{ _ in "…" }`。
            case custom((Context) -> String)
        }
    }

    /// 列表级配置（内含 `Excel.Configuration`）。
    /// 修改后需调用 `applyConfiguration()` 才会刷新界面。
    public struct Configuration {
        /// 底层表格引擎配置（布局 / 外观 / locale / 选中等）。
        public var excel = Excel.Configuration()

        /// Footer 第 0 列在无 Delegate/Header 内容时的默认合计标题。
        /// - `nil`：不显示该回退标题
        /// - `.localeDefault`：跟 `excel.locale`（默认）
        /// - `.custom`：固定文案
        public var footerSumTitle: LocalizedText? = .localeDefault
        /// 底栏右侧「共计 N 条」类文案。
        /// - `nil`：不显示合计文字（底栏仍可由 `showsTotalView` 控制）
        /// - `.localeDefault` / `.custom`：见 `LocalizedText.Source`
        public var totalText: LocalizedText.Source<Int>? = .localeDefault
        /// 当前排序提示文案；显隐由 `showsSortHint` 与是否存在 `sortColumn` 共同决定。
        public var sortHintText: LocalizedText.Source<Excel.SortColumn<T>> = .localeDefault
        /// 「清除排序」按钮标题；随排序提示一并显隐。
        public var clearSortTitle: LocalizedText = .localeDefault

        /// 为 `true` 时内容行使用 `excel.enlargedRowHeight`（如媒体封面模式）。
        public var enlargeImageRows: Bool = false
        /// 是否在底栏展示排序提示与清除按钮（有 `sortColumn` 时才真正出现）。
        public var showsSortHint: Bool = ExcelTheme.showsSortHint
        /// 是否展示底部合计栏（`ExcelTotalView`）。
        public var showsTotalView: Bool = ExcelTheme.showsTotalView
        /// 距底部多少 pt 内触发 loadMore 判定。
        public var loadMoreThreshold: CGFloat = ExcelTheme.loadMoreThreshold

        public init() {
            excel.showsHeaderColumnLines = true
        }

        /// 解析后的 footer 合计标题；`nil` 表示不显示回退标题。
        public func resolvedFooterSumTitle() -> String? {
            resolve(footerSumTitle) {
                ExcelTheme.footerSumTitle(locale: excel.locale)
            }
        }

        /// 解析后的底栏合计文案；`nil` 表示不显示。
        public func resolvedTotalText(for count: Int) -> String? {
            resolve(totalText, context: count) {
                ExcelTheme.totalText(for: $0, locale: excel.locale)
            }
        }

        /// 解析后的排序提示文案。
        public func resolvedSortHint(for column: Excel.SortColumn<T>) -> String {
            resolve(sortHintText, context: column) {
                ExcelTheme.sortHint(for: $0, locale: excel.locale)
            }
        }

        /// 解析后的清除排序按钮标题。
        public func resolvedClearSortTitle() -> String {
            resolve(clearSortTitle) {
                ExcelTheme.clearSortTitle(locale: excel.locale)
            }
        }

        /// 当前应使用的内容行高（普通 / 放大）。
        public var resolvedRowHeight: CGFloat {
            enlargeImageRows ? excel.enlargedRowHeight : excel.rowHeight
        }
    }
}

extension ListExcelView.Configuration {
    func resolve(_ text: ListExcelView.LocalizedText?, localeDefault: () -> String) -> String? {
        guard let text else { return nil }
        switch text {
            case .localeDefault: return localeDefault()
            case let .custom(value): return value
        }
    }

    func resolve(_ text: ListExcelView.LocalizedText, localeDefault: () -> String) -> String {
        switch text {
            case .localeDefault: return localeDefault()
            case let .custom(value): return value
        }
    }

    func resolve<Context>(
        _ text: ListExcelView.LocalizedText.Source<Context>?,
        context: Context,
        localeDefault: (Context) -> String
    ) -> String? {
        guard let text else { return nil }
        switch text {
            case .localeDefault: return localeDefault(context)
            case let .custom(make): return make(context)
        }
    }

    func resolve<Context>(
        _ text: ListExcelView.LocalizedText.Source<Context>,
        context: Context,
        localeDefault: (Context) -> String
    ) -> String {
        switch text {
            case .localeDefault: return localeDefault(context)
            case let .custom(make): return make(context)
        }
    }
}
