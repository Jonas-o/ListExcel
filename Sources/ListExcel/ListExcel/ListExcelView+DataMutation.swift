//
//  ListExcelView+DataMutation.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension ListExcelView {
    /// 尾部追加；只测新行（并按需重测 footer）。换列 / 整表替换 / 改单行请用 `reload`。
    public func append(_ rows: [any Excel.RowModel]) {
        guard !rows.isEmpty else { return }
        let oldCount = rowDatas.count
        rowDatas += rows
        rebuildModelIdCounts()
        demoteConflictingModelIdsFromDictionary()
        // 因同 id 冲突从字典降级的旧行，补进 orphan
        for index in 0 ..< oldCount {
            let model = rowDatas[index]
            if uniqueRowWidthKey(for: model) == nil {
                _ = measureRow(model, index: index)
            }
        }

        for (offset, row) in rows.enumerated() {
            _ = measureRow(row, index: oldCount + offset)
        }
        if footerHeight > 0 {
            measureFooterWidths()
        }
        recomputeWidthsFromRowContributions()
        performUIRefreshAfterAppend(from: oldCount)
    }

    /// `append` 专用 UI：可 `insertRows`；`isLoading` 时记待对齐。
    func performUIRefreshAfterAppend(from: Int) {
        guard !isLoading else {
            pendingUIRefresh = .fullReconcile
            return
        }
        pendingUIRefresh = .none
        let indexPaths = (from ..< rowDatas.count).map { IndexPath(row: $0, section: 0) }
        excelView.insertRows(at: indexPaths, with: .none)
        if footerHeight > 0 {
            reloadFooter()
        }
        refreshSelectHeaderIfNeeded()
    }

    func performResetStyleUIRefresh() {
        reloadData(immediate: true, widthPolicy: .keep)
    }

    func pruneSelectRows(to rows: [any Excel.RowModel]) {
        let valid = Set(rows.compactMap { ($0 as? Excel.ModelIdentifier)?.identifier })
        selectRows = selectRows.intersection(valid)
    }

    func applyResetDiff(_ rows: [any Excel.RowModel]) {
        let oldFingerprints = rowContentFingerprints
        let oldContributions = rowColumnWidths
        rowDatas = rows
        rebuildModelIdCounts()

        rowColumnWidths.removeAll()
        orphanRowContributions.removeAll()
        rowContentFingerprints.removeAll()

        for (index, model) in rows.enumerated() {
            guard let key = uniqueRowWidthKey(for: model) else {
                _ = measureRow(model, index: index)
                continue
            }
            let fingerprints = rowFingerprint(for: model, index: index)
            if let old = oldFingerprints[key],
               old == fingerprints,
               let contrib = oldContributions[key] {
                rowColumnWidths[key] = contrib
                rowContentFingerprints[key] = fingerprints
                orphanRowContributions.removeValue(forKey: index)
            } else {
                _ = measureRow(model, index: index)
            }
        }
    }

    private func rowFingerprint(for model: Excel.RowModel, index: Int) -> [ContentWidthKey?] {
        let font = configuration.excel.rowFont
        return headers.indices.map { column in
            contentWidthKey(for: genContent(at: .cell(index), column: column), font: font)
        }
    }

    func demoteConflictingModelIdsFromDictionary() {
        for (id, count) in modelIdCounts where count > 1 {
            let key = RowWidthKey.modelId(id)
            rowColumnWidths.removeValue(forKey: key)
            rowContentFingerprints.removeValue(forKey: key)
        }
    }

    private func refreshSelectHeaderIfNeeded() {
        guard let column = selectColumnIndex() else { return }
        excelView.reloadCell(at: Excel.Matrix(column: column, row: .header))
    }

    func selectColumnIndex() -> Int? {
        headers.enumerated().first {
            if case .select = headerContent(at: $0.element, column: $0.offset) {
                return true
            }
            return false
        }?.offset
    }
}
