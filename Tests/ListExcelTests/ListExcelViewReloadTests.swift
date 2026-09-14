//
//  ListExcelViewReloadTests.swift
//  ListExcelTests
//

import XCTest
@testable import ListExcel

final class ListExcelViewReloadTests: XCTestCase {
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

    // MARK: - selection / chrome-only

    func testReloadSelectionTypeOnlyKeepsWidths() {
        list.reload { $0.rowDatas = [
            TestIdentifiedRow(identifier: "1", name: "A", value: "1"),
            TestIdentifiedRow(identifier: "2", name: "BB", value: "22"),
        ] }
        let before = list.widths

        list.reload { $0.configuration.excel.selectionType = .cell() }

        XCTAssertTrue(list.configuration.excel.selectionType.isCell)
        XCTAssertEqual(list.widths, before)
    }

    func testMutateConfigurationSelectionTypeKeepsWidths() {
        list.reload { $0.rowDatas = [TestIdentifiedRow(identifier: "1", name: "A", value: "1")] }
        let before = list.widths

        list.mutateConfiguration { $0.excel.selectionType = .rowSelection() }

        XCTAssertTrue(list.configuration.excel.selectionType.isRow)
        XCTAssertEqual(list.widths, before)
    }

    func testMutateConfigurationRowFontRemeasuresWidths() {
        list.reload { $0.rowDatas = [
            TestIdentifiedRow(identifier: "1", name: "A", value: String(repeating: "9", count: 24)),
        ] }
        let before = list.widths[1]

        list.mutateConfiguration { $0.excel.rowFont = .boldSystemFont(ofSize: 28) }

        XCTAssertGreaterThan(list.widths[1], before)
    }

    func testHeightOnlyMutationsKeepWidths() {
        list.reload { $0.rowDatas = [
            TestIdentifiedRow(identifier: "1", name: "A", value: String(repeating: "9", count: 24)),
        ] }
        let before = list.widths

        list.mutateConfiguration {
            $0.enlargeImageRows = true
            $0.supportsEnlargeImageRows = true
            $0.enlargedRowHeight = 88
            $0.excel.rowHeight = 60
            $0.excel.headerHeight = 52
            $0.excel.footerHeight = 40
        }

        XCTAssertTrue(list.configuration.enlargeImageRows)
        XCTAssertEqual(list.rowHeight, 88)
        XCTAssertEqual(list.widths, before)
    }

    // MARK: - rows / headers / selection prune

    func testReloadRowsUsesDiffAndPrunesSelection() {
        list.reload { $0.rowDatas = [
            TestIdentifiedRow(identifier: "1", name: "A", value: "1"),
            TestIdentifiedRow(identifier: "2", name: "B", value: "2"),
        ] }
        list.select(TestIdentifiedRow(identifier: "1", name: "A", value: "1"))
        list.select(TestIdentifiedRow(identifier: "2", name: "B", value: "2"))
        XCTAssertEqual(list.selectRows, Set(["1", "2"]))

        list.reload {
            $0.rowDatas = [
                TestIdentifiedRow(identifier: "2", name: "B2", value: "20"),
                TestIdentifiedRow(identifier: "3", name: "C", value: "3"),
            ]
        }

        XCTAssertEqual(list.rowDatas.count, 2)
        XCTAssertEqual(list.selectRows, Set(["2"]))
        XCTAssertEqual((list.rowDatas[0] as? TestIdentifiedRow)?.name, "B2")
    }

    func testReloadRowsClearsSelectionWhenRequested() {
        list.reload { $0.rowDatas = [
            TestIdentifiedRow(identifier: "1", name: "A", value: "1"),
            TestIdentifiedRow(identifier: "2", name: "B", value: "2"),
        ] }
        list.select(TestIdentifiedRow(identifier: "1", name: "A", value: "1"))

        list.reload {
            $0.clearsSelection = true
            $0.rowDatas = [
                TestIdentifiedRow(identifier: "1", name: "A", value: "1"),
            ]
        }

        XCTAssertTrue(list.selectRows.isEmpty)
        XCTAssertEqual(list.rowDatas.count, 1)
    }

    func testReloadHeadersWithoutRowsRemeasuresExistingRows() {
        list.reload { $0.rowDatas = [
            TestIdentifiedRow(identifier: "1", name: "A", value: "1"),
        ] }
        XCTAssertEqual(list.headers.count, 2)

        list.reload { $0.headers = [.name, .value, .select] }

        XCTAssertEqual(list.headers.count, 3)
        XCTAssertEqual(list.widths.count, 3)
        XCTAssertEqual(list.rowDatas.count, 1)
    }

    func testReloadHeadersAndRowsTogether() {
        list.reload {
            $0.headers = [.name, .value, .select]
            $0.rowDatas = [
                TestIdentifiedRow(identifier: "1", name: "A", value: "1"),
            ]
            $0.total = 10
            $0.page = 2
        }

        XCTAssertEqual(list.headers.count, 3)
        XCTAssertEqual(list.rowDatas.count, 1)
        XCTAssertEqual(list.widths.count, 3)
        XCTAssertEqual(list.total, 10)
        XCTAssertEqual(list.page, 2)
    }

    // MARK: - isLoading

    func testReloadDefersUIWhileLoadingThenFlushesOnce() {
        list.reload { $0.rowDatas = [TestIdentifiedRow(identifier: "1", name: "A", value: "1")] }
        list.isLoading = true

        list.reload {
            $0.rowDatas = [
                TestIdentifiedRow(identifier: "1", name: "A", value: "1"),
                TestIdentifiedRow(identifier: "2", name: "B", value: "2"),
            ]
        }

        XCTAssertTrue(list.isLoading)
        XCTAssertEqual(list.pendingUIRefresh, .fullReconcile)
        XCTAssertEqual(list.rowDatas.count, 2)

        list.reload { $0.isLoading = false }

        XCTAssertFalse(list.isLoading)
        XCTAssertEqual(list.pendingUIRefresh, .none)
        XCTAssertEqual(list.rowDatas.count, 2)
    }

    func testReloadSetsLoadingTrueFirst() {
        XCTAssertFalse(list.isLoading)
        list.reload {
            $0.isLoading = true
            $0.rowDatas = [TestIdentifiedRow(identifier: "1", name: "A", value: "1")]
        }
        XCTAssertTrue(list.isLoading)
        XCTAssertEqual(list.pendingUIRefresh, .fullReconcile)
        XCTAssertEqual(list.rowDatas.count, 1)
    }

    // MARK: - reload / mutate / reloadData

    func testReloadWholeConfigurationKeepsWidthsForSelectionOnly() {
        list.reload { $0.rowDatas = [TestIdentifiedRow(identifier: "1", name: "A", value: "1")] }
        let before = list.widths

        var config = list.configuration
        config.excel.selectionType = .cell()
        list.reload { $0.configuration = config }

        XCTAssertTrue(list.configuration.excel.selectionType.isCell)
        XCTAssertEqual(list.widths, before)
    }

    func testReloadDataForcesRecalculate() {
        list.reload { $0.rowDatas = [
            TestIdentifiedRow(identifier: "1", name: "A", value: String(repeating: "9", count: 20)),
        ] }
        XCTAssertEqual(list.widths.count, list.headers.count)

        list.reloadData()

        XCTAssertEqual(list.widths.count, list.headers.count)
        XCTAssertEqual(list.pendingUIRefresh, .none)
    }
}
