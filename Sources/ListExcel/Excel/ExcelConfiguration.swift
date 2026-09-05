//
//  ExcelConfiguration.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension Excel {
    /// 表格全局配置（布局 / 外观 / 行为）
    public struct Configuration {
        // MARK: Layout

        public var headerHeight: CGFloat = ExcelTheme.headerHeight
        public var footerHeight: CGFloat = ExcelTheme.footerHeight
        public var rowHeight: CGFloat = ExcelTheme.rowHeight
        public var enlargedRowHeight: CGFloat = ExcelTheme.enlargedRowHeight
        public var leadingLockCount: Int = ExcelTheme.leadingLockCount
        public var trailingLockCount: Int = ExcelTheme.trailingLockCount
        public var cellPadding: UIEdgeInsets = ExcelTheme.cellPadding
        public var cellMargin: CGFloat = ExcelTheme.cellMargin

        // MARK: Appearance

        public var headerFont: UIFont = ExcelTheme.headerFont
        public var rowFont: UIFont = ExcelTheme.rowFont
        public var footerFont: UIFont = ExcelTheme.footerFont
        public var textColor: UIColor = ExcelTheme.textColor
        public var accentColor: UIColor = ExcelTheme.accentColor
        public var headerBackgroundColor: UIColor = ExcelTheme.headerBackgroundColor
        public var highlightColor: UIColor = ExcelTheme.highlightColor
        public var separatorColor: UIColor = ExcelTheme.separatorColor
        public var warnTextColor: UIColor = ExcelTheme.warnTextColor

        // MARK: Behavior

        public var selectionType: SelectionType = ExcelTheme.defaultSelectionType
        public var showsHeaderColumnLines: Bool = true

        public init() {}
    }

    /// 注入到单个 Cell 的外观快照（由 `Configuration` + 行类型生成）
    public struct Appearance {
        public var padding: UIEdgeInsets
        public var margin: CGFloat
        public var font: UIFont
        public var textColor: UIColor
        public var accentColor: UIColor
        public var highlightColor: UIColor
        public var separatorColor: UIColor
        public var warnTextColor: UIColor
        public var showsColumnLines: Bool

        public init(
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
