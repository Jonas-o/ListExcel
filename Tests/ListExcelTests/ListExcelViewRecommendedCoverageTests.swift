//
//  ListExcelViewRecommendedCoverageTests.swift
//  ListExcelTests
//

import XCTest
@testable import ListExcel

@MainActor
final class ListExcelViewRecommendedCoverageTests: XCTestCase {

    // MARK: - 列宽 orphan / id 冲突 / setHeaders

    func testPlainRowsStayInOrphanContributions() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reset([
            TestPlainRow(name: "A", value: String(repeating: "1", count: 30)),
            TestPlainRow(name: "B", value: "2"),
        ])

        XCTAssertTrue(list.rowColumnWidths.isEmpty)
        XCTAssertEqual(list.orphanRowContributions.count, 2)
        XCTAssertGreaterThan(list.widths[1], 40)
    }

    func testDuplicateModelIdDemotesThenUniqueIdReturnsToDictionary() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        let key = ListExcelView<TestHeader>.RowWidthKey.modelId("dup")
        list.reset([
            TestIdentifiedRow(identifier: "dup", name: "A", value: "1"),
        ])
        XCTAssertNotNil(list.rowColumnWidths[key])
        XCTAssertTrue(list.orphanRowContributions.isEmpty)

        list.append([
            TestIdentifiedRow(
                identifier: "dup",
                name: "B",
                value: String(repeating: "W", count: 35)
            ),
        ])
        XCTAssertNil(list.rowColumnWidths[key])
        XCTAssertEqual(list.orphanRowContributions.count, 2)
        XCTAssertGreaterThan(list.widths[1], 40)

        // 1→2→1：只留一行唯一 id，重新进字典
        list.reset([
            TestIdentifiedRow(identifier: "dup", name: "Solo", value: "9"),
        ])
        XCTAssertNotNil(list.rowColumnWidths[key])
        XCTAssertTrue(list.orphanRowContributions.isEmpty)
    }

    func testUpdateChangesModelIdMigratesDictionaryEntry() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reset([
            TestIdentifiedRow(identifier: "old", name: "A", value: String(repeating: "X", count: 20)),
        ])
        let oldKey = ListExcelView<TestHeader>.RowWidthKey.modelId("old")
        let newKey = ListExcelView<TestHeader>.RowWidthKey.modelId("new")
        XCTAssertNotNil(list.rowColumnWidths[oldKey])

        list.update(
            at: 0,
            TestIdentifiedRow(identifier: "new", name: "B", value: String(repeating: "Y", count: 25))
        )
        XCTAssertNil(list.rowColumnWidths[oldKey])
        XCTAssertNotNil(list.rowColumnWidths[newKey])
        XCTAssertEqual(list.rowColumnWidths[newKey]?.keys.sorted(), [0, 1])
    }

    func testSetHeadersInvalidatesCacheAndRebuildsWidths() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reset([
            TestIdentifiedRow(identifier: "1", name: "A", value: String(repeating: "Z", count: 30)),
        ])
        let key = ListExcelView<TestHeader>.RowWidthKey.modelId("1")
        XCTAssertFalse(list.contentWidthCache.isEmpty)
        XCTAssertNotNil(list.rowColumnWidths[key])
        let oldWidths = list.widths

        list.setHeaders([.value, .name, .select])
        XCTAssertEqual(list.headers.count, 3)
        XCTAssertEqual(list.widths.count, 3)
        XCTAssertNotEqual(list.widths, oldWidths)
        // setHeaders 会 invalidate 后全量重建
        XCTAssertNotNil(list.rowColumnWidths[key])
        XCTAssertEqual(list.headerColumnWidths.count, 3)
    }

    // MARK: - Delegate 内容回退

    func testDelegateContentAtUsedWhenHeaderContentNil() {
        let (list, host, window) = TestListFactory.makeExternalList(footerHeight: 0, footerSumTitle: nil)
        defer { window.isHidden = true }
        // host 须强引用：list.delegate 为 weak
        XCTAssertTrue(host === list.delegate)

        list.reset([TestIdentifiedRow(identifier: "1", name: "ignored", value: "ignored")])
        list.layoutIfNeeded()
        XCTAssertEqual(list.widths.count, 2)
        XCTAssertGreaterThan(list.widths[0], 0)
        XCTAssertGreaterThan(list.widths[1], 0)

        guard case let .text(text)? = list.genContent(at: .cell(0), column: 0) else {
            return XCTFail("expected .text from contentAt fallback")
        }
        XCTAssertEqual(text, "r0-c0")
        guard case let .text(text1)? = list.genContent(at: .cell(0), column: 1) else {
            return XCTFail("expected .text for column 1")
        }
        XCTAssertEqual(text1, "r0-c1")
    }

    func testDelegateHeaderContentOverridesTitleFallback() {
        let (list, host, window) = TestListFactory.makeExternalList(footerHeight: 0, footerSumTitle: nil) {
            host, _ in
            host.headerByColumn[0] = .text(String(repeating: "H", count: 40))
        }
        defer { window.isHidden = true }

        list.reset([TestIdentifiedRow(identifier: "1", name: "n", value: "v")])
        let titleOnly = "title".width(font: list.configuration.excel.headerFont)
            + list.configuration.excel.cellPadding.horizontalValue
        XCTAssertGreaterThan(list.widths[0], titleOnly)
    }

    func testFooterSumTitleUsedWhenFooterContentNil() {
        let (list, host, window) = TestListFactory.makeExternalList(
            footerHeight: 44,
            footerSumTitle: .custom(String(repeating: "合", count: 12))
        )
        defer { window.isHidden = true }
        _ = host

        list.reset([TestIdentifiedRow(identifier: "1", name: "n", value: "v")])
        XCTAssertGreaterThan(list.footerColumnWidths[0] ?? 0, 40)
        XCTAssertGreaterThanOrEqual(list.widths[0], list.footerColumnWidths[0] ?? 0)
    }

    // MARK: - 可见 API 冒烟

    func testScrollToColumnAndMatrixDoNotCrash() {
        let (list, _, window) = TestListFactory.makeList(headers: [.name, .value, .select])
        defer { window.isHidden = true }

        list.reset([
            TestIdentifiedRow(identifier: "1", name: "A", value: String(repeating: "V", count: 50)),
            TestIdentifiedRow(identifier: "2", name: "B", value: "2"),
        ])
        list.widths = [60, 400, 44]
        list.reloadData(immediate: true, widthPolicy: .keep)
        list.layoutIfNeeded()

        list.scrollToColumn(at: 1, animated: false)
        list.scrollToMatrix(at: .init(column: 1, row: .cell(1)), animated: false)
        XCTAssertEqual(list.tableView.numberOfRows(inSection: 0), 2)
    }

    func testReloadHeaderAndFooterDoNotCrash() {
        let (list, host, window) = TestListFactory.makeList(footerHeight: 44)
        defer { window.isHidden = true }

        host.footerByHeader[.value] = "100"
        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])
        list.reloadHeader()
        list.reloadFooter()
        XCTAssertFalse(list.footerView.isHidden)
    }

    func testShowNoticeUpdatesLayout() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.total = 3
        list.showNotice = "底部提示"
        list.layoutIfNeeded()
        XCTAssertEqual(list.showNotice, "底部提示")
        XCTAssertFalse(list.totalView.isHidden)

        list.showNotice = nil
        list.layoutIfNeeded()
        XCTAssertNil(list.showNotice)
    }

    func testTotalViewVisibilityAffectsSizeThatFits() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reset([
            TestIdentifiedRow(identifier: "1", name: "A", value: "1"),
            TestIdentifiedRow(identifier: "2", name: "B", value: "2"),
        ])
        list.configuration.showsTotalView = true
        list.applyConfiguration()
        let withTotal = list.sizeThatFits(.init(375, 2000)).height

        list.configuration.showsTotalView = false
        list.applyConfiguration()
        let withoutTotal = list.sizeThatFits(.init(375, 2000)).height

        XCTAssertTrue(list.totalView.isHidden)
        XCTAssertGreaterThan(withTotal, withoutTotal)
        XCTAssertEqual(withTotal - withoutTotal, list.totalView.height, accuracy: 1)
    }

    // MARK: - 选中 / isLoading 推迟刷新

    func testDeselectHeaderClearsAllSelection() {
        let (list, _, window) = TestListFactory.makeList(headers: [.name, .value, .select])
        defer { window.isHidden = true }

        let r1 = TestIdentifiedRow(identifier: "1", name: "A", value: "1")
        let r2 = TestIdentifiedRow(identifier: "2", name: "B", value: "2")
        list.reset([r1, r2])
        list.select(.header)
        XCTAssertTrue(list.isSelected(.header))
        XCTAssertTrue(list.isSelected(.cell(0)))
        XCTAssertTrue(list.isSelected(.cell(1)))

        list.deselect(.header)
        XCTAssertTrue(list.selectRows.isEmpty)
        XCTAssertFalse(list.isSelected(.header))
        XCTAssertFalse(list.isSelected(.cell(0)))
    }

    func testSelectCellMatrixAndIsSelectedRoundTrip() {
        let (list, _, window) = TestListFactory.makeList(headers: [.name, .value, .select])
        defer { window.isHidden = true }

        let r1 = TestIdentifiedRow(identifier: "1", name: "A", value: "1")
        list.reset([r1, TestIdentifiedRow(identifier: "2", name: "B", value: "2")])
        list.select(.cell(0))
        XCTAssertTrue(list.isSelected(r1))
        XCTAssertTrue(list.isSelected(.cell(0)))
        XCTAssertFalse(list.isSelected(.cell(1)))
        XCTAssertFalse(list.isSelected(.header))

        list.deselect(.cell(0))
        XCTAssertFalse(list.isSelected(.cell(0)))
    }

    func testIsLoadingEndReconcilesDeferredTableRows() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])
        list.layoutIfNeeded()
        XCTAssertEqual(list.tableView.numberOfRows(inSection: 0), 1)

        list.isLoading = true
        list.append([
            TestIdentifiedRow(identifier: "2", name: "B", value: "2"),
            TestIdentifiedRow(identifier: "3", name: "C", value: "3"),
        ])
        XCTAssertEqual(list.rowDatas.count, 3)
        XCTAssertEqual(list.pendingUIRefresh, .fullReconcile)
        // 刷新被推迟，表格行数仍可为旧值
        XCTAssertEqual(list.tableView.numberOfRows(inSection: 0), 1)

        list.isLoading = false
        list.layoutIfNeeded()
        XCTAssertEqual(list.pendingUIRefresh, .none)
        XCTAssertEqual(list.tableView.numberOfRows(inSection: 0), 3)
    }

    // MARK: - Excel 宽度不变刷新 + 双锁横滑同步

    func testUpdateSameWidthKeepsWidthsAndRowCount() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reset([
            TestIdentifiedRow(identifier: "1", name: "A", value: "12"),
            TestIdentifiedRow(identifier: "2", name: "B", value: "34"),
        ])
        list.layoutIfNeeded()
        let before = list.widths
        list.update(at: 0, TestIdentifiedRow(identifier: "1", name: "A", value: "99"))
        list.layoutIfNeeded()
        XCTAssertEqual(list.widths.count, before.count)
        XCTAssertEqual(list.tableView.numberOfRows(inSection: 0), 2)
        guard case let .text(value)? = list.genContent(at: .cell(0), column: 1) else {
            return XCTFail("expected updated cell content")
        }
        XCTAssertEqual(value, "99")
    }

    func testLeadingAndTrailingLockHorizontalOffsetSyncs() {
        let (list, _, window) = TestListFactory.makeList(headers: [.name, .value, .select])
        defer { window.isHidden = true }

        list.configuration.excel.leadingLockCount = 1
        list.configuration.excel.trailingLockCount = 1
        list.applyConfiguration()
        list.reset([
            TestIdentifiedRow(identifier: "1", name: "A", value: "1"),
            TestIdentifiedRow(identifier: "2", name: "B", value: "2"),
        ])
        list.widths = [60, 500, 44]
        list.reloadData(immediate: true, widthPolicy: .keep)
        list.layoutIfNeeded()

        guard
            let header = list.excelView.headerView as? ExcelTableViewCell,
            let body = list.tableView.visibleCells.first as? ExcelTableViewCell
        else {
            return XCTFail("expected header/body cells")
        }

        XCTAssertEqual(header.leadingCount, 1)
        XCTAssertEqual(header.trailingCount, 1)
        XCTAssertEqual(header.contentCount, 1)
        let maxOffset = header.contentCollectionView.contentSize.width - header.contentCollectionView.bounds.width
        XCTAssertGreaterThan(maxOffset, 40)

        let targetX: CGFloat = 28
        header.contentCollectionView.setContentOffset(.init(targetX, 0), animated: false)
        header.scrollViewDidScroll(header.contentCollectionView)
        XCTAssertEqual(body.contentCollectionView.contentOffset.x, targetX, accuracy: 1)
    }
}
