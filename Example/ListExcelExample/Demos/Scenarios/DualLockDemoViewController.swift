//
//  DualLockDemoViewController.swift
//  ListExcelExample
//

import ListExcel
import UIKit

enum StockHeader: String, CaseIterable, Excel.Header {
    case sku
    case name
    case warehouse
    case shelf
    case stock
    case reserved
    case available
    case inbound
    case outbound
    case supplier
    case updatedAt
    case action

    var title: String {
        switch self {
            case .sku: return "SKU"
            case .name: return "品名"
            case .warehouse: return "仓库"
            case .shelf: return "货架"
            case .stock: return "库存"
            case .reserved: return "预留"
            case .available: return "可用"
            case .inbound: return "在途入库"
            case .outbound: return "待出库"
            case .supplier: return "供应商"
            case .updatedAt: return "更新时间"
            case .action: return "操作"
        }
    }

    var sortBy: String {
        switch self {
            case .stock, .available, .sku: return rawValue
            default: return ""
        }
    }

    var minWidth: CGFloat? {
        switch self {
            case .action: return 64
            default: return nil
        }
    }

    func content(for model: Excel.RowModel, row: Int) -> Excel.Content? {
        guard let item = model as? StockRow else { return nil }
        switch self {
            case .sku: return .text(item.sku)
            case .name: return .text(item.name)
            case .warehouse: return .text(item.warehouse)
            case .shelf: return .text(item.shelf)
            case .stock: return .decimal(Decimal(item.stock), .none)
            case .reserved: return .decimal(Decimal(item.reserved), .none)
            case .available: return .decimal(Decimal(item.available), .none)
            case .inbound: return .decimal(Decimal(item.inbound), .none)
            case .outbound: return .decimal(Decimal(item.outbound), .none)
            case .supplier: return .text(item.supplier)
            case .updatedAt: return .text(item.updatedAt)
            case .action: return .iconText(.clear, "定位")
        }
    }
}

struct StockRow: Excel.RowModel, Excel.ModelIdentifier {
    var identifier: String
    var sku: String
    var name: String
    var warehouse: String
    var shelf: String
    var stock: Int
    var reserved: Int
    var available: Int { stock - reserved }
    var inbound: Int
    var outbound: Int
    var supplier: String
    var updatedAt: String
}

enum StockFactory {
    static func rows(count: Int = 40) -> [StockRow] {
        let names = ["碳纤维支架", "无线充电座", "工业网关", "传感器模组", "散热风扇", "电源适配器"]
        let suppliers = ["深创硬件", "甬江器件", "苏锡通联", "成渝智造"]
        return (0 ..< count).map { index in
            let stock = 20 + index * 3
            let reserved = index % 9
            return StockRow(
                identifier: "sku-\(index)",
                sku: String(format: "SKU-%04d", index + 1),
                name: "\(names[index % names.count])-\(index + 1)",
                warehouse: index.isMultiple(of: 2) ? "上海仓" : "深圳仓",
                shelf: "\(UnicodeScalar(65 + index % 6)!.description)-\(index % 20 + 1)",
                stock: stock,
                reserved: reserved,
                inbound: index % 5,
                outbound: index % 4,
                supplier: suppliers[index % suppliers.count],
                updatedAt: String(format: "14:%02d", index % 60)
            )
        }
    }
}

final class DualLockDemoViewController: UIViewController, ListExcelDataSource, ListExcelCellHandling, ListExcelInteractionDelegate {
    typealias T = StockHeader

