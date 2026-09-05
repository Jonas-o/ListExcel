//
//  ListExcelView+Interaction.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension ListExcelView {
    func excel(_ excel: Excel, didSelectRowAt row: Excel.Matrix.Row, column: Int?) {
        var header: T?
        var content: Excel.Content?
        if let column, 0 ..< headers.count ~= column {
            header = headers[column]
            content = genContent(at: row, column: column)
        }
        var selectColumn: Int?
        if case .select = content {
            selectColumn = column
        } else if case .rowSelection = selectionType {
            // 找到第一个是选择类型的列
            let value = headers.enumerated().first {
                if case .select = headerContent(at: $0.element, column: $0.offset) {
                    return true
                }
                return false
            }
            selectColumn = value?.offset
        }
        if let selectColumn {
            // 接管「选择」类型
            if isSelected(row) {
                deselect(row)
            } else {
                select(row)
            }
            excel.reloadCell(at: Excel.Matrix(column: selectColumn, row: row))
            // 刷新表头
            excel.reloadCell(at: Excel.Matrix(column: selectColumn, row: .header))
            return
        }
        let rowIndex = row.rawValue
        if 0 ..< rowDatas.count ~= rowIndex {
            let model = rowDatas[rowIndex]
            didSelectRow(at: rowIndex, rowModel: model, column: column, header: header)
        }
    }

    func excel(_ excel: Excel, didSelectHeaderAt column: Int) {
        guard 0 ..< headers.count ~= column else { return }
        let header = headers[column]
        let content = genContent(at: .header, column: column)
        if !header.sortBy.isEmpty, content?.targetClassType == .text {
            // 接管「排序」逻辑
            var type = Excel.OrderType.default
            if let sortColumn, sortColumn.column == column {
                switch sortColumn.type {
                    case .none:
                        type = .default
                    case .ascending:
                        type = .descending
                    case .descending:
                        type = .ascending
                }
            }
            sortColumn = Excel.SortColumn(column: column, header: header, type: type)
            reloadHeader()
            didSortHeader()
            return
        }
        if content?.targetClassType == .iconText,
           let firstRowContent = genContent(at: .cell(0), column: column),
           firstRowContent.targetClassType == .image {
            // 图片列头点击：切换行高
            configuration.enlargeImageRows.toggle()
            applyConfiguration()
            return
        }
        switch content {
            case .select:
                // 接管「选择」类型
                if isAllSelected {
                    deselect(.header)
                } else {
                    select(.header)
                }
                excel.reloadCell(at: Excel.Matrix(column: column, row: .header))
                (0 ..< rowDatas.count)
                    .map { Excel.Matrix(column: column, row: .cell($0)) }
                    .forEach { excel.reloadCell(at: $0) }
                return
            default:
                didSelectHeader(at: header, column: column)
        }
    }

    func excel(_ excel: Excel, didSelectFooterAt column: Int) {
        guard 0 ..< headers.count ~= column else { return }
        let header = headers[column]
        didSelectFooter(at: header, column: column)
    }

    // MARK: UIScrollViewDelegate

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == tableView, canLoadMore, !isLoading, rowDatas.count < total else { return }
        if let superview = scrollView.superview {
            let point = scrollView.panGestureRecognizer.translation(in: superview)
            if point.y >= 0 {
                return
            }
        }
        let tableHeaderViewHeight = tableView.tableHeaderView?.height ?? 0
        let realContentSize = rowHeight * CGFloat(numberOfRows) + headerHeight + tableHeaderViewHeight
        if realContentSize <= scrollView.contentOffset.y + scrollView.height + configuration.loadMoreThreshold {
            canLoadMore = false
            requestNextPage()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.canLoadMore = true
            }
        }
    }
}
