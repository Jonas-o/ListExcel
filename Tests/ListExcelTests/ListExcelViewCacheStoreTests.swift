//
//  ListExcelViewCacheStoreTests.swift
//  ListExcelTests
//

import XCTest
@testable import ListExcel

@MainActor
final class ListExcelViewCacheStoreTests: XCTestCase {
    func testReloadWithoutStoreKeepsExplicitSort() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }
        let sort = Excel.SortColumn(header: TestHeader.name, type: .ascending)

        list.reload { $0.sortColumn = sort }

        XCTAssertEqual(list.sortColumn?.header, .name)
        XCTAssertEqual(list.sortColumn?.type, .ascending)
    }

    func testReadsCacheFillsUnassignedFieldsAndClampsLocks() {
        let (list, _, window) = TestListFactory.makeList(headers: [.name, .value, .select])
        defer { window.isHidden = true }
        let store = TestCacheStore(
            headers: [.value, .name],
            leadingLockCount: 9,
            trailingLockCount: 9,
            sortColumn: Excel.SortColumn(header: .name, type: .ascending),
            showsSortHint: false,
            supportsEnlargeImageRows: true,
            enlargeImageRows: true
        )
        list.cacheStore = store

        list.reload { $0.rowDatas = [TestIdentifiedRow(identifier: "1", name: "A", value: "1")] }

        XCTAssertEqual(list.headers, [.value, .name])
        XCTAssertEqual(list.sortColumn?.header, .name)
        XCTAssertEqual(list.sortColumn?.type, .ascending)
        XCTAssertEqual(list.configuration.excel.leadingLockCount, 2)
        XCTAssertEqual(list.configuration.excel.trailingLockCount, 0)
        XCTAssertFalse(list.configuration.showsSortHint)
        XCTAssertTrue(list.configuration.supportsEnlargeImageRows)
        XCTAssertTrue(list.configuration.enlargeImageRows)
        XCTAssertNil(store.savedSort)
    }

    func testReadsCacheFalseIgnoresStore() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }
        let store = TestCacheStore(headers: [.select], leadingLockCount: 0, sortColumn: Excel.SortColumn(header: .name, type: .descending))
        list.cacheStore = store

        list.reload(readsCache: false) { $0.rowDatas = [TestIdentifiedRow(identifier: "1", name: "A", value: "1")] }

        XCTAssertEqual(list.headers, [.name, .value])
        XCTAssertNil(list.sortColumn)
    }

    func testClosureOverridesStoreIncludingSameSort() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }
        let current = Excel.SortColumn(header: TestHeader.name, type: .descending)
        list.reload { $0.sortColumn = current }
        let store = TestCacheStore(
            headers: [.value],
            leadingLockCount: 0,
            sortColumn: Excel.SortColumn(header: .name, type: .ascending),
            showsSortHint: false
        )
        list.cacheStore = store

        list.reload {
            $0.headers = [.name]
            $0.sortColumn = current
            $0.configuration.excel.leadingLockCount = 0
        }

        XCTAssertEqual(list.headers, [.name])
        XCTAssertEqual(list.sortColumn?.type, .descending)
        XCTAssertEqual(list.configuration.excel.leadingLockCount, 0)
        XCTAssertFalse(list.configuration.showsSortHint)
    }

    func testExplicitNilSortBeatsStore() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }
        let store = TestCacheStore(sortColumn: Excel.SortColumn(header: .name, type: .ascending))
        list.cacheStore = store

        list.reload { $0.sortColumn = nil }

        XCTAssertNil(list.sortColumn)
    }

    func testNextReloadRestoresStoreLockAfterOneShotOverride() {
        let (list, _, window) = TestListFactory.makeList(headers: [.name, .value, .select])
        defer { window.isHidden = true }
        let store = TestCacheStore(headers: [.name, .value, .select], leadingLockCount: 2)
        list.cacheStore = store
        list.reload { _ in }
        XCTAssertEqual(list.configuration.excel.leadingLockCount, 2)

        list.reload { $0.configuration.excel.leadingLockCount = 0 }
        XCTAssertEqual(list.configuration.excel.leadingLockCount, 0)

        list.reload { $0.rowDatas = [] }
        XCTAssertEqual(list.configuration.excel.leadingLockCount, 2)
    }

    func testInvalidStoreSortIsClearedInMemoryButNotSaved() {
        let host = PermissionHost()
        let list = ListExcelView<PermissionProbeHeader>(frame: .init(0, 0, 375, 667))
        list.delegate = host
        let window = UIWindow(frame: .init(0, 0, 375, 667))
        window.rootViewController = UIViewController()
        window.rootViewController?.view.addSubview(list)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        let hidden = PermissionProbeHeader(title: "hidden", sortBy: "gone", hasPermission: false)
        let store = PermissionCacheStore(
            headers: [hidden],
            sortColumn: Excel.SortColumn(header: hidden, type: .ascending)
        )
        list.cacheStore = store

        list.reload { _ in }

        XCTAssertTrue(list.headers.isEmpty)
        XCTAssertNil(list.sortColumn)
        XCTAssertNil(store.savedSort)
        XCTAssertEqual(store.sortColumn?.header.sortBy, "gone")
    }

    func testValidatedSortColumnDoesNotMutateList() {
        let host = PermissionHost()
        let list = ListExcelView<PermissionProbeHeader>(frame: .init(0, 0, 375, 667))
        list.delegate = host
        list.reload { $0.headers = [PermissionProbeHeader(title: "on-screen", sortBy: "screen")] }
        let beforeHeaders = list.headers
        let visible = PermissionProbeHeader(title: "ok", sortBy: "k")
        let hidden = PermissionProbeHeader(title: "no", sortBy: "no", hasPermission: false)
        let hiddenStore = PermissionCacheStore(
            headers: [hidden, visible],
            sortColumn: Excel.SortColumn(header: hidden, type: .descending)
        )
        list.cacheStore = hiddenStore

        XCTAssertNil(list.validatedSortColumn())
        XCTAssertEqual(list.headers, beforeHeaders)
        XCTAssertNil(list.sortColumn)

        let visibleStore = PermissionCacheStore(
            headers: [visible],
            sortColumn: Excel.SortColumn(header: visible, type: .ascending)
        )
        list.cacheStore = visibleStore
        let validated = list.validatedSortColumn()
        XCTAssertEqual(validated?.header, visible)
        XCTAssertEqual(validated?.type, .ascending)
        XCTAssertEqual(list.headers, beforeHeaders)
    }

    func testSortAndClearSaveToStore() {
        let (list, host, window) = TestListFactory.makeList()
        defer { window.isHidden = true }
        let store = TestCacheStore()
        list.cacheStore = store
        list.reload { $0.rowDatas = [TestIdentifiedRow(identifier: "1", name: "A", value: "1")] }

        list.excel(list.excelView, didSelectHeaderAt: 0)
        XCTAssertEqual(store.savedSort??.header, .name)
        XCTAssertEqual(host.lastSortColumn?.header, .name)

        list.clearSorts()
        XCTAssertNotNil(store.savedSort)
        XCTAssertNil(store.savedSort?.flatMap { $0 })
        XCTAssertNil(list.sortColumn)
    }

    func testEnlargeToggleSavesWithoutReplacingHeaders() {
        let (list, _, window) = TestListFactory.makeList(headers: [.name, .photo])
        defer { window.isHidden = true }
        list.reload {
            $0.configuration.supportsEnlargeImageRows = true
            $0.rowDatas = [TestIdentifiedRow(identifier: "1", name: "A", value: "1")]
        }
        let store = TestCacheStore(headers: [.select], supportsEnlargeImageRows: true, enlargeImageRows: false)
        list.cacheStore = store

        list.excel(list.excelView, didSelectHeaderAt: 1)

        XCTAssertTrue(list.configuration.enlargeImageRows)
        XCTAssertEqual(store.savedEnlarge, true)
        XCTAssertEqual(list.headers, [.name, .photo])
    }

    func testMutateConfigurationDoesNotReadStore() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }
        let store = TestCacheStore(headers: [.select], sortColumn: Excel.SortColumn(header: .name, type: .ascending))
        list.cacheStore = store

        list.mutateConfiguration { $0.excel.selectionType = .cell() }

        XCTAssertEqual(list.headers, [.name, .value])
        XCTAssertNil(list.sortColumn)
        XCTAssertTrue(list.configuration.excel.selectionType.isCell)
    }

    func testHeaderLongPressBeganNotifiesDelegate() {
        let (list, host, window) = TestListFactory.makeList()
        defer { window.isHidden = true }
        let began = StubLongPress()
        began.stubState = .began
        list.handleHeaderLongPress(began)
        XCTAssertEqual(host.longPressCount, 1)

        let changed = StubLongPress()
        changed.stubState = .changed
        list.handleHeaderLongPress(changed)
        XCTAssertEqual(host.longPressCount, 1)
    }
}

