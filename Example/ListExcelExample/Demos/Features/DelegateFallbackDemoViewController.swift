//
//  DelegateFallbackDemoViewController.swift
//  ListExcelExample
//

import ListExcel
import UIKit

/// `Header.content` 恒 nil，内容全部走 Delegate `contentAt` / header / footer。
enum FallbackHeader: String, CaseIterable, Excel.Header {
    case code
    case title
    case amount

    var title: String { rawValue.uppercased() }
    var sortBy: String { "" }

    func content(for model: Excel.RowModel, row: Int) -> Excel.Content? { nil }
}

struct FallbackRow: Excel.RowModel, Excel.ModelIdentifier {
    var identifier: String
    var code: String
    var title: String
    var amount: Decimal
}

final class DelegateFallbackDemoViewController: UIViewController, ListExcelDataSource, ListExcelCellHandling, ListExcelInteractionDelegate {
    typealias T = FallbackHeader

    private let listView = ListExcelView<FallbackHeader>()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        var configuration = ListExcelView<FallbackHeader>.Configuration()
        configuration.excel.headerHeight = 44
        configuration.excel.footerHeight = 40
        configuration.excel.rowHeight = 44
        configuration.footerSumTitle = .custom("汇总(Delegate 回退)")
        configuration.showsTotalView = true

        listView.applyConfiguration(configuration)
        listView.delegate = self
        listView.setHeaders(FallbackHeader.allCases)
        listView.reset((0 ..< 15).map {
            FallbackRow(
                identifier: "fb-\($0)",
                code: String(format: "D%03d", $0 + 1),
                title: "Delegate 行 \($0 + 1)",
                amount: Decimal(($0 + 1) * 50)
            )
        })
        listView.total = listView.rowDatas.count
        listView.showNotice = "Header.content≡nil → contentAt / headerContent / footerSumTitle"
        view.addSubview(listView)
        listView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            listView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            listView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            listView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            listView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    func listExcelView(
        _ excelView: ListExcelView<FallbackHeader>,
        headerContentAt header: FallbackHeader,
        column: Int
    ) -> Excel.Content? {
        .text("H-\(header.title)")
    }

    func listExcelView(
        _ excelView: ListExcelView<FallbackHeader>,
        contentAt union: Excel.CellUnion<FallbackHeader>
    ) -> Excel.Content? {
        guard let row = union.rowModel as? FallbackRow else { return nil }
        switch union.header {
            case .code: return .text(row.code)
            case .title: return .text(row.title)
            case .amount: return .decimal(row.amount, .currency)
        }
    }

    func listExcelView(
        _ excelView: ListExcelView<FallbackHeader>,
        footerContentAt header: FallbackHeader,
        column: Int
    ) -> Excel.Content? {
        // amount 列提供 footer；code 列走 footerSumTitle 回退
        if header == .amount {
            let sum = listView.rowDatas.compactMap { $0 as? FallbackRow }.reduce(Decimal(0)) { $0 + $1.amount }
            return .decimal(sum, .currency)
        }
        return nil
    }
}
