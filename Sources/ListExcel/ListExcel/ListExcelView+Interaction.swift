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
        } else if case .rowSelection = configuration.excel.selectionType {
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

    // MARK: Scroll

    func handleExcelScrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == tableView else { return }
        let panTranslationY: CGFloat
        if let superview = scrollView.superview {
            panTranslationY = scrollView.panGestureRecognizer.translation(in: superview).y
        } else {
            // 无 superview 时不拦截方向（与历史行为一致：跳过 translation 检查）
            panTranslationY = -1
        }
        triggerLoadMoreIfNeeded(
            contentOffsetY: scrollView.contentOffset.y,
            viewportHeight: scrollView.height,
            panTranslationY: panTranslationY
        )
    }

    /// 触底加载判定（抽出便于单测；UIPan 在未激活态下 translation 常为 0）。
    func triggerLoadMoreIfNeeded(
        contentOffsetY: CGFloat,
        viewportHeight: CGFloat,
        panTranslationY: CGFloat
    ) {
        guard canLoadMore, !isLoading, rowDatas.count < total else { return }
        guard panTranslationY < 0 else { return }
        let tableHeaderViewHeight = tableView.tableHeaderView?.height ?? 0
        let realContentSize = rowHeight * CGFloat(numberOfRows) + headerHeight + tableHeaderViewHeight
        if realContentSize <= contentOffsetY + viewportHeight + configuration.loadMoreThreshold {
            canLoadMore = false
            requestNextPage()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.canLoadMore = true
            }
        }
    }
}