    private let listView = ListExcelView<StockHeader>()
    private let buttonBar = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureList()
        configureButtons()
        layout()
        listView.reset(StockFactory.rows())
        listView.total = listView.rowDatas.count
        listView.showNotice = "左锁 SKU/品名 · 右锁操作 · 中间横滑"
    }

    private func configureList() {
        var configuration = ListExcelView<StockHeader>.Configuration()
        configuration.excel.headerHeight = 44
        configuration.excel.footerHeight = 0
        configuration.excel.rowHeight = 44
        configuration.excel.leadingLockCount = 2
        configuration.excel.trailingLockCount = 1
        configuration.showsTotalView = true
        configuration.showsSortHint = true
        configuration.excel.selectionType = .cell()

        listView.applyConfiguration(configuration)
        listView.delegate = self
        listView.setHeaders(StockHeader.allCases)
        view.addSubview(listView)
    }

    private func configureButtons() {
        buttonBar.axis = .horizontal
        buttonBar.spacing = 8
        buttonBar.distribution = .fillEqually
        [
            ("到库存", #selector(jumpStock)),
            ("到供应商", #selector(jumpSupplier)),
            ("重置偏移", #selector(resetOffset)),
            ("换大字体", #selector(toggleFont)),
        ].forEach { title, sel in
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.addTarget(self, action: sel, for: .touchUpInside)
            buttonBar.addArrangedSubview(button)
        }
        view.addSubview(buttonBar)
    }

    private func layout() {
        buttonBar.translatesAutoresizingMaskIntoConstraints = false
        listView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            buttonBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            buttonBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            buttonBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            buttonBar.heightAnchor.constraint(equalToConstant: 36),

            listView.topAnchor.constraint(equalTo: buttonBar.bottomAnchor, constant: 4),
            listView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            listView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            listView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    @objc private func jumpStock() {
        if let column = listView.headers.firstIndex(of: .stock) {
            listView.scrollToColumn(at: column, animated: true)
        }
    }

    @objc private func jumpSupplier() {
        if let column = listView.headers.firstIndex(of: .supplier) {
            listView.scrollToColumn(at: column, animated: true)
        }
    }

    @objc private func resetOffset() {
        listView.resetContentOffset()
        listView.showNotice = "已重置横向 contentOffset"
    }

    @objc private func toggleFont() {
        var configuration = listView.configuration
        let large = configuration.excel.rowFont.pointSize > 14
        configuration.excel.rowFont = .systemFont(ofSize: large ? 13 : 16)
        configuration.excel.headerFont = .systemFont(ofSize: large ? 13 : 16, weight: .medium)
        listView.applyConfiguration(configuration)
        listView.showNotice = large ? "恢复默认字号（列宽重算）" : "放大字号并 invalidate 列宽"
    }

    func listExcelView(_ excelView: ListExcelView<StockHeader>, didSortAt column: Excel.SortColumn<StockHeader>?) {
        guard let column else { return }
        var rows = listView.rowDatas.compactMap { $0 as? StockRow }
        let asc = column.type == .ascending
        switch column.header {
            case .sku: rows.sort { asc ? $0.sku < $1.sku : $0.sku > $1.sku }
            case .stock: rows.sort { asc ? $0.stock < $1.stock : $0.stock > $1.stock }
            case .available: rows.sort { asc ? $0.available < $1.available : $0.available > $1.available }
            default: return
        }
        listView.reset(rows)
    }

    func listExcelView(
        _ excelView: ListExcelView<StockHeader>,
        didSelectRowAt row: Int,
        rowModel: Excel.RowModel,
        column: Int?,
        header: StockHeader?
    ) {
        guard let item = rowModel as? StockRow else { return }
        if header == .action {
            listView.scrollToMatrix(
                at: .init(column: listView.headers.firstIndex(of: .shelf) ?? 0, row: .cell(row)),
                animated: true
            )
            listView.showNotice = "定位 \(item.sku) 货架 \(item.shelf)"
            return
        }
        listView.showNotice = "\(item.sku) · \(header?.title ?? "")"
    }

    func listExcelView(
        _ excelView: ListExcelView<StockHeader>,
        backgroundColorAt row: Int,
        rowModel: Excel.RowModel
    ) -> UIColor? {
        guard let item = rowModel as? StockRow else { return nil }
        if item.available < 10 { return DemoPalette.warning }
        return row.isMultiple(of: 2) ? DemoPalette.zebra : nil
    }
}
