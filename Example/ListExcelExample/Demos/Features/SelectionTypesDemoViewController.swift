//
//  SelectionTypesDemoViewController.swift
//  ListExcelExample
//

import ListExcel
import UIKit

enum SelectDemoHeader: String, CaseIterable, Excel.Header {
    case select
    case title
    case value

    var title: String {
        switch self {
            case .select: return ""
            case .title: return "标题"
            case .value: return "数值"
        }
    }

    func content(for model: Excel.RowModel, row: Int) -> Excel.Content? {
        guard let item = model as? SelectDemoRow else { return nil }
        switch self {
            case .select: return .select
            case .title: return .text(item.title)
            case .value: return .text(item.value)
        }
    }
}

struct SelectDemoRow: Excel.RowModel, Excel.ModelIdentifier {
    var identifier: String
    var title: String
    var value: String
}

/// 对比 `selectionType`：none / cell / row / rowSelection。
final class SelectionTypesDemoViewController: UIViewController, ListExcelDataSource, ListExcelCellHandling, ListExcelInteractionDelegate {
    typealias T = SelectDemoHeader

    private let listView = ListExcelView<SelectDemoHeader>()
    private let typeControl = UISegmentedControl(items: ["none", "cell", "row", "rowSel"])
    private let logLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        typeControl.selectedSegmentIndex = 2
        typeControl.addTarget(self, action: #selector(typeChanged), for: .valueChanged)
        view.addSubview(typeControl)

        logLabel.font = .systemFont(ofSize: 13)
        logLabel.textColor = .secondaryLabel
        logLabel.numberOfLines = 2
        logLabel.text = "切换上方类型，再点单元格观察高亮与回调"
        view.addSubview(logLabel)

        var configuration = ListExcelView<SelectDemoHeader>.Configuration()
        configuration.excel.headerHeight = 40
        configuration.excel.rowHeight = 44
        configuration.excel.leadingLockCount = 1
        configuration.showsTotalView = true
        listView.configuration = configuration
        listView.applyConfiguration()
        listView.delegate = self
        listView.selectionType = .row()
        listView.setHeaders(SelectDemoHeader.allCases)
        listView.reset((0 ..< 20).map {
            SelectDemoRow(identifier: "s-\($0)", title: "行 \($0 + 1)", value: "V\($0)")
        })
        listView.total = listView.rowDatas.count
        view.addSubview(listView)

        [typeControl, logLabel, listView].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            typeControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            typeControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            typeControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            logLabel.topAnchor.constraint(equalTo: typeControl.bottomAnchor, constant: 8),
            logLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            logLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            listView.topAnchor.constraint(equalTo: logLabel.bottomAnchor, constant: 8),
            listView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            listView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            listView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    @objc private func typeChanged() {
        switch typeControl.selectedSegmentIndex {
            case 0: listView.selectionType = .none
            case 1: listView.selectionType = .cell()
            case 2: listView.selectionType = .row()
            default: listView.selectionType = .rowSelection()
        }
        logLabel.text = "当前 selectionType index=\(typeControl.selectedSegmentIndex)"
    }

    func listExcelView(
        _ excelView: ListExcelView<SelectDemoHeader>,
        headerContentAt header: SelectDemoHeader,
        column: Int
    ) -> Excel.Content? {
        header == .select ? .select : nil
    }

    func listExcelView(
        _ excelView: ListExcelView<SelectDemoHeader>,
        didSelectRowAt row: Int,
        rowModel: Excel.RowModel,
        column: Int?,
        header: SelectDemoHeader?
    ) {
        let title = (rowModel as? SelectDemoRow)?.title ?? "?"
        logLabel.text = "didSelectRow row=\(row) col=\(column.map(String.init) ?? "nil") header=\(header?.title ?? "-") · \(title)"
        listView.showNotice = logLabel.text
    }

    func listExcelView(_ excelView: ListExcelView<SelectDemoHeader>, selectedRowsChanged identifiers: Set<String>) {
        logLabel.text = "selectedRowsChanged count=\(identifiers.count)"
    }
}
