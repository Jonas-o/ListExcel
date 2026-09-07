//
//  ListExcelView+DataSource.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension ListExcelView {
    func excel(_ excel: Excel, columnWidthAt column: Int) -> CGFloat {
        guard 0 ..< widths.count ~= column else { return 0 }
        return widths[column]
    }

    func excel(_ excel: Excel, dequeueReusableCellAt matrix: Excel.Matrix) -> Excel.Cell.ClassType? {
        let type = genContent(at: matrix.row, column: matrix.column)?.targetClassType
        if case .header = matrix.row, type == .text {
            return .headerText
        }
        return type
    }

    func excel(_ excel: Excel, handle cell: some Excel.Cell, at matrix: Excel.Matrix) {
        guard 0 ..< headers.count ~= matrix.column else { return }
        let header = headers[matrix.column]
        let content = genContent(at: matrix.row, column: matrix.column)
        cell.bindContent(
            content,
            context: .init(
                textAlignment: header.textAlignment,
                isSelected: isSelected(matrix.row)
            )
        )
        switch matrix.row {
            case .header:
                handleHeader(cell: cell, at: header, column: matrix.column)
                if let sortColumn,
                   sortColumn.column == matrix.column,
                   let cell = cell as? Excel.HeaderTextCell {
                    cell.orderType = sortColumn.type
                    if sortColumn.type != .none {
                        cell.textLabel.textAlignment = .left
                    }
                }
            case .footer:
                handleFooter(cell: cell, at: header, column: matrix.column)
            case let .cell(index) where 0 ..< rowDatas.count ~= index:
                let model = rowDatas[index]
                handleRow(cell: cell, union: Excel.CellUnion(row: index, column: matrix.column, header: header, rowModel: model))
            default:
                break
        }
    }

    func excel(_ excel: Excel, backgroundColorAt row: Excel.Matrix.Row) -> UIColor? {
        switch row {
            case .header:
                return headerBackgroundColor() ?? configuration.excel.headerBackgroundColor
            case let .cell(index) where 0 ..< rowDatas.count ~= index:
                let model = rowDatas[index]
                return backgroundColor(at: index, rowModel: model)
            case .footer:
                return footerBackgroundColor()
            default: return nil
        }
    }
}

extension ListExcelView {
    // custom header
    func headerContent(at header: T, column: Int) -> Excel.Content? {
        delegate?.listExcelView(self, headerContentAt: header, column: column)
    }

    // custom row
    func content(at union: Excel.CellUnion<T>) -> Excel.Content? {
        delegate?.listExcelView(self, contentAt: union)
    }

    // custom footer
    func footerContent(at header: T, column: Int) -> Excel.Content? {
        delegate?.listExcelView(self, footerContentAt: header, column: column)
    }

    // custom header backgroundColor
    func headerBackgroundColor() -> UIColor? {
        delegate?.listExcelView(headerBackgroundColor: self)
    }

    // custom row backgroundColor
    func backgroundColor(at row: Int, rowModel: Excel.RowModel) -> UIColor? {
        delegate?.listExcelView(self, backgroundColorAt: row, rowModel: rowModel)
    }

    // custom footer backgroundColor
    func footerBackgroundColor() -> UIColor? {
        delegate?.listExcelView(footerBackgroundColor: self)
    }

    // handle header
    func handleHeader(cell: some Excel.Cell, at header: T, column: Int) {
        delegate?.listExcelView(self, handleHeader: cell, at: header, column: column)
    }

    // handle row
    func handleRow(cell: some Excel.Cell, union: Excel.CellUnion<T>) {
        delegate?.listExcelView(self, handleRow: cell, union: union)
    }

    // handle footer
    func handleFooter(cell: some Excel.Cell, at header: T, column: Int) {
        delegate?.listExcelView(self, handleFooter: cell, at: header, column: column)
    }

    func didSelectRow(at row: Int, rowModel: Excel.RowModel, column: Int?, header: T?) {
        delegate?.listExcelView(self, didSelectRowAt: row, rowModel: rowModel, column: column, header: header)
    }

    func didSelectHeader(at header: T, column: Int) {
        delegate?.listExcelView(self, didSelectHeaderAt: header, column: column)
    }

    func didSortHeader() {
        delegate?.listExcelView(self, didSortAt: sortColumn)
    }

    func didSelectFooter(at header: T, column: Int) {
        delegate?.listExcelView(self, didSelectFooterAt: header, column: column)
    }

    func requestNextPage() {
        delegate?.listExcelView(self, requestNext: page + 1)
    }
}

extension ListExcelView {
    /// 解析单元格内容。优先级：`Header.content(for:)` → Delegate `contentAt` / header/footer 回调 → 默认表头 title / footerSumTitle。
    func genContent(at row: Excel.Matrix.Row, column: Int) -> Excel.Content? {
        guard 0 ..< headers.count ~= column else { return nil }
        let header = headers[column]
        switch row {
            case .header:
                let content = headerContent(at: header, column: column)
                return content ?? .text(header.title)
            case .footer where !rowDatas.isEmpty:
                let content = footerContent(at: header, column: column)
                if content == nil, column == 0, let footerSumTitle = configuration.resolvedFooterSumTitle() {
                    // Footer的第一列显示汇总 title
                    return .text(footerSumTitle)
                }
                return content
            case let .cell(index) where 0 ..< rowDatas.count ~= index:
                let model = rowDatas[index]
                return header.content(for: model, row: row.rawValue) ?? content(at: Excel.CellUnion(row: index, column: column, header: header, rowModel: model))
            default: return nil
        }
    }
}

