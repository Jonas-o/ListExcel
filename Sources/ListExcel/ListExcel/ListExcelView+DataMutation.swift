//
//  ListExcelView+DataMutation.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension ListExcelView {
    enum UIRefreshKind {
        case append(from: Int)
        case reset
        case setHeaders
        case update(index: Int)
    }

    /// 替换表头 / 列定义；必定 invalidate 列宽缓存并全量重测。
    public func setHeaders(_ headers: [T]) {
        self.headers = headers
        invalidateWidthCache()
        measureHeaderFooter()
        rebuildAllRowWidthContributions()
        recomputeWidthsFromRowContributions()
        performUIRefresh(after: .setHeaders)
    }

    /// 整表替换；列宽缓存做 diff，不清空字典后盲目全扔。
    public func reset(_ rows: [any Excel.RowModel]) {
        applyResetDiff(rows)
        pruneSelectRows(to: rows)
        measureHeaderFooter()
        recomputeWidthsFromRowContributions()
        performUIRefresh(after: .reset)
    }

    /// 尾部追加；只测新行（并按需重测 footer）。
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
        performUIRefresh(after: .append(from: oldCount))
    }

    /// 按下标替换一行。
    public func update(at index: Int, _ row: any Excel.RowModel) {
        guard 0 ..< rowDatas.count ~= index else { return }
        let oldModel = rowDatas[index]
        let oldKey = rowWidthKey(for: oldModel)
        let oldUnique = uniqueRowWidthKey(for: oldModel)

        if let oldId = (oldModel as? Excel.ModelIdentifier)?.identifier,
           let newId = (row as? Excel.ModelIdentifier)?.identifier,
           oldId != newId {
            selectRows.remove(oldId)
        } else if oldModel is Excel.ModelIdentifier, !(row is Excel.ModelIdentifier),
                  let oldId = (oldModel as? Excel.ModelIdentifier)?.identifier {
            selectRows.remove(oldId)
        }

        rowDatas[index] = row
        rebuildModelIdCounts()

        if let oldUnique {
            rowColumnWidths.removeValue(forKey: oldUnique)
            rowContentFingerprints.removeValue(forKey: oldUnique)
        } else if let oldKey {
            rowColumnWidths.removeValue(forKey: oldKey)
            rowContentFingerprints.removeValue(forKey: oldKey)
        }
        orphanRowContributions.removeValue(forKey: index)

        demoteConflictingModelIdsFromDictionary()
        _ = measureRow(row, index: index)

        if uniqueRowWidthKey(for: row) == nil || needsOrphanRebuildAfterUpdate() {
            rebuildOrphanRowContributions()
        }

        if footerHeight > 0 {
            measureFooterWidths()
        }
        recomputeWidthsFromRowContributions()
        performUIRefresh(after: .update(index: index))
    }

    /// 按业务 id 替换一行（取第一个匹配）。
    @discardableResult
    public func replace(_ row: some Excel.RowModel & Excel.ModelIdentifier) -> Bool {
        guard let index = rowDatas.firstIndex(where: {
            ($0 as? Excel.ModelIdentifier)?.identifier == row.identifier
        }) else {
            return false
        }
        update(at: index, row)
        return true
    }

    func performUIRefresh(after kind: UIRefreshKind) {
        guard !isLoading else {
            pendingUIRefresh = .fullReconcile
            return
        }
        pendingUIRefresh = .none
        switch kind {
            case let .append(from):
                let indexPaths = (from ..< rowDatas.count).map { IndexPath(row: $0, section: 0) }
                excelView.insertRows(at: indexPaths, with: .none)
                if footerHeight > 0 {
                    reloadFooter()
                }
                refreshSelectHeaderIfNeeded()
            case let .update(index):
                excelView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
                if footerHeight > 0 {
                    reloadFooter()
                }
                refreshSelectHeaderIfNeeded()
            case .reset, .setHeaders:
                performResetStyleUIRefresh()
        }
    }

    func performResetStyleUIRefresh() {
        reloadData(immediate: true, widthPolicy: .keep)
    }

    func pruneSelectRows(to rows: [any Excel.RowModel]) {
        let valid = Set(rows.compactMap { ($0 as? Excel.ModelIdentifier)?.identifier })
        selectRows = selectRows.intersection(valid)
    }

    private func applyResetDiff(_ rows: [any Excel.RowModel]) {
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

    private func demoteConflictingModelIdsFromDictionary() {
        for (id, count) in modelIdCounts where count > 1 {
            let key = RowWidthKey.modelId(id)
            rowColumnWidths.removeValue(forKey: key)
            rowContentFingerprints.removeValue(forKey: key)
        }
    }

    private func needsOrphanRebuildAfterUpdate() -> Bool {
        modelIdCounts.values.contains { $0 > 1 }
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