private final class TestCacheStore: ListExcelCacheStore {
    typealias Header = TestHeader

    var headers: [TestHeader]
    var leadingLockCount: Int
    var trailingLockCount: Int
    var sortColumn: Excel.SortColumn<TestHeader>?
    var showsSortHint: Bool
    var supportsEnlargeImageRows: Bool
    var enlargeImageRows: Bool
    var savedSort: Excel.SortColumn<TestHeader>??
    var savedEnlarge: Bool?

    init(
        headers: [TestHeader] = [.name, .value],
        leadingLockCount: Int = 1,
        trailingLockCount: Int = 0,
        sortColumn: Excel.SortColumn<TestHeader>? = nil,
        showsSortHint: Bool = true,
        supportsEnlargeImageRows: Bool = false,
        enlargeImageRows: Bool = false
    ) {
        self.headers = headers
        self.leadingLockCount = leadingLockCount
        self.trailingLockCount = trailingLockCount
        self.sortColumn = sortColumn
        self.showsSortHint = showsSortHint
        self.supportsEnlargeImageRows = supportsEnlargeImageRows
        self.enlargeImageRows = enlargeImageRows
    }

    func saveSortColumn(_ column: Excel.SortColumn<TestHeader>?) {
        savedSort = .some(column)
        sortColumn = column
    }

