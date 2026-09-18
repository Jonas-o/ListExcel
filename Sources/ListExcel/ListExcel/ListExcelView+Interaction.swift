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
            if isSortedHeader(header), let current = sortColumn?.type {
                switch current {
                    case .none:
                        type = .default
                    case .ascending:
                        type = .descending
                    case .descending:
                        type = .ascending
                }
            }
            sortColumn = Excel.SortColumn(header: header, type: type)
            cacheStore?.saveSortColumn(sortColumn)
            reloadHeader()
            didSortHeader()
            return
        }
        if content?.targetClassType == .iconText,
           let firstRowContent = genContent(at: .cell(0), column: column),
           firstRowContent.targetClassType == .image {
            // 图片列头点击：切换行高（需 supportsEnlargeImageRows）
            guard configuration.supportsEnlargeImageRows else {
                didSelectHeader(at: header, column: column)
                return
            }
            mutateConfiguration { $0.enlargeImageRows.toggle() }
            cacheStore?.saveEnlargeImageRows(configuration.enlargeImageRows)
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
    func triggerLoadMoreIfNeeded(contentOffsetY: CGFloat, viewportHeight: CGFloat, panTranslationY: CGFloat) {
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

    // MARK: - Sort / Headers visibility

    /// 清除当前排序：内存置空、写回 ``cacheStore``（若有）、刷新表头，并触发 ``ListExcelInteractionDelegate/listExcelView(_:didSortAt:)``（参数为 `nil`）。
    public func clearSorts() {
        sortColumn = nil
        cacheStore?.saveSortColumn(nil)
        reloadHeader()
        didSortHeader()
    }

    func installHeaderLongPress() {
        let target = ListExcelHeaderLongPressTarget { [weak self] gesture in
            self?.handleHeaderLongPress(gesture)
        }
        headerLongPressTarget = target
        let longPress = UILongPressGestureRecognizer(target: target, action: #selector(ListExcelHeaderLongPressTarget.handle(_:)))
        longPress.minimumPressDuration = 0.5
        headerView.addGestureRecognizer(longPress)
    }

    func handleHeaderLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        delegate?.listExcelView(self, didLongPressHeader: gesture)
    }

    /// 得到「按当前缓存表头过滤后仍有效」的排序，供请求参数使用。
    ///
    /// - 已设置 ``cacheStore``：读取 store 的 `headers` / `sortColumn`，经 `hasPermission` 与 `customHeadersFilter` 投影后，
    ///   按 `sortBy` 匹配；命中则返回可见列上的 header + 原 `type`，否则 `nil`。
    /// - 未设置 store：返回当前内存 ``sortColumn``（已与界面可见列对齐）。
    ///
    /// 不修改 `headers` / `rowDatas` / `sortColumn`，不触发 `reload` 或布局。界面上的表头与排序提示仍须另一次 `reload(readsCache:)` 带上。
    public func validatedSortColumn() -> Excel.SortColumn<T>? {
        guard let cacheStore else { return sortColumn }
        let visible = visibleHeaders(from: cacheStore.headers)
        guard let sort = cacheStore.sortColumn else { return nil }
        let key = sort.header.sortBy
        guard !key.isEmpty, let header = visible.first(where: { !$0.sortBy.isEmpty && $0.sortBy == key }) else { return nil }
        return Excel.SortColumn(header: header, type: sort.type)
    }

    /// `hasPermission` + `customHeadersFilter` 投影可见列，并校验当前排序是否仍有效。
    func applyHeaders(_ headers: [T]) {
        self.headers = visibleHeaders(from: headers)
        if let sortColumn, !containsSortColumn(sortColumn) {
            self.sortColumn = nil
        }
    }

    func visibleHeaders(from headers: [T]) -> [T] {
        headers.filter(\.hasPermission).filter(customHeadersFilter)
    }

    /// 当前可见 `headers` 中是否存在与 `sort` 相同 `sortBy` 的可排序列。
    func containsSortColumn(_ sort: Excel.SortColumn<T>) -> Bool {
        columnIndex(forSortColumn: sort) != nil
    }

    /// 用 `header.sortBy` 反查可见列下标；`sortBy` 为空或不存在时返回 `nil`。
    func columnIndex(forSortColumn sort: Excel.SortColumn<T>) -> Int? {
        let key = sort.header.sortBy
        guard !key.isEmpty else { return nil }
        return headers.firstIndex { !$0.sortBy.isEmpty && $0.sortBy == key }
    }

    func isSortedHeader(_ header: T) -> Bool {
        guard let sortColumn else { return false }
        let key = sortColumn.header.sortBy
        guard !key.isEmpty, !header.sortBy.isEmpty else { return false }
        return key == header.sortBy
    }
}
