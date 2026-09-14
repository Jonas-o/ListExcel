//
//  ListExcelView+Reload.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension ListExcelView {
    /// `reload` 批量子快照：`configuration` / `sortColumn` 预填当前值且提交时恒写回；其余 Optional 有值才写入。
    public struct Batch {
        /// 当前配置的副本；提交时恒写回。
        public var configuration: Configuration
        /// 当前排序；提交时恒写回（可显式置 `nil` 清除）。写 headers 后会按可见列校验。
        public var sortColumn: Excel.SortColumn<T>?
        public var headers: [T]?
        public var rowDatas: [any Excel.RowModel]?
        public var total: Int?
        public var page: Int?
        public var isLoading: Bool?
        /// `true` 清空选中；`false` 若写了 `rowDatas` 则按 id 裁剪保留。
        public var clearsSelection: Bool

        public init(configuration: Configuration, sortColumn: Excel.SortColumn<T>? = nil, clearsSelection: Bool = false) {
            self.configuration = configuration
            self.sortColumn = sortColumn
            self.clearsSelection = clearsSelection
        }
    }

    /// 批改可编辑态：按赋值情况选择列宽缓存策略，并尽量只对齐一次 UI。
    /// - `isLoading == true`：第一步写入；`== false`：最后一步写入；`nil`：不碰。
    public func reload(_ update: (inout Batch) -> Void) {
        let configurationBaseline = configuration
        var batch = Batch(configuration: configurationBaseline, sortColumn: sortColumn)
        update(&batch)
        commitReload(batch, configurationBaseline: configurationBaseline)
    }

    /// 在当前配置上批改字段；走 ``reload(_:)`` 同一提交路径（测宽字段未变时不整表重测）。
    public func mutateConfiguration(_ update: (inout Configuration) -> Void) {
        reload { batch in
            update(&batch.configuration)
        }
    }

    func syncListChrome() {
        clampLockCountsToVisibleColumns()
        var excelConfiguration = configuration.excel
        // enlargeImageRows 时把解析后的行高写入引擎，避免再依赖 Delegate 属性
        excelConfiguration.rowHeight = configuration.resolvedRowHeight
        excelView.configuration = excelConfiguration
        excelView.syncSelectionTypeToVisibleCells()
        clearSortButton.setTitle(configuration.resolvedClearSortTitle(), for: .normal)
        totalView.isHidden = !configuration.showsTotalView
        totalView.resetTotalText(configuration.resolvedTotalText(for: total))
        bottomNoticeLabel.font = configuration.excel.rowFont
        bottomNoticeLabel.textColor = configuration.excel.textColor.withAlphaComponent(0.6)
        currentSortLabel.font = configuration.excel.rowFont
        currentSortLabel.textColor = configuration.excel.textColor.withAlphaComponent(0.6)
        let current = sortColumn
        sortColumn = current
    }

    /// 保证 `leadingLockCount + trailingLockCount ≤ 可见列数`（优先保留左侧锁列）。
    func clampLockCountsToVisibleColumns() {
        let columnCount = max(headers.count, 0)
        var leading = max(0, configuration.excel.leadingLockCount)
        var trailing = max(0, configuration.excel.trailingLockCount)
        if leading > columnCount {
            leading = columnCount
            trailing = 0
        } else if leading + trailing > columnCount {
            trailing = columnCount - leading
        }
        configuration.excel.leadingLockCount = leading
        configuration.excel.trailingLockCount = trailing
    }

    /// 整表刷新并强制重测列宽（立刻执行）。`isLoading == true` 时只记待对齐。
    public func reloadData() {
        reloadData(immediate: true, widthPolicy: .recalculate)
    }

    /// 内部刷新入口：可指定防抖与列宽策略（`.recalculate` / `.keep` / `.reconcile`）。
    func reloadData(immediate: Bool, widthPolicy: ColumnWidthPolicy) {
        guard !isLoading else {
            pendingUIRefresh = .fullReconcile
            return
        }
        pendingUIRefresh = .none
        reloadDebouncer.perform(immediate: immediate) { [weak self] in
            guard let self else { return }
            switch widthPolicy {
                case .recalculate:
                    self.calculateColumnWidths()
                case .keep:
                    if self.widths.count != self.headers.count {
                        self.calculateColumnWidths()
                    }
                case .reconcile:
                    self.measureHeaderFooter()
                    self.recomputeWidthsFromRowContributions()
            }
            self.excelView.reloadData()
        }
    }

    public func reloadHeader() {
        excelView.reloadHeader()
    }

    public func reloadFooter() {
        excelView.reloadFooter()
    }

    /// 仅刷新内容，不涉及宽度变化
    public func reloadCell(at matrix: Excel.Matrix) {
        excelView.reloadCell(at: matrix)
    }

    /// 仅刷新内容，不涉及宽度变化
    public func reloadCells(at matrixs: [Excel.Matrix]) {
        excelView.reloadCells(at: matrixs)
    }

    /// 单列重算并同步到 Excel。不完整重建行级增量缓存；需严格一致时请 `reloadData()`。
    public func reloadCellWidth(_ column: Int, row: Excel.Matrix.Row? = nil) {
        guard
            widths.count == headers.count,
            0 ..< widths.count ~= column
        else {
            reloadData(immediate: true, widthPolicy: .recalculate)
            return
        }
        widths[column] = calculateColumnWidth(column)
        excelView.reloadColumnWidth(column, reason: row)
    }
}

extension ListExcelView {
    func commitReload(_ batch: Batch, configurationBaseline: Configuration) {
        let widthMetricsChanged = !batch.configuration.hasSameWidthMetrics(as: configurationBaseline)
        let heightMetricsChanged =
            batch.configuration.resolvedRowHeight != configurationBaseline.resolvedRowHeight
        let headersAssigned = batch.headers != nil
        let rowsAssigned = batch.rowDatas != nil

        if batch.isLoading == true {
            isLoading = true
        }

        // 恒写 configuration（含不影响列宽的文案/颜色等）
        configuration = batch.configuration

        let dropAllWidthCache = widthMetricsChanged || headersAssigned
        let useRowsDiff = !widthMetricsChanged && !headersAssigned && rowsAssigned

        if let headers = batch.headers {
            applyHeaders(headers)
        }

        // 恒写排序（在 headers 投影之后，便于同批 headers + sortColumn）
        sortColumn = batch.sortColumn

        // 锁列 clamp + 推引擎配置（依赖最新可见列数）
        syncListChrome()

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
            // 行高 / 放大切换：图列 preferred 随 `resolvedRowHeight` 变，不清文字测宽缓存
            if heightMetricsChanged {
                recomputeWidthsFromRowContributions()
            }
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
            if isLoading {
                isLoading = false
            } else {
                pendingUIRefresh = .none
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
    /// 是否与另一配置在「影响文字测宽 / fingerprint」的字段上一致。
    /// 行高 / `enlargeImageRows` 等不在此列：变更时走轻量 `recompute`（图列 preferred），不清 `contentWidthCache`。
    func hasSameWidthMetrics(as other: Self) -> Bool {
        excel.hasSameWidthMetrics(as: other.excel)
    }
}
