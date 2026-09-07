//
//  ListExcelViewMutationTests.swift
//  ListExcelTests
//

import XCTest
@testable import ListExcel

final class ListExcelViewMutationTests: XCTestCase {
    private var host: TestListHost!
    private var list: ListExcelView<TestHeader>!
    private var window: UIWindow!

    @MainActor
    override func setUp() {
        super.setUp()
        let pair = TestListFactory.makeList()
        list = pair.0
        host = pair.1
        window = pair.2
    }

    @MainActor
    override func tearDown() {
        window.isHidden = true
        window = nil
        list = nil
        host = nil
        super.tearDown()
    }

    func testSetHeadersMatchesWidthsCount() {
        XCTAssertEqual(list.headers.count, 2)
        XCTAssertEqual(list.widths.count, list.headers.count)
        list.setHeaders([.name, .value, .select])
        XCTAssertEqual(list.widths.count, 3)
        list.setHeaders([.name])
        XCTAssertEqual(list.widths.count, 1)
    }

    func testResetAndAppendRowCounts() {
        list.reset([
            TestIdentifiedRow(identifier: "1", name: "A", value: "1"),
            TestIdentifiedRow(identifier: "2", name: "B", value: "2"),
        ])
        XCTAssertEqual(list.rowDatas.count, 2)

        list.append([
            TestIdentifiedRow(identifier: "3", name: "C", value: "3"),
        ])
        XCTAssertEqual(list.rowDatas.count, 3)
        XCTAssertEqual(list.widths.count, list.headers.count)
    }

    func testAppendEmptyIsNoOp() {
        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])
        list.append([])
        XCTAssertEqual(list.rowDatas.count, 1)
    }

    func testAppendLongValueWidensColumn() {
        list.reset([
            TestIdentifiedRow(identifier: "1", name: "A", value: "1"),
        ])
        let before = list.widths[1]
        list.append([
            TestIdentifiedRow(
                identifier: "2",
                name: "B",
                value: String(repeating: "9", count: 48)
            ),
        ])
        XCTAssertGreaterThan(list.widths[1], before)
    }

    func testResetRemovesWidestRowCanNarrow() {
        list.reset([
            TestIdentifiedRow(identifier: "1", name: "A", value: "1"),
            TestIdentifiedRow(
                identifier: "wide",
                name: "B",
                value: String(repeating: "M", count: 60)
            ),
        ])
        let wide = list.widths[1]
        list.reset([
            TestIdentifiedRow(identifier: "1", name: "A", value: "1"),
        ])
        XCTAssertLessThan(list.widths[1], wide)
    }

    func testUpdateCanNarrowValueColumn() {
        list.reset([
            TestIdentifiedRow(
                identifier: "1",
                name: "A",
                value: String(repeating: "X", count: 50)
            ),
        ])
        let wide = list.widths[1]
        list.update(
            at: 0,
            TestIdentifiedRow(identifier: "1", name: "A", value: "1")
        )
        XCTAssertLessThan(list.widths[1], wide)
    }

    func testUpdateOutOfBoundsIsNoOp() {
        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])
        list.update(at: 9, TestIdentifiedRow(identifier: "x", name: "Z", value: "9"))
        XCTAssertEqual(list.rowDatas.count, 1)
        XCTAssertEqual((list.rowDatas[0] as? TestIdentifiedRow)?.identifier, "1")
    }

    func testReplaceUpdatesMatchingRow() {
        list.reset([
            TestIdentifiedRow(identifier: "1", name: "A", value: "1"),
            TestIdentifiedRow(identifier: "2", name: "B", value: "2"),
        ])
        let ok = list.replace(TestIdentifiedRow(identifier: "2", name: "BB", value: "22"))
        XCTAssertTrue(ok)
        XCTAssertEqual((list.rowDatas[1] as? TestIdentifiedRow)?.name, "BB")
    }

    func testReplaceMissingReturnsFalse() {
        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])
        let ok = list.replace(TestIdentifiedRow(identifier: "missing", name: "Z", value: "0"))
        XCTAssertFalse(ok)
        XCTAssertEqual(list.rowDatas.count, 1)
    }

    func testDuplicateModelIdStillComputesWidths() {
        list.reset([
            TestIdentifiedRow(identifier: "same", name: "A", value: "1"),
            TestIdentifiedRow(
                identifier: "same",
                name: "B",
                value: String(repeating: "W", count: 40)
            ),
        ])
        XCTAssertEqual(list.rowDatas.count, 2)
        XCTAssertEqual(list.widths.count, 2)
        XCTAssertGreaterThan(list.widths[1], 44)
        // 冲突 id 不进唯一字典
        XCTAssertNil(list.rowColumnWidths[.modelId("same")])
        XCTAssertFalse(list.orphanRowContributions.isEmpty)
    }

    func testLoadingDefersUIButKeepsData() {
        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])
        list.isLoading = true
        list.append([
            TestIdentifiedRow(identifier: "2", name: "B", value: "2"),
            TestIdentifiedRow(identifier: "3", name: "C", value: "3"),
        ])
        XCTAssertEqual(list.rowDatas.count, 3)
        list.isLoading = false
        XCTAssertEqual(list.rowDatas.count, 3)
        XCTAssertEqual(list.widths.count, list.headers.count)
    }

    func testResetPrunesSelectRowsToIntersection() {
        list.setHeaders([.name, .value, .select])
        list.reset([
            TestIdentifiedRow(identifier: "1", name: "A", value: "1"),
            TestIdentifiedRow(identifier: "2", name: "B", value: "2"),
        ])
        list.select(TestIdentifiedRow(identifier: "1", name: "A", value: "1"))
        list.select(TestIdentifiedRow(identifier: "2", name: "B", value: "2"))
        XCTAssertEqual(list.selectRows, Set(["1", "2"]))

        list.reset([
            TestIdentifiedRow(identifier: "2", name: "B2", value: "22"),
            TestIdentifiedRow(identifier: "3", name: "C", value: "3"),
        ])
        XCTAssertEqual(list.selectRows, Set(["2"]))
    }

    func testClearSelectionEmptiesSelectRows() {
        list.setHeaders([.name, .value, .select])
        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])
        list.select(TestIdentifiedRow(identifier: "1", name: "A", value: "1"))
        list.clearSelection()
        XCTAssertTrue(list.selectRows.isEmpty)
    }

    func testPlainAndClassRowsDoNotCrashWidthPipeline() {
        list.reset([
            TestPlainRow(name: "plain", value: "1"),
            TestClassRow(name: "class", value: String(repeating: "Z", count: 30)),
        ])
        XCTAssertEqual(list.rowDatas.count, 2)
        XCTAssertEqual(list.widths.count, 2)
        list.append([TestPlainRow(name: "p2", value: "2")])
        XCTAssertEqual(list.rowDatas.count, 3)
    }

    func testReloadDataDefaultRecalculatesWidthsCount() {
        list.reset([TestIdentifiedRow(identifier: "1", name: "A", value: "1")])
        list.widths = []
        list.reloadData(immediate: true)
        XCTAssertEqual(list.widths.count, list.headers.count)
    }
}
