//
//  TestFixtures.swift
//  ListExcelTests
//

import UIKit
@testable import ListExcel

enum TestHeader: String, CaseIterable, Excel.Header {
    case name
    case value
    case select
    case photo

    var title: String { rawValue }

    var sortBy: String {
        self == .name ? "name" : ""
    }

    func content(for model: Excel.RowModel, row: Int) -> Excel.Content? {
        if self == .photo { return .image }
        if let row = model as? TestIdentifiedRow {
            switch self {
                case .name: return .text(row.name)
                case .value: return .text(row.value)
                case .select: return .select
                case .photo: return .image
            }
        }
        if let row = model as? TestPlainRow {
            switch self {
                case .name: return .text(row.name)
                case .value: return .text(row.value)
                case .select: return .select
                case .photo: return .image
            }
        }
        if let row = model as? TestClassRow {
            switch self {
                case .name: return .text(row.name)
                case .value: return .text(row.value)
                case .select: return .select
                case .photo: return .image
            }
        }
        return nil
    }
}

/// 专门用于排序加宽断言：两列同 title，仅一列带 sortBy。
struct SortProbeHeader: Excel.Header, Equatable {
    let title: String
    let sortKey: String

    var sortBy: String { sortKey }

    func content(for model: Excel.RowModel, row: Int) -> Excel.Content? {
        .text((model as? TestIdentifiedRow)?.name)
    }
}

struct TestIdentifiedRow: Excel.RowModel, Excel.ModelIdentifier {
    var identifier: String
    var name: String
    var value: String
}

struct TestPlainRow: Excel.RowModel {
    var name: String
    var value: String
}

final class TestClassRow: Excel.RowModel {
    var name: String
    var value: String

    init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

final class TestListHost: NSObject, ListExcelDataSource, ListExcelCellHandling, ListExcelInteractionDelegate {
    typealias T = TestHeader

    var footerByHeader: [TestHeader: String] = [:]
    var headerOverrides: [TestHeader: Excel.Content] = [:]
    var lastSortColumn: Excel.SortColumn<TestHeader>?
    var sortCallbackCount = 0
    var selectedRowsEvents: [Set<String>] = []
    var requestNextPages: [Int] = []
    var didSelectHeaders: [(TestHeader, Int)] = []
    var didSelectRows: [(Int, String?)] = []
    var didSelectFooters: [(TestHeader, Int)] = []

    func listExcelView(_ excelView: ListExcelView<TestHeader>, headerContentAt header: TestHeader, column: Int) -> Excel.Content? {
        if let override = headerOverrides[header] { return override }
        return header == .select ? .select : nil
    }

    func listExcelView(_ excelView: ListExcelView<TestHeader>, footerContentAt header: TestHeader, column: Int) -> Excel.Content? {
        footerByHeader[header].map { .text($0) }
    }

    func listExcelView(_ excelView: ListExcelView<TestHeader>, didSortAt column: Excel.SortColumn<TestHeader>?) {
        lastSortColumn = column
        sortCallbackCount += 1
    }

    func listExcelView(_ excelView: ListExcelView<TestHeader>, selectedRowsChanged identifiers: Set<String>) {
        selectedRowsEvents.append(identifiers)
    }

    func listExcelView(_ excelView: ListExcelView<TestHeader>, requestNext page: Int) {
        requestNextPages.append(page)
    }

    func listExcelView(_ excelView: ListExcelView<TestHeader>, didSelectHeaderAt header: TestHeader, column: Int) {
        didSelectHeaders.append((header, column))
    }

    func listExcelView(
        _ excelView: ListExcelView<TestHeader>,
        didSelectRowAt row: Int,
        rowModel: Excel.RowModel,
        column: Int?,
        header: TestHeader?
    ) {
        didSelectRows.append((row, (rowModel as? TestIdentifiedRow)?.identifier))
    }

    func listExcelView(_ excelView: ListExcelView<TestHeader>, didSelectFooterAt header: TestHeader, column: Int) {
        didSelectFooters.append((header, column))
    }
}

final class SortProbeHost: NSObject, ListExcelDataSource, ListExcelCellHandling, ListExcelInteractionDelegate {
    typealias T = SortProbeHeader
}

/// Header.content 恒为 nil，内容全部走 Delegate。
enum ExternalHeader: String, Excel.Header {
    case title
    case amount

