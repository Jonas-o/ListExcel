//
//  ContentGalleryDemoViewController.swift
//  ListExcelExample
//

import ListExcel
import UIKit

/// 展示各类 `Excel.Content`：decimals / cornerDecimal / cornerTextField 等。
enum GalleryHeader: String, CaseIterable, Excel.Header {
    case name
    case decimals
    case cornerDec
    case cornerTF
    case cornerTxt
    case plainDec

    var title: String {
        switch self {
            case .name: return "名称"
            case .decimals: return "多行数"
            case .cornerDec: return "角标数"
            case .cornerTF: return "角标输入"
            case .cornerTxt: return "角标文"
            case .plainDec: return "金额"
        }
    }

    var sortBy: String { self == .name ? "name" : "" }

    func content(for model: Excel.RowModel, row: Int) -> Excel.Content? {
        guard let item = model as? GalleryRow else { return nil }
        switch self {
            case .name: return .text(item.name)
            case .decimals:
                return .decimals([
                    .init(item.lineA, style: .decimal),
                    .init(item.lineB, style: .percent),
                ])
            case .cornerDec:
                return .cornerDecimal(
                    item.amount,
                    .currency,
                    leadingCorner: item.flag ? .init(Decimal(1), style: .none) : nil,
                    trailingCorner: .init(item.badge, style: .none)
                )
            case .cornerTF:
                return .cornerTextField(
                    item.input,
                    leadingCorner: .init(Decimal(string: "9"), style: .none),
                    trailingCorner: nil
                )
            case .cornerTxt:
                return .cornerText(
                    item.tag,
                    leadingCorner: item.hot ? .init(Decimal(1), style: .none) : nil,
                    trailingCorner: nil
                )
            case .plainDec:
                return .decimal(item.amount, .currency, item.amount == 0)
        }
    }
}

struct GalleryRow: Excel.RowModel, Excel.ModelIdentifier {
    var identifier: String
    var name: String
    var lineA: Decimal
    var lineB: Decimal
    var amount: Decimal
    var badge: Decimal
    var input: String
    var tag: String
    var flag: Bool
    var hot: Bool
}

final class ContentGalleryDemoViewController: UIViewController, ListExcelDataSource, ListExcelCellHandling, ListExcelInteractionDelegate {
    typealias T = GalleryHeader

    private let listView = ListExcelView<GalleryHeader>()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        var configuration = ListExcelView<GalleryHeader>.Configuration()
        configuration.excel.headerHeight = 44
        configuration.excel.rowHeight = 52
        configuration.excel.leadingLockCount = 1
        configuration.excel.footerHeight = 0
        configuration.showsTotalView = true
        configuration.showsSortHint = true
        configuration.excel.selectionType = .cell()

        listView.applyConfiguration(configuration)
        listView.delegate = self
        listView.setHeaders(GalleryHeader.allCases)
        listView.reset(Self.seed())
        listView.total = listView.rowDatas.count
        listView.showNotice = "decimals / corner* / decimal(hiddenZero)"
        view.addSubview(listView)
        listView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            listView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            listView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            listView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            listView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    private static func seed() -> [GalleryRow] {
        var rows: [GalleryRow] = []
        rows.reserveCapacity(12)
        for index in 0 ..< 12 {
            let amount: Decimal = index == 3 ? 0 : Decimal((index + 1) * 128)
            rows.append(
                GalleryRow(
                    identifier: "g-\(index)",
                    name: "品目 \(index + 1)",
                    lineA: Decimal(100 + index * 13),
                    lineB: Decimal(index % 5) / 100 + Decimal(string: "0.08")!,
                    amount: amount,
                    badge: Decimal(index % 3),
                    input: "\(index + 1)",
                    tag: index.isMultiple(of: 2) ? "套餐" : "单品",
                    flag: index < 3,
                    hot: index.isMultiple(of: 4)
                )
            )
        }
        return rows
    }

    func listExcelView(
        _ excelView: ListExcelView<GalleryHeader>,
        handleRow cell: some Excel.Cell,
        union: Excel.CellUnion<GalleryHeader>
    ) {
        guard var row = union.rowModel as? GalleryRow,
              let fieldCell = cell as? Excel.DefaultCornerTextFieldCell
        else { return }
        fieldCell.editingAction = { [weak self] _, field, event in
            guard let self, event == .editingDidEnd || event == .editingDidEndOnExit else { return }
            row.input = field.text ?? ""
            _ = self.listView.replace(row)
            self.listView.showNotice = "cornerTextField 写回 \(row.name)"
        }
    }

    func listExcelView(_ excelView: ListExcelView<GalleryHeader>, didSortAt column: Excel.SortColumn<GalleryHeader>?) {
        guard let column, column.header == .name else { return }
        var rows = listView.rowDatas.compactMap { $0 as? GalleryRow }
        let asc = column.type == .ascending
        rows.sort { asc ? $0.name < $1.name : $0.name > $1.name }
        listView.reset(rows)
    }
}
