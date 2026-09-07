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
        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])
        let before = list.widths[1]

        host.footerByHeader = [.value: String(repeating: "9", count: 50)]
        list.append([TestIdentifiedRow(identifier: "2", name: "B", value: "1")])
        XCTAssertGreaterThan(list.widths[1], before)
        XCTAssertNotNil(list.footerColumnWidths[1])
    }

    func testReloadDataKeepPreservesWidthsWhenCountMatches() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])
        let snapshot = list.widths
        list.reloadData(immediate: true, widthPolicy: .keep)
        XCTAssertEqual(list.widths, snapshot)
    }

    func testReloadDataKeepRecalculatesWhenWidthsCountMismatch() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])
        list.widths = []
        list.reloadData(immediate: true, widthPolicy: .keep)
        XCTAssertEqual(list.widths.count, list.headers.count)
    }

    func testApplyConfigurationInvalidateRebuildsWidthsForLargerFont() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reset([
            TestIdentifiedRow(
                identifier: "1",
                name: String(repeating: "A", count: 20),
                value: "1"
            ),
        ])
        let before = list.widths[0]
        list.configuration.excel.rowFont = .systemFont(ofSize: 28)
        list.configuration.excel.headerFont = .systemFont(ofSize: 28)
        list.applyConfiguration()
        XCTAssertGreaterThan(list.widths[0], before)
    }

    func testAppendIncreasesTableRowCountViaInsertRows() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reset([
            TestIdentifiedRow(identifier: "1", name: "A", value: "1"),
        ])
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

        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])
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
        list.reset([r1, r2])

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

        list.sortColumn = .init(column: 0, header: .name, type: .ascending)
        XCTAssertNotNil(list.sortColumn)
        let before = host.sortCallbackCount
        list.clearSorts()
        XCTAssertNil(list.sortColumn)
        XCTAssertGreaterThan(host.sortCallbackCount, before)
        XCTAssertNil(host.lastSortColumn)
    }

    func testUpdateRemovesOldSelectionId() {
        let (list, _, window) = TestListFactory.makeList(headers: [.name, .value, .select])
        defer { window.isHidden = true }

        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])
        list.select(TestIdentifiedRow(identifier: "1", name: "A", value: "1"))
        list.update(at: 0, TestIdentifiedRow(identifier: "9", name: "Z", value: "9"))
        XCTAssertFalse(list.selectRows.contains("1"))
    }

    func testResetKeptFingerprintReusesRowContribution() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        let row = TestIdentifiedRow(identifier: "1", name: "Same", value: "10")
        list.reset([row])
        let key = ListExcelView<TestHeader>.RowWidthKey.modelId("1")
        let before = list.rowColumnWidths[key]
        XCTAssertNotNil(before)

        list.reset([TestIdentifiedRow(identifier: "1", name: "Same", value: "10")])
        XCTAssertEqual(list.rowColumnWidths[key]?[0], before?[0])
        XCTAssertEqual(list.rowColumnWidths[key]?[1], before?[1])
    }
}
