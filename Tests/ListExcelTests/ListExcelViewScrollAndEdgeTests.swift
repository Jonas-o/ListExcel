//
//  ListExcelViewScrollAndEdgeTests.swift
//  ListExcelTests
//

import XCTest
@testable import ListExcel

@MainActor
final class ListExcelViewScrollAndEdgeTests: XCTestCase {
    func testHorizontalOffsetSyncsAcrossHeaderAndBodyRows() {
        let (list, _, window) = TestListFactory.makeList(headers: [.name, .value, .select])
        defer { window.isHidden = true }

        list.configuration.excel.leadingLockCount = 1
        list.configuration.excel.trailingLockCount = 0
        list.applyConfiguration()
        list.reset([
            TestIdentifiedRow(identifier: "1", name: "A", value: "1"),
            TestIdentifiedRow(identifier: "2", name: "B", value: "2"),
        ])
        // 强制中间区可横滑（自动算宽在部分机型上可能刚好撑满视口）
        list.widths = [60, 420, 44]
        list.reloadData(immediate: true, widthPolicy: .keep)
        list.layoutIfNeeded()

        guard
            let header = list.excelView.headerView as? ExcelTableViewCell,
            let body = list.tableView.visibleCells.first as? ExcelTableViewCell
        else {
            return XCTFail("expected header/body ExcelTableViewCell")
        }

        XCTAssertEqual(header.leadingCount, 1)
        let maxOffset = header.contentCollectionView.contentSize.width - header.contentCollectionView.bounds.width
        XCTAssertGreaterThan(maxOffset, 40, "content area should be horizontally scrollable")

        let targetX: CGFloat = 36
        header.contentCollectionView.setContentOffset(.init(targetX, 0), animated: false)
        header.scrollViewDidScroll(header.contentCollectionView)

        XCTAssertEqual(body.contentCollectionView.contentOffset.x, targetX, accuracy: 1)
    }

    func testListResetContentOffsetClearsSharedHorizontalOffset() {
        let (list, _, window) = TestListFactory.makeList(headers: [.name, .value, .select])
        defer { window.isHidden = true }

        list.configuration.excel.leadingLockCount = 1
        list.configuration.excel.trailingLockCount = 0
        list.applyConfiguration()
        list.reset([
            TestIdentifiedRow(identifier: "1", name: "A", value: "1"),
            TestIdentifiedRow(identifier: "2", name: "B", value: "2"),
        ])
        list.widths = [60, 420, 44]
        list.reloadData(immediate: true, widthPolicy: .keep)
        list.layoutIfNeeded()

        guard
            let header = list.excelView.headerView as? ExcelTableViewCell,
            let body = list.tableView.visibleCells.first as? ExcelTableViewCell
        else {
            return XCTFail("expected header/body ExcelTableViewCell")
        }

        let maxOffset = header.contentCollectionView.contentSize.width - header.contentCollectionView.bounds.width
        XCTAssertGreaterThan(maxOffset, 40, "content area should be horizontally scrollable")

        let targetX: CGFloat = 36
        header.contentCollectionView.setContentOffset(.init(targetX, 0), animated: false)
        header.scrollViewDidScroll(header.contentCollectionView)
        XCTAssertEqual(body.contentCollectionView.contentOffset.x, targetX, accuracy: 1)

        // 仅调公开 API，不应再依赖宿主手动推可见行
        list.resetContentOffset()
        XCTAssertEqual(header.contentCollectionView.contentOffset.x, 0, accuracy: 0.5)
        XCTAssertEqual(body.contentCollectionView.contentOffset.x, 0, accuracy: 0.5)
    }

    func testScrollNearBottomTriggersRequestNextWhenPanningUp() {
        let (list, host, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.total = 50
        list.page = 0
        list.canLoadMore = true
        list.isLoading = false
        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])
        list.layoutIfNeeded()

        // UIPan 未激活时 translation 不可靠，直接测触底判定
        list.triggerLoadMoreIfNeeded(contentOffsetY: 0, viewportHeight: 667, panTranslationY: -12)

