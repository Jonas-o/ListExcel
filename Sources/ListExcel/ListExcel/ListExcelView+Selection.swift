//
//  ListExcelView+Selection.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension ListExcelView {
    /// 清除选择；尽量只刷新 select 列，不重算列宽。
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

    public var isAllSelected: Bool {
        !selectRows.isEmpty && selectRows.count >= rowDatas.count
    }

    public func isSelected(_ row: Excel.RowSelection) -> Bool {
        selectRows.contains(row.identifier)
    }

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

    public func select(_ row: Excel.RowSelection) {
        selectRows.update(with: row.identifier)
    }

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

    public func deselect(_ row: Excel.RowSelection) {
        selectRows.remove(row.identifier)
    }

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