    func saveEnlargeImageRows(_ enlarged: Bool) {
        savedEnlarge = enlarged
        enlargeImageRows = enlarged
    }
}

private final class PermissionHost: NSObject, ListExcelDataSource, ListExcelCellHandling, ListExcelInteractionDelegate {
    typealias T = PermissionProbeHeader
}

private final class PermissionCacheStore: ListExcelCacheStore {
    typealias Header = PermissionProbeHeader

    var headers: [PermissionProbeHeader]
    var leadingLockCount = 0
    var trailingLockCount = 0
    var sortColumn: Excel.SortColumn<PermissionProbeHeader>?
    var savedSort: Excel.SortColumn<PermissionProbeHeader>??

    init(headers: [PermissionProbeHeader], sortColumn: Excel.SortColumn<PermissionProbeHeader>?) {
        self.headers = headers
        self.sortColumn = sortColumn
    }

    func saveSortColumn(_ column: Excel.SortColumn<PermissionProbeHeader>?) {
        savedSort = .some(column)
        sortColumn = column
    }
}

private final class StubLongPress: UILongPressGestureRecognizer {
    var stubState: UIGestureRecognizer.State = .possible
    override var state: UIGestureRecognizer.State {
        get { stubState }
        set { stubState = newValue }
    }
}