    var title: String { rawValue }
    var sortBy: String { "" }

    func content(for model: Excel.RowModel, row: Int) -> Excel.Content? { nil }
}

final class ExternalHost: NSObject, ListExcelDataSource, ListExcelCellHandling, ListExcelInteractionDelegate {
    typealias T = ExternalHeader

    var headerByColumn: [Int: Excel.Content] = [:]
    var rowByUnion: ((Excel.CellUnion<ExternalHeader>) -> Excel.Content?)?
    var footerByColumn: [Int: Excel.Content] = [:]

    func listExcelView(
        _ excelView: ListExcelView<ExternalHeader>,
        headerContentAt header: ExternalHeader,
        column: Int
    ) -> Excel.Content? {
        headerByColumn[column]
    }

    func listExcelView(
        _ excelView: ListExcelView<ExternalHeader>,
        contentAt union: Excel.CellUnion<ExternalHeader>
    ) -> Excel.Content? {
        if let rowByUnion { return rowByUnion(union) }
        return .text("r\(union.row)-c\(union.column)")
    }

    func listExcelView(
        _ excelView: ListExcelView<ExternalHeader>,
        footerContentAt header: ExternalHeader,
        column: Int
    ) -> Excel.Content? {
        footerByColumn[column]
    }
}

enum TestListFactory {
    @MainActor
    static func makeList(
        headers: [TestHeader] = [.name, .value],
        footerHeight: CGFloat = 0,
        host: TestListHost = TestListHost()
    ) -> (ListExcelView<TestHeader>, TestListHost, UIWindow) {
        var configuration = ListExcelView<TestHeader>.Configuration()
        configuration.excel.headerHeight = 44
        configuration.excel.footerHeight = footerHeight
        configuration.excel.rowHeight = 44
        let list = ListExcelView<TestHeader>(frame: .init(0, 0, 375, 667), configuration: configuration)
        list.delegate = host

        let window = UIWindow(frame: .init(0, 0, 375, 667))
        let root = UIViewController()
        root.view.addSubview(list)
        list.frame = root.view.bounds
        window.rootViewController = root
        window.makeKeyAndVisible()

        list.setHeaders(headers)
        return (list, host, window)
    }

    @MainActor
    static func makeSortProbeList() -> (ListExcelView<SortProbeHeader>, SortProbeHost, UIWindow) {
        let host = SortProbeHost()
        var configuration = ListExcelView<SortProbeHeader>.Configuration()
        configuration.excel.headerHeight = 44
        configuration.excel.footerHeight = 0
        let list = ListExcelView<SortProbeHeader>(frame: .init(0, 0, 375, 667), configuration: configuration)
        list.delegate = host

        let window = UIWindow(frame: .init(0, 0, 375, 667))
        let root = UIViewController()
        root.view.addSubview(list)
        list.frame = root.view.bounds
        window.rootViewController = root
        window.makeKeyAndVisible()

        list.setHeaders([
            SortProbeHeader(title: "Col", sortKey: "k"),
            SortProbeHeader(title: "Col", sortKey: ""),
        ])
        return (list, host, window)
    }

    @MainActor
    static func makeExternalList(
        footerHeight: CGFloat = 44,
        footerSumTitle: ListExcelView<ExternalHeader>.LocalizedText? = .custom("合计"),
        configure: ((ExternalHost, inout ListExcelView<ExternalHeader>.Configuration) -> Void)? = nil
    ) -> (ListExcelView<ExternalHeader>, ExternalHost, UIWindow) {
        let host = ExternalHost()
        var configuration = ListExcelView<ExternalHeader>.Configuration()
        configuration.excel.headerHeight = 44
        configuration.excel.footerHeight = footerHeight
        configuration.excel.rowHeight = 44
        configuration.excel.locale = Excel.Locale.zhCN
        configuration.footerSumTitle = footerSumTitle
        configure?(host, &configuration)

        let list = ListExcelView<ExternalHeader>(frame: .init(0, 0, 375, 667), configuration: configuration)
        list.delegate = host

        let window = UIWindow(frame: .init(0, 0, 375, 667))
        let root = UIViewController()
        root.view.addSubview(list)
        list.frame = root.view.bounds
        window.rootViewController = root
        window.makeKeyAndVisible()

        list.setHeaders([.title, .amount])
        return (list, host, window)
    }
}
