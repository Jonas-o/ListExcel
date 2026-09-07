//
//  EditableDemoViewController.swift
//  ListExcelExample
//

import ListExcel
import UIKit

enum QuoteHeader: String, CaseIterable, Excel.Header {
    case name
    case unitPrice
    case qty
    case subtotal
    case remark
    case tag

    var title: String {
        switch self {
            case .name: return "品名"
            case .unitPrice: return "单价"
            case .qty: return "数量"
            case .subtotal: return "小计"
            case .remark: return "备注"
            case .tag: return "角标"
        }
    }

    var sortBy: String {
        self == .name || self == .subtotal ? rawValue : ""
    }

    func content(for model: Excel.RowModel, row: Int) -> Excel.Content? {
        guard let item = model as? QuoteRow else { return nil }
        switch self {
            case .name: return .text(item.name)
            case .unitPrice: return .decimal(item.unitPrice, .currency)
            case .qty: return .textField("\(item.qty)")
            case .subtotal: return .decimal(item.subtotal, .currency)
            case .remark: return .textField(item.remark)
            case .tag:
                return .cornerText(
                    item.tag,
                    leadingCorner: item.hot ? .init(Decimal(1), style: .none) : nil,
                    trailingCorner: nil
                )
        }
    }
}

struct QuoteRow: Excel.RowModel, Excel.ModelIdentifier {
    var identifier: String
    var name: String
    var unitPrice: Decimal
    var qty: Int
    var remark: String
    var tag: String
    var hot: Bool

    var subtotal: Decimal { unitPrice * Decimal(qty) }
}

enum QuoteFactory {
    static func rows() -> [QuoteRow] {
        let names = ["咨询服务", "实施人天", "年度维保", "定制报表", "数据迁移", "培训场次"]
        return names.enumerated().map { index, name in
            QuoteRow(
                identifier: "quote-\(index)",
                name: name,
                unitPrice: Decimal((index + 2) * 800),
                qty: index + 1,
                remark: index.isMultiple(of: 2) ? "可议" : "",
                tag: index.isMultiple(of: 3) ? "套餐" : "单项",
                hot: index < 2
            )
        }
    }
}

final class EditableDemoViewController: UIViewController, ListExcelDataSource, ListExcelCellHandling, ListExcelInteractionDelegate {
    typealias T = QuoteHeader

    private let listView = ListExcelView<QuoteHeader>()
    private let summaryLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "重算合计",
            style: .plain,
            target: self,
            action: #selector(refreshSummary)
        )

        summaryLabel.font = .systemFont(ofSize: 14)
        summaryLabel.textColor = .secondaryLabel
        summaryLabel.numberOfLines = 2
        view.addSubview(summaryLabel)

        var configuration = ListExcelView<QuoteHeader>.Configuration()
        configuration.excel.headerHeight = 44
        configuration.excel.footerHeight = 40
        configuration.excel.rowHeight = 48
        configuration.excel.leadingLockCount = 1
        configuration.footerSumTitle = .localeDefault
        configuration.showsTotalView = true
        configuration.showsSortHint = true

        listView.configuration = configuration
        listView.applyConfiguration()
        listView.delegate = self
        listView.selectionType = .none
        listView.setHeaders(QuoteHeader.allCases)
        listView.reset(QuoteFactory.rows())
        listView.total = listView.rowDatas.count
        listView.showNotice = "编辑数量/备注后失焦即 replace"
        view.addSubview(listView)

        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        listView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            summaryLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            summaryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            summaryLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            listView.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 8),
            listView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            listView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            listView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        refreshSummary()
    }

    @objc private func refreshSummary() {
        let rows = listView.rowDatas.compactMap { $0 as? QuoteRow }
        let total = rows.reduce(Decimal(0)) { $0 + $1.subtotal }
        let qty = rows.reduce(0) { $0 + $1.qty }
        summaryLabel.text = "行数 \(rows.count) · 件数 \(qty) · 金额 \(total)"
        listView.reloadFooter()
    }

    func listExcelView(
        _ excelView: ListExcelView<QuoteHeader>,
        footerContentAt header: QuoteHeader,
        column: Int
    ) -> Excel.Content? {
        let rows = listView.rowDatas.compactMap { $0 as? QuoteRow }
        switch header {
            case .subtotal: return .decimal(rows.reduce(0) { $0 + $1.subtotal }, .currency)
            case .qty: return .text("\(rows.reduce(0) { $0 + $1.qty })")
            default: return nil
        }
    }

    func listExcelView(
        _ excelView: ListExcelView<QuoteHeader>,
        handleRow cell: some Excel.Cell,
        union: Excel.CellUnion<QuoteHeader>
    ) {
        guard var row = union.rowModel as? QuoteRow else { return }
        if let fieldCell = cell as? Excel.DefaultTextFieldCell {
            fieldCell.textField.keyboardType = union.header == .qty ? .numberPad : .default
            fieldCell.editingAction = { [weak self] _, field, event in
                guard let self, event == .editingDidEnd || event == .editingDidEndOnExit else { return }
                switch union.header {
                    case .qty:
                        row.qty = max(Int(field.text ?? "") ?? row.qty, 0)
                    case .remark:
                        row.remark = field.text ?? ""
                    default:
                        return
                }
                _ = self.listView.replace(row)
                self.refreshSummary()
                self.listView.showNotice = "已写回 \(row.name)"
            }
        }
    }

    func listExcelView(_ excelView: ListExcelView<QuoteHeader>, didSortAt column: Excel.SortColumn<QuoteHeader>?) {
        guard let column else { return }
        var rows = listView.rowDatas.compactMap { $0 as? QuoteRow }
        let asc = column.type == .ascending
        switch column.header {
            case .name: rows.sort { asc ? $0.name < $1.name : $0.name > $1.name }
            case .subtotal: rows.sort { asc ? $0.subtotal < $1.subtotal : $0.subtotal > $1.subtotal }
            default: return
        }
        listView.reset(rows)
        refreshSummary()
    }
}
