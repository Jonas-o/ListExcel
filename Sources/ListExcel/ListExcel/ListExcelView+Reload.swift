//
//  ListExcelView+Reload.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension ListExcelView {
    /// `reload` 批量子快照：`configuration` 预填当前值；其余 Optional 有值才写入。
    public struct Batch {
        /// 当前配置的副本；提交时恒写回。
        public var configuration: Configuration
        public var headers: [T]?
        public var rowDatas: [any Excel.RowModel]?
        public var total: Int?
        public var page: Int?
        public var isLoading: Bool?
        /// `true` 清空选中；`false` 若写了 `rowDatas` 则按 id 裁剪保留。
        public var clearsSelection: Bool

        public init(configuration: Configuration, clearsSelection: Bool = false) {
            self.configuration = configuration
            self.clearsSelection = clearsSelection
        }
    }

    /// 批改可编辑态：按赋值情况选择列宽缓存策略，并尽量只对齐一次 UI。
    /// - `isLoading == true`：第一步写入；`== false`：最后一步写入；`nil`：不碰。
    public func reload(_ update: (inout Batch) -> Void) {
        let configurationBaseline = configuration
        var batch = Batch(configuration: configurationBaseline)
        update(&batch)
        commitReload(batch, configurationBaseline: configurationBaseline)
    }
}

extension ListExcelView {
    func commitReload(_ batch: Batch, configurationBaseline: Configuration) {
        let widthMetricsChanged = !batch.configuration.hasSameWidthMetrics(as: configurationBaseline)
        let headersAssigned = batch.headers != nil
        let rowsAssigned = batch.rowDatas != nil

        if batch.isLoading == true {
            isLoading = true
        }

        // 恒写 configuration（含不影响列宽的文案/颜色等）
        configuration = batch.configuration
        syncListChrome()

        let dropAllWidthCache = widthMetricsChanged || headersAssigned
        let useRowsDiff = !widthMetricsChanged && !headersAssigned && rowsAssigned

        if let headers = batch.headers {
            self.headers = headers
        }

        if dropAllWidthCache {
            invalidateWidthCache()
            if let rows = batch.rowDatas {
                rowDatas = rows
                rebuildModelIdCounts()
                pruneOrClearSelection(clearsSelection: batch.clearsSelection, rowsChanged: true)
                for (index, model) in rowDatas.enumerated() {
                    _ = measureRow(model, index: index)
                }
            } else {
                pruneOrClearSelection(clearsSelection: batch.clearsSelection, rowsChanged: false)
                rebuildAllRowWidthContributions()
            }
            measureHeaderFooter()
            recomputeWidthsFromRowContributions()
        } else if useRowsDiff, let rows = batch.rowDatas {
            applyResetDiff(rows)
            pruneOrClearSelection(clearsSelection: batch.clearsSelection, rowsChanged: true)
            measureHeaderFooter()
            recomputeWidthsFromRowContributions()
        } else {
            pruneOrClearSelection(clearsSelection: batch.clearsSelection, rowsChanged: false)
        }

        if let total = batch.total {
            self.total = total
        }
        if let page = batch.page {
            self.page = page
        }

        setNeedsLayout()

        // configuration 恒写：轻量也要刷 cell 外观；结构变更则对齐整表（宽度已在上方算好）
        if isLoading {
            pendingUIRefresh = .fullReconcile
        } else {
            performResetStyleUIRefresh()
        }

        if batch.isLoading == false {
            // 本事务若已在非 loading 下刷过 → 清 pending 再赋 false，避免 didSet 双刷；
            // 若仍在 loading 且已记 pending → 交给 didSet 冲刷一次。
            if !isLoading {
                pendingUIRefresh = .none
                isLoading = false
            } else {
                isLoading = false
            }
        }
    }

    private func pruneOrClearSelection(clearsSelection: Bool, rowsChanged: Bool) {
        if clearsSelection {
            clearSelection()
        } else if rowsChanged {
            pruneSelectRows(to: rowDatas)
        }
    }
}

extension ListExcelView.Configuration {
    /// 是否与另一配置在「影响列宽测宽 / fingerprint」的字段上一致。
    func hasSameWidthMetrics(as other: Self) -> Bool {
        enlargeImageRows == other.enlargeImageRows
            && excel.hasSameWidthMetrics(as: other.excel)
    }
}

extension Excel.Configuration {
    func hasSameWidthMetrics(as other: Self) -> Bool {
        locale.identifier == other.locale.identifier
            && headerHeight == other.headerHeight
            && footerHeight == other.footerHeight
            && rowHeight == other.rowHeight
            && enlargedRowHeight == other.enlargedRowHeight
            && leadingLockCount == other.leadingLockCount
            && trailingLockCount == other.trailingLockCount
            && cellPadding == other.cellPadding
            && cellMargin == other.cellMargin
            && headerFont.isEqual(other.headerFont)
            && rowFont.isEqual(other.rowFont)
            && footerFont.isEqual(other.footerFont)
    }
}