        XCTAssertEqual(host.requestNextPages, [1])
        XCTAssertFalse(list.canLoadMore)
    }

    func testScrollDoesNotLoadMoreWhenPanningDown() {
        let (list, host, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.total = 50
        list.canLoadMore = true
        list.isLoading = false
        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])
        list.triggerLoadMoreIfNeeded(contentOffsetY: 0, viewportHeight: 667, panTranslationY: 8)
        XCTAssertTrue(host.requestNextPages.isEmpty)
        XCTAssertTrue(list.canLoadMore)
    }

    func testScrollDoesNotLoadMoreWhenAlreadyLoading() {
        let (list, host, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.total = 50
        list.canLoadMore = true
        list.isLoading = true
        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])
        list.triggerLoadMoreIfNeeded(contentOffsetY: 0, viewportHeight: 667, panTranslationY: -12)
        XCTAssertTrue(host.requestNextPages.isEmpty)
    }

    func testScrollDoesNotLoadMoreWhenDataAlreadyComplete() {
        let (list, host, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.total = 1
        list.canLoadMore = true
        list.isLoading = false
        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])
        list.triggerLoadMoreIfNeeded(contentOffsetY: 0, viewportHeight: 667, panTranslationY: -12)
        XCTAssertTrue(host.requestNextPages.isEmpty)
    }

    func testScrollDoesNotLoadMoreWhenFarFromBottom() {
        let (list, host, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.total = 500
        list.canLoadMore = true
        list.isLoading = false
        list.configuration.loadMoreThreshold = 100
        list.reset(
            (0 ..< 40).map { TestIdentifiedRow(identifier: "\($0)", name: "R\($0)", value: "\($0)") }
        )
        // 内容远高于视口，offset 仍在顶部 → 不应加载
        list.triggerLoadMoreIfNeeded(contentOffsetY: 0, viewportHeight: 200, panTranslationY: -12)
        XCTAssertTrue(host.requestNextPages.isEmpty)
    }

    func testImageHeaderToggleEnlargesRowHeight() {
        let (list, host, window) = TestListFactory.makeList(headers: [.name, .photo])
        defer { window.isHidden = true }

        host.headerOverrides[.photo] = .iconText(.delete, nil)
        list.setHeaders([.name, .photo])
        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])

        let normal = list.configuration.excel.rowHeight
        let enlarged = list.configuration.excel.enlargedRowHeight
        XCTAssertFalse(list.configuration.enlargeImageRows)

        list.excel(list.excelView, didSelectHeaderAt: 1)
        XCTAssertTrue(list.configuration.enlargeImageRows)
        XCTAssertEqual(list.rowHeight, enlarged)

        list.excel(list.excelView, didSelectHeaderAt: 1)
        XCTAssertFalse(list.configuration.enlargeImageRows)
        XCTAssertEqual(list.rowHeight, normal)
    }

    func testExcelReloadRowsKeepsRowCount() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reset([
            TestIdentifiedRow(identifier: "1", name: "A", value: "1"),
            TestIdentifiedRow(identifier: "2", name: "B", value: "2"),
        ])
        list.excelView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
        XCTAssertEqual(list.tableView.numberOfRows(inSection: 0), 2)
    }

    func testReloadCellWidthUpdatesSingleColumn() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])
        let before = list.widths[1]
        // 直接改行数据绕过 update，再单列重算
        if var row = list.rowDatas[0] as? TestIdentifiedRow {
            row.value = String(repeating: "9", count: 55)
            list.rowDatas[0] = row
        }
        list.reloadCellWidth(1)
        XCTAssertGreaterThan(list.widths[1], before)
    }

    func testReconcileWidthPolicyRecomputesFromCache() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reset([
            TestIdentifiedRow(
                identifier: "1",
                name: "A",
                value: String(repeating: "M", count: 40)
            ),
        ])
        let expected = list.widths
        list.widths = [10, 10]
        list.reloadData(immediate: true, widthPolicy: .reconcile)
        XCTAssertEqual(list.widths.count, expected.count)
        XCTAssertEqual(list.widths[1], expected[1], accuracy: 0.5)
    }

    func testImageCellBindDoesNotCrash() {
        let cell = Excel.ImageCell(frame: .init(0, 0, 44, 44))
        cell.bindContent(.image, context: .init())
        cell.layoutIfNeeded()
        XCTAssertEqual(cell.bounds.width, 44)
    }
}
