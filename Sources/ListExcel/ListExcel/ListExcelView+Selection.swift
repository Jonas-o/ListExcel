//
//  ListExcelView+Selection.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension ListExcelView {
    /// 清空多选集合。尽量只刷新「选择」列可见格，不重算列宽。
    public func clearSelection() {
        selectRows.removeAll()
        if let column = selectColumnIndex() {
            var matrixs: [Excel.Matrix] = [.init(column: column, row: .header)]
            for cell in tableView.visibleCells {
                guard let indexPath = tableView.indexPath(for: cell) else { continue }
                matrixs.append(.init(column: column, row: .cell(indexPath.row)))
            }
            if footerHeight > 0 {
                matrixs.append(.init(column: column, row: .footer))
            }
            reloadCells(at: matrixs)
        } else {
            reloadData(immediate: true, widthPolicy: .keep)
        }
    }

    /// 是否已选中全部可标识行（`selectRows` 非空且数量 ≥ `rowDatas.count`）。
    public var isAllSelected: Bool {
        !selectRows.isEmpty && selectRows.count >= rowDatas.count
    }

    /// 指定行模型（`Excel.RowSelection`）是否在多选集合中。
    public func isSelected(_ row: Excel.RowSelection) -> Bool {
        selectRows.contains(row.identifier)
    }

    /// 按矩阵行判断选中态：表头表示「全选」；内容行须实现 `Excel.RowSelection`。
    public func isSelected(_ row: Excel.Matrix.Row) -> Bool {
        switch row {
            case .header:
                return isAllSelected
            case let .cell(index) where 0 ..< rowDatas.count ~= index:
                if let model = rowDatas[index] as? Excel.RowSelection {
                    return isSelected(model)
                }
            default: break
        }
        return false
    }

    /// 将一行加入多选集合（按 `identifier`）。不自动刷新 Cell，请随后 `reloadCell` / 依赖内部点击路径。
    public func select(_ row: Excel.RowSelection) {
        selectRows.update(with: row.identifier)
    }

    /// 按矩阵行选中：表头选中全部可标识行；内容行须实现 `Excel.RowSelection`。
    public func select(_ row: Excel.Matrix.Row) {
        switch row {
            case .header:
                let identifiers = rowDatas.compactMap { ($0 as? Excel.RowSelection)?.identifier }
                selectRows = Set(identifiers)
            case let .cell(index) where 0 ..< rowDatas.count ~= index:
                if let model = rowDatas[index] as? Excel.RowSelection {
                    select(model)
                }
            default: break
        }
    }

    /// 从多选集合移除一行。
    public func deselect(_ row: Excel.RowSelection) {
        selectRows.remove(row.identifier)
    }

    /// 按矩阵行取消选中：表头清空全部；内容行须实现 `Excel.RowSelection`。
    public func deselect(_ row: Excel.Matrix.Row) {
        switch row {
            case .header:
                selectRows.removeAll()
            case let .cell(index) where 0 ..< rowDatas.count ~= index:
                if let model = rowDatas[index] as? Excel.RowSelection {
                    deselect(model)
                }
            default: break
        }
    }
}
