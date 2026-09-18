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
        ///
        /// 闭包里**赋过值**（含写成与当前相同、或写成 `nil`）后，同次 `readsCache` 不再用 ``ListExcelCacheStore`` 覆盖。
        /// `Batch` 初始化时的预填**不**算赋值。
        public var sortColumn: Excel.SortColumn<T>? {
            didSet { sortColumnAssigned = true }
        }
        /// 闭包是否给 `sortColumn` 赋过值（供 `readsCache` 合并用；对外无需关心）。
        var sortColumnAssigned = false
        /// 有值才写入表头；`nil` 表示本次不改。`readsCache` 且未赋值时改用 ``ListExcelCacheStore/headers``。
        public var headers: [T]?
        /// 有值才写入内容行；`nil` 表示本次不改。
        public var rowDatas: [any Excel.RowModel]?
        /// 有值才写入总条数；`nil` 表示本次不改。
        public var total: Int?
        /// 有值才写入页码；`nil` 表示本次不改。
        public var page: Int?
        /// `true`：提交开头置 loading；`false`：提交末尾关 loading；`nil`：不碰。
        public var isLoading: Bool?
        /// `true` 清空选中；`false` 若写了 `rowDatas` 则按 id 裁剪保留。
        public var clearsSelection: Bool

        public init(configuration: Configuration, sortColumn: Excel.SortColumn<T>? = nil, clearsSelection: Bool = false) {
            self.configuration = configuration
            self.sortColumn = sortColumn
            self.clearsSelection = clearsSelection
        }

        /// 只填这次闭包没写过的字段。调用方保证已经决定要读 store。
        mutating func fillUnassignedFields(from store: any ListExcelCacheStore<T>, baseline: Configuration) {
            if headers == nil {
                headers = store.headers
            }
            if !sortColumnAssigned {
                sortColumn = store.sortColumn
            }
            if configuration.excel.leadingLockCount == baseline.excel.leadingLockCount {
                configuration.excel.leadingLockCount = store.leadingLockCount
            }
            if configuration.excel.trailingLockCount == baseline.excel.trailingLockCount {
                configuration.excel.trailingLockCount = store.trailingLockCount
            }
            if configuration.showsSortHint == baseline.showsSortHint {
                configuration.showsSortHint = store.showsSortHint
            }
            if configuration.supportsEnlargeImageRows == baseline.supportsEnlargeImageRows {
                configuration.supportsEnlargeImageRows = store.supportsEnlargeImageRows
            }
            if configuration.enlargeImageRows == baseline.enlargeImageRows {
                configuration.enlargeImageRows = store.enlargeImageRows
            }
        }
    }

    /// 批改可编辑态：按赋值情况选择列宽缓存策略，并尽量只对齐一次 UI。
    ///
    /// - Parameters:
    ///   - readsCache: 为 `true` 且已设置 ``cacheStore`` 时，闭包**未写**的表头、排序、左右锁列，
    ///     以及 `showsSortHint` / `supportsEnlargeImageRows` / `enlargeImageRows` 用 store 填充；
    ///     闭包写过的字段优先。为 `false` 或未挂 store 时不读缓存。默认 `true`，故 `reload { }` 与旧写法兼容。
    ///   - update: 修改 ``Batch``。`configuration` / `sortColumn` 预填当前值且提交时恒写回；
    ///     `headers` / `rowDatas` / `total` / `page` / `isLoading` 仅赋值时才写入。
    ///
    /// - Note: `isLoading == true` 时表格刷新推迟到恢复为 `false`；`== false` 在提交末尾写入；`nil` 不碰。
    ///   合并时不会调用 store 的 `save*`。投影导致内存排序清空时也不会写回 store。
    public func reload(readsCache: Bool = true, _ update: (inout Batch) -> Void) {
        let configurationBaseline = configuration
        var batch = Batch(configuration: configurationBaseline, sortColumn: sortColumn)
        update(&batch)
        if readsCache, let cacheStore {
            batch.fillUnassignedFields(from: cacheStore, baseline: configurationBaseline)
        }
        commitReload(batch, configurationBaseline: configurationBaseline)
    }

    /// 在当前配置上批改字段；内部走 ``reload(readsCache: false)``，避免只改配置时把表头 / 排序从 store 再拉一遍。
    /// 测宽相关字段未变时不整表重测。
    public func mutateConfiguration(_ update: (inout Configuration) -> Void) {
        reload(readsCache: false) { batch in
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

    /// 整表刷新并强制重测列宽（立刻执行）。`isLoading == true` 时只记待对齐，恢复后再刷。
    public func reloadData() {
        reloadData(immediate: true, widthPolicy: .recalculate)
    }

    /// 内部刷新入口：可指定防抖与 ``ColumnWidthPolicy``（`.recalculate` / `.keep` / `.reconcile`）。
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

    /// 仅刷新表头行内容（不重测列宽）。
    public func reloadHeader() {
        excelView.reloadHeader()
    }

    /// 仅刷新表尾行内容（不重测列宽）。
    public func reloadFooter() {
        excelView.reloadFooter()
    }

    /// 仅刷新指定格内容，不涉及宽度变化。
    public func reloadCell(at matrix: Excel.Matrix) {
        excelView.reloadCell(at: matrix)
    }

    /// 仅刷新多格内容，不涉及宽度变化。
    public func reloadCells(at matrixs: [Excel.Matrix]) {
        excelView.reloadCells(at: matrixs)
    }

    /// 单列重算宽度并同步到引擎。不完整重建行级增量缓存；需严格一致时请 ``reloadData()``。
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
