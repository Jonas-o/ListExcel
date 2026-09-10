//
//  ListExcelViewInteractionTests.swift
//  ListExcelTests
//

import XCTest
@testable import ListExcel

@MainActor
final class ListExcelViewInteractionTests: XCTestCase {
    func testHeaderSortCyclesDescendingThenAscending() {
        let (list, host, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])
        // name 列可排序；首次点击使用 OrderType.default == .descending
        list.excel(list.excelView, didSelectHeaderAt: 0)
        XCTAssertEqual(list.sortColumn?.column, 0)
        XCTAssertEqual(list.sortColumn?.type, .descending)
        XCTAssertEqual(host.lastSortColumn?.type, .descending)

        list.excel(list.excelView, didSelectHeaderAt: 0)
        XCTAssertEqual(list.sortColumn?.type, .ascending)

        list.excel(list.excelView, didSelectHeaderAt: 0)
        XCTAssertEqual(list.sortColumn?.type, .descending)
    }

    func testNonSortableHeaderForwardsToDelegate() {
        let (list, host, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])
        list.excel(list.excelView, didSelectHeaderAt: 1) // value 无 sortBy
        XCTAssertNil(list.sortColumn)
        XCTAssertEqual(host.didSelectHeaders.count, 1)
        XCTAssertEqual(host.didSelectHeaders.first?.1, 1)
    }

    func testHeaderSelectTogglesAllRows() {
        let (list, host, window) = TestListFactory.makeList(headers: [.name, .value, .select])
        defer { window.isHidden = true }

        list.reset([
            TestIdentifiedRow(identifier: "1", name: "A", value: "1"),
            TestIdentifiedRow(identifier: "2", name: "B", value: "2"),
        ])
        // 表头 select 列由 host.headerContentAt 提供 `.select`
        XCTAssertEqual(list.genContent(at: .header, column: 2)?.targetClassType, .select)

        list.excel(list.excelView, didSelectHeaderAt: 2)
        XCTAssertEqual(list.selectRows, Set(["1", "2"]))
        XCTAssertTrue(list.isAllSelected)

        list.excel(list.excelView, didSelectHeaderAt: 2)
        XCTAssertTrue(list.selectRows.isEmpty)
        XCTAssertTrue(host.didSelectHeaders.isEmpty) // select 列由表头逻辑接管，不转发
    }

    func testRowSelectViaSelectColumnDoesNotForwardDidSelectRow() {
        let (list, host, window) = TestListFactory.makeList(headers: [.name, .value, .select])
        defer { window.isHidden = true }

        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])
        list.excel(list.excelView, didSelectRowAt: .cell(0), column: 2)
        XCTAssertTrue(list.isSelected(TestIdentifiedRow(identifier: "1", name: "A", value: "1")))
        XCTAssertTrue(host.didSelectRows.isEmpty)

        list.excel(list.excelView, didSelectRowAt: .cell(0), column: 2)
        XCTAssertFalse(list.isSelected(TestIdentifiedRow(identifier: "1", name: "A", value: "1")))
    }

    func testRowSelectOnValueColumnForwardsToDelegate() {
        let (list, host, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reload { $0.configuration.excel.selectionType = .cell() }
        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])
        list.excel(list.excelView, didSelectRowAt: .cell(0), column: 1)
        XCTAssertEqual(host.didSelectRows.count, 1)
        XCTAssertEqual(host.didSelectRows.first?.0, 0)
        XCTAssertEqual(host.didSelectRows.first?.1, "1")
    }

    func testFooterSelectForwardsToDelegate() {
        let (list, host, window) = TestListFactory.makeList(footerHeight: 44)
        defer { window.isHidden = true }

        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])
        list.excel(list.excelView, didSelectFooterAt: 0)
        XCTAssertEqual(host.didSelectFooters.count, 1)
        XCTAssertEqual(host.didSelectFooters.first?.0, .name)
    }

    func testRequestNextPageNotifiesDelegate() {
        let (list, host, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.page = 2
        list.requestNextPage()
        XCTAssertEqual(host.requestNextPages, [3])
    }

    func testLeadingAndTrailingLockCountsPropagateToHeaderCell() {
        let (list, _, window) = TestListFactory.makeList(headers: [.name, .value, .select])
        defer { window.isHidden = true }

        list.configuration.excel.leadingLockCount = 1
        list.configuration.excel.trailingLockCount = 1
        list.applyConfiguration()
        list.reset([
            TestIdentifiedRow(identifier: "1", name: "A", value: "1"),
            TestIdentifiedRow(identifier: "2", name: "B", value: "2"),
        ])
        list.layoutIfNeeded()

        guard let headerCell = list.excelView.headerView as? ExcelTableViewCell else {
            return XCTFail("headerView should be ExcelTableViewCell")
        }
        XCTAssertEqual(headerCell.leadingCount, 1)
        XCTAssertEqual(headerCell.trailingCount, 1)
        XCTAssertEqual(headerCell.contentCount, 1)
    }

    func testResetContentOffsetDoesNotCrash() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])
        list.resetContentOffset()
        list.scrollToTop()
        XCTAssertEqual(list.rowDatas.count, 1)
    }

    func testMatrixHelpersRoundTripForVisibleHeader() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])
        list.layoutIfNeeded()

        guard let cell = list.cellForMatrix(at: .init(column: 0, row: .header)) else {
            return XCTFail("expected header cell")
        }
        let matrix = list.matrix(for: cell)
        XCTAssertEqual(matrix?.column, 0)
        XCTAssertEqual(matrix?.row.rawValue, Excel.Matrix.Row.header.rawValue)
    }

    func testReplaceUsesFirstMatchingIdentifier() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reset([
            TestIdentifiedRow(identifier: "dup", name: "A", value: "1"),
            TestIdentifiedRow(identifier: "dup", name: "B", value: "2"),
        ])
        XCTAssertTrue(list.replace(TestIdentifiedRow(identifier: "dup", name: "AA", value: "11")))
        XCTAssertEqual((list.rowDatas[0] as? TestIdentifiedRow)?.name, "AA")
        XCTAssertEqual((list.rowDatas[1] as? TestIdentifiedRow)?.name, "B")
    }

    func testSelectionTypeViaReloadUpdatesConfiguration() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }

        list.reload { $0.configuration.excel.selectionType = .cell() }
        XCTAssertTrue(list.configuration.excel.selectionType.isCell)
        list.reload { $0.configuration.excel.selectionType = .row() }
        XCTAssertTrue(list.configuration.excel.selectionType.isRow)
    }
}
