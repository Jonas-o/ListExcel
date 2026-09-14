//
//  ListExcelViewAdvancedTests.swift
//  ListExcelTests
//

import XCTest
@testable import ListExcel

@MainActor
final class ListExcelViewAdvancedTests: XCTestCase {
    func testSortableHeaderIsWiderThanSameTitleWithoutSort() {
        let (list, _, window) = TestListFactory.makeSortProbeList()
        defer { window.isHidden = true }

        XCTAssertEqual(list.headerColumnWidths.count, 2)
        let sortable = list.headerColumnWidths[0] ?? 0
        let plain = list.headerColumnWidths[1] ?? 0
        XCTAssertEqual(sortable - plain, 28, accuracy: 0.5)
    }

    func testFooterRemeasureOnAppendCanWidenColumn() {
        let (list, host, window) = TestListFactory.makeList(footerHeight: 44)
        defer { window.isHidden = true }

        host.footerByHeader = [.value: "1"]
        list.reload { $0.rowDatas = [TestIdentifiedRow(identifier: "1", name: "A", value: "1")] }
        let before = list.widths[1]

        host.footerByHeader = [.value: String(repeating: "9", count: 50)]
        list.append([TestIdentifiedRow(identifier: "2", name: "B", value: "1")])
        XCTAssertGreaterThan(list.widths[1], before)
        XCTAssertNotNil(list.footerColumnWidths[1])
    }

