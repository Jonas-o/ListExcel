//
//  ExcelConfiguration.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension Excel {
    /// 表格全局配置（布局 / 外观 / 行为）。
    /// 修改后需经 `Excel.applyConfiguration` 或 `ListExcelView.applyConfiguration` 生效。
    public struct Configuration {
        // MARK: Layout

        /// 数字格式与内置 UI 文案所用 Locale；默认 `.current`。
        /// 预设见 `Excel.Locale`（如 `zhCN` / `enUS` / `jaJP`）。
        public var locale: Foundation.Locale = .current
        /// 表头行高；`0` 隐藏表头。
        public var headerHeight: CGFloat = ExcelTheme.headerHeight
        /// 表尾行高；`0` 隐藏表尾。
        public var footerHeight: CGFloat = ExcelTheme.footerHeight
        /// 普通内容行高。
        public var rowHeight: CGFloat = ExcelTheme.rowHeight
        /// 放大行高（如封面图模式，由列表层 `enlargeImageRows` 选用）。
        public var enlargedRowHeight: CGFloat = ExcelTheme.enlargedRowHeight
        /// 左侧锁定列数（不随中间区横滑）。
        public var leadingLockCount: Int = ExcelTheme.leadingLockCount
        /// 右侧锁定列数。
        public var trailingLockCount: Int = ExcelTheme.trailingLockCount
        /// 单元格内边距（影响文案测宽与布局）。
        public var cellPadding: UIEdgeInsets = ExcelTheme.cellPadding
        /// 图标等与文案之间的额外间距（测宽用）。
        public var cellMargin: CGFloat = ExcelTheme.cellMargin

        // MARK: Appearance

        /// 表头字体。
        public var headerFont: UIFont = ExcelTheme.headerFont
        /// 内容行字体。
        public var rowFont: UIFont = ExcelTheme.rowFont
        /// 表尾字体。
        public var footerFont: UIFont = ExcelTheme.footerFont
        /// 主文字颜色。
        public var textColor: UIColor = ExcelTheme.textColor
        /// 强调色（角标、输入框边框、选中相关等）。
        public var accentColor: UIColor = ExcelTheme.accentColor
        /// 表头背景色。
        public var headerBackgroundColor: UIColor = ExcelTheme.headerBackgroundColor
        /// 行/单元格选中高亮色。
        public var highlightColor: UIColor = ExcelTheme.highlightColor
        /// 分隔线颜色。
        public var separatorColor: UIColor = ExcelTheme.separatorColor
        /// 数值告警色（零 / 负数等，见 `DecimalLabel.warnStyle`）。
        public var warnTextColor: UIColor = ExcelTheme.warnTextColor

        // MARK: Behavior

        /// 选中形态（无 / 单元格 / 行 / 行多选等）。
        public var selectionType: SelectionType = ExcelTheme.defaultSelectionType
        /// 是否在表头绘制列竖线。
        public var showsHeaderColumnLines: Bool = false

        public init() {}
    }

    /// 注入到单个 Cell 的外观快照（由 `Configuration` + 行类型生成）。
    public struct Appearance {
        /// 与所属表格 `Configuration.locale` 一致，供数字格式化使用。
        public var locale: Foundation.Locale
        /// 单元格内边距。
        public var padding: UIEdgeInsets
        /// 图标与文案间距。
        public var margin: CGFloat
        /// 当前行对应字体（表头 / 行 / 表尾）。
        public var font: UIFont
        /// 主文字颜色。
        public var textColor: UIColor
        /// 强调色。
        public var accentColor: UIColor
        /// 高亮色。
        public var highlightColor: UIColor
        /// 分隔线颜色。
        public var separatorColor: UIColor
        /// 数值告警色。
        public var warnTextColor: UIColor
        /// 是否绘制列竖线（通常仅表头）。
        public var showsColumnLines: Bool

        public init(
            locale: Foundation.Locale,
            padding: UIEdgeInsets,
            margin: CGFloat,
            font: UIFont,
            textColor: UIColor,
            accentColor: UIColor,
            highlightColor: UIColor,
            separatorColor: UIColor,
            warnTextColor: UIColor,
            showsColumnLines: Bool
        ) {
            self.locale = locale
            self.padding = padding
            self.margin = margin
            self.font = font
            self.textColor = textColor
            self.accentColor = accentColor
            self.highlightColor = highlightColor
            self.separatorColor = separatorColor
            self.warnTextColor = warnTextColor
            self.showsColumnLines = showsColumnLines
        }

        public init(configuration: Configuration, row: Matrix.Row) {
            locale = configuration.locale
            padding = configuration.cellPadding
            margin = configuration.cellMargin
            switch row {
            case .header:
                font = configuration.headerFont
            case .footer:
                font = configuration.footerFont
            case .cell:
                font = configuration.rowFont
            }
            textColor = configuration.textColor
            accentColor = configuration.accentColor
            highlightColor = configuration.highlightColor
            separatorColor = configuration.separatorColor
            warnTextColor = configuration.warnTextColor
            showsColumnLines = configuration.showsHeaderColumnLines && row.isHeader
        }
    }
}