    func testReloadDataKeepPreservesWidthsWhenCountMatches() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reload { $0.rowDatas = [TestIdentifiedRow(identifier: "1", name: "A", value: "1")] }
        let snapshot = list.widths
        list.reloadData(immediate: true, widthPolicy: .keep)
        XCTAssertEqual(list.widths, snapshot)
    }

    func testReloadDataKeepRecalculatesWhenWidthsCountMismatch() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reload { $0.rowDatas = [TestIdentifiedRow(identifier: "1", name: "A", value: "1")] }
        list.widths = []
        list.reloadData(immediate: true, widthPolicy: .keep)
        XCTAssertEqual(list.widths.count, list.headers.count)
    }

    func testMutateConfigurationInvalidateRebuildsWidthsForLargerFont() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reload { $0.rowDatas = [
            TestIdentifiedRow(
                identifier: "1",
                name: String(repeating: "A", count: 20),
                value: "1"
            ),
        ] }
        let before = list.widths[0]
        list.mutateConfiguration {
            $0.excel.rowFont = .systemFont(ofSize: 28)
            $0.excel.headerFont = .systemFont(ofSize: 28)
        }
        XCTAssertGreaterThan(list.widths[0], before)
    }

    func testAppendIncreasesTableRowCountViaInsertRows() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reload { $0.rowDatas = [
            TestIdentifiedRow(identifier: "1", name: "A", value: "1"),
        ] }
        XCTAssertEqual(list.tableView.numberOfRows(inSection: 0), 1)

        list.append([
            TestIdentifiedRow(identifier: "2", name: "B", value: "2"),
            TestIdentifiedRow(identifier: "3", name: "C", value: "3"),
        ])
        XCTAssertEqual(list.rowDatas.count, 3)
        XCTAssertEqual(list.tableView.numberOfRows(inSection: 0), 3)
    }

    func testAppendWiderContentUpdatesWidthsAndTableRows() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reload { $0.rowDatas = [TestIdentifiedRow(identifier: "1", name: "A", value: "1")] }
        let before = list.widths[1]
        list.append([
            TestIdentifiedRow(
                identifier: "2",
                name: "B",
                value: String(repeating: "8", count: 45)
            ),
        ])
        XCTAssertGreaterThan(list.widths[1], before)
        XCTAssertEqual(list.tableView.numberOfRows(inSection: 0), 2)
    }

    func testSelectDeselectAndAllSelected() {
        let (list, _, window) = TestListFactory.makeList(headers: [.name, .value, .select])
        defer { window.isHidden = true }

        let r1 = TestIdentifiedRow(identifier: "1", name: "A", value: "1")
        let r2 = TestIdentifiedRow(identifier: "2", name: "B", value: "2")
        list.reload { $0.rowDatas = [r1, r2] }

        list.select(r1)
        XCTAssertTrue(list.isSelected(r1))
        XCTAssertFalse(list.isAllSelected)

        list.select(.header)
        XCTAssertTrue(list.isAllSelected)
        XCTAssertEqual(list.selectRows, Set(["1", "2"]))

        list.deselect(r1)
        XCTAssertFalse(list.isSelected(r1))
        XCTAssertFalse(list.isAllSelected)
    }

    func testClearSortsClearsSortColumnAndNotifies() {
        let (list, host, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.sortColumn = .init(header: .name, type: .ascending)
        XCTAssertNotNil(list.sortColumn)
        let before = host.sortCallbackCount
        list.clearSorts()
        XCTAssertNil(list.sortColumn)
        XCTAssertGreaterThan(host.sortCallbackCount, before)
        XCTAssertNil(host.lastSortColumn)
    }

    func testHasPermissionAndCustomFilterProjectHeaders() {
        var configuration = ListExcelView<PermissionProbeHeader>.Configuration()
        configuration.excel.headerHeight = 44
        configuration.excel.footerHeight = 0
        let list = ListExcelView<PermissionProbeHeader>(
            frame: .init(0, 0, 375, 200),
            configuration: configuration,
            customHeadersFilter: { $0.title != "hiddenByFilter" }
        )
        list.reload { $0.headers = [
            .init(title: "ok", sortBy: "ok"),
            .init(title: "denied", sortBy: "denied", hasPermission: false),
            .init(title: "hiddenByFilter", sortBy: "f"),
        ] }
        XCTAssertEqual(list.headers.map(\.title), ["ok"])
    }

    func testSortColumnClearedWhenHeaderNoLongerVisible() {
        var configuration = ListExcelView<PermissionProbeHeader>.Configuration()
        configuration.excel.headerHeight = 44
        configuration.excel.footerHeight = 0
        let list = ListExcelView<PermissionProbeHeader>(frame: .init(0, 0, 375, 200), configuration: configuration)
        let a = PermissionProbeHeader(title: "A", sortBy: "a")
        let b = PermissionProbeHeader(title: "B", sortBy: "b")
        list.reload { $0.headers = [a, b] }
        list.reload { $0.sortColumn = .init(header: a, type: .ascending) }
        XCTAssertNotNil(list.sortColumn)

        list.reload { $0.headers = [b] }
        XCTAssertNil(list.sortColumn)
    }

    func testBatchSortColumnAppliedWithHeaders() {
        var configuration = ListExcelView<PermissionProbeHeader>.Configuration()
        configuration.excel.headerHeight = 44
        configuration.excel.footerHeight = 0
        let list = ListExcelView<PermissionProbeHeader>(frame: .init(0, 0, 375, 200), configuration: configuration)
        let a = PermissionProbeHeader(title: "A", sortBy: "a")
        let b = PermissionProbeHeader(title: "B", sortBy: "b")
        list.reload {
            $0.headers = [a, b]
            $0.sortColumn = .init(header: b, type: .descending)
        }
        XCTAssertEqual(list.sortColumn?.header.sortBy, "b")
        XCTAssertEqual(list.sortColumn?.type, .descending)
    }

    func testLockCountsClampedToVisibleColumnCount() {
        let (list, _, window) = TestListFactory.makeList(headers: [.name])
        defer { window.isHidden = true }

        list.mutateConfiguration {
            $0.excel.leadingLockCount = 5
            $0.excel.trailingLockCount = 5
        }
        XCTAssertEqual(list.configuration.excel.leadingLockCount, 1)
        XCTAssertEqual(list.configuration.excel.trailingLockCount, 0)
    }

    func testSortColumnDidSetRejectsMissingSortBy() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reload { $0.rowDatas = [TestIdentifiedRow(identifier: "1", name: "A", value: "1")] }
        // value 列 sortBy 为空，不能作为排序身份
        list.sortColumn = .init(header: .value, type: .ascending)
        XCTAssertNil(list.sortColumn)
    }

    func testUpdateRemovesOldSelectionId() {
        let (list, _, window) = TestListFactory.makeList(headers: [.name, .value, .select])
        defer { window.isHidden = true }

        list.reload { $0.rowDatas = [TestIdentifiedRow(identifier: "1", name: "A", value: "1")] }
        list.select(TestIdentifiedRow(identifier: "1", name: "A", value: "1"))
        var rows = list.rowDatas
        rows[0] = TestIdentifiedRow(identifier: "9", name: "Z", value: "9")
        list.reload { $0.rowDatas = rows }
        XCTAssertFalse(list.selectRows.contains("1"))
    }

    func testResetKeptFingerprintReusesRowContribution() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        let row = TestIdentifiedRow(identifier: "1", name: "Same", value: "10")
        list.reload { $0.rowDatas = [row] }
        let key = ListExcelView<TestHeader>.RowWidthKey.modelId("1")
        let before = list.rowColumnWidths[key]
        XCTAssertNotNil(before)

        list.reload { $0.rowDatas = [TestIdentifiedRow(identifier: "1", name: "Same", value: "10")] }
        XCTAssertEqual(list.rowColumnWidths[key]?[0], before?[0])
        XCTAssertEqual(list.rowColumnWidths[key]?[1], before?[1])
    }
}
