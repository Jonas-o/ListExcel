//
//  OrdersDemoViewController.swift
//  ListExcelExample
//

import ListExcel
import UIKit

// MARK: - Models

enum OrderHeader: String, CaseIterable, Excel.Header {
    case select
    case orderNo
    case customer
    case amount
    case discount
    case region
    case createdAt
    case status

    var title: String {
        switch self {
            case .select: return ""
            case .orderNo: return "单号"
            case .customer: return "客户"
            case .amount: return "金额"
            case .discount: return "折扣"
            case .region: return "区域"
            case .createdAt: return "下单时间"
            case .status: return "状态"
        }
    }

    var sortBy: String {
        switch self {
            case .orderNo: return "orderNo"
            case .amount: return "amount"
            case .createdAt: return "createdAt"
            case .customer: return "customer"
            default: return ""
        }
    }

    var textAlignment: NSTextAlignment? {
        switch self {
            case .amount, .discount: return .right
            case .status: return .center
            default: return nil
        }
    }

    func content(for model: Excel.RowModel, row: Int) -> Excel.Content? {
        guard let order = model as? OrderRow else { return nil }
        switch self {
            case .select: return .select
            case .orderNo: return .text(order.orderNo)
            case .customer: return .text(order.customer)
            case .amount: return .decimal(order.amount, .currency)
            case .discount: return .decimal(order.discount, .percent)
            case .region: return .text(order.region)
            case .createdAt: return .text(order.createdAt)
            case .status: return .text(order.status.title)
        }
    }
}

enum OrderStatus: CaseIterable {
    case pending
    case shipping
    case done
    case cancelled

    var title: String {
        switch self {
            case .pending: return "待发货"
            case .shipping: return "运输中"
            case .done: return "已完成"
            case .cancelled: return "已取消"
        }
    }
}

struct OrderRow: Excel.RowModel, Excel.ModelIdentifier {
    var identifier: String
    var orderNo: String
    var customer: String
    var amount: Decimal
    var discount: Decimal
    var region: String
    var createdAt: String
    var status: OrderStatus
}

enum OrderFactory {
    static let pageSize = 18
    static let totalCount = 96
    private static let regions = ["华东", "华南", "华北", "西南", "西北"]
    private static let customers = ["星云科技", "青禾零售", "远航物流", "麦田农业", "灯塔传媒", "山海文旅"]

    static func page(_ page: Int, filter: OrderStatus?) -> [OrderRow] {
        let all = (0 ..< totalCount).map(make(index:))
        let filtered = filter.map { status in all.filter { $0.status == status } } ?? all
        let start = page * pageSize
        guard start < filtered.count else { return [] }
        let end = min(start + pageSize, filtered.count)
        return Array(filtered[start ..< end])
    }

    static func filteredTotal(_ filter: OrderStatus?) -> Int {
        guard let filter else { return totalCount }
        return (0 ..< totalCount).map(make(index:)).filter { $0.status == filter }.count
    }

    private static func make(index: Int) -> OrderRow {
        let status = OrderStatus.allCases[index % OrderStatus.allCases.count]
        return OrderRow(
            identifier: "order-\(index)",
            orderNo: String(format: "SO%06d", 100_000 + index),
            customer: customers[index % customers.count],
            amount: Decimal(index * 37 + 259) / 10,
            discount: Decimal(index % 7) / 100 + 0.05,
            region: regions[index % regions.count],
            createdAt: String(format: "09-%02d %02d:%02d", (index % 28) + 1, index % 24, (index * 3) % 60),
            status: status
        )
    }
}

// MARK: - Controller

final class OrdersDemoViewController: UIViewController, ListExcelDataSource, ListExcelCellHandling, ListExcelInteractionDelegate {
    typealias T = OrderHeader

    private let listView = ListExcelView<OrderHeader>()
    private let filterControl = UISegmentedControl(items: ["全部"] + OrderStatus.allCases.map(\.title))
    private let toolbar = UIToolbar()
    private var selectedItem: UIBarButtonItem!
    private var filter: OrderStatus?
    private var loadedCount = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "批量删", style: .plain, target: self, action: #selector(batchDelete)),
            UIBarButtonItem(title: "改选中", style: .plain, target: self, action: #selector(mutateSelected)),
        ]

        configureFilter()
        configureList()
        configureToolbar()
        layout()
        reloadFirstPage()
    }

    private func configureFilter() {
        filterControl.selectedSegmentIndex = 0
        filterControl.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        view.addSubview(filterControl)
    }

    private func configureList() {
        var configuration = ListExcelView<OrderHeader>.Configuration()
        configuration.excel.headerHeight = 44
        configuration.excel.footerHeight = 40
        configuration.excel.rowHeight = 44
        configuration.excel.leadingLockCount = 2
        configuration.excel.trailingLockCount = 1
        configuration.footerSumTitle = .custom("本页合计")
        configuration.showsTotalView = true
        configuration.showsSortHint = true
        configuration.loadMoreThreshold = 120
        configuration.excel.selectionType = .row()

        listView.applyConfiguration(configuration)
        listView.delegate = self
        listView.setHeaders(OrderHeader.allCases)
        listView.totalView.resetActionButton("回到顶部") { [weak self] _ in
            self?.listView.scrollToTop()
        }
        view.addSubview(listView)
    }

    private func configureToolbar() {
        selectedItem = UIBarButtonItem(title: "已选 0", style: .plain, target: nil, action: nil)
        selectedItem.isEnabled = false
        let clear = UIBarButtonItem(title: "清空", style: .plain, target: self, action: #selector(clearSelection))
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let jump = UIBarButtonItem(title: "滚到金额列", style: .plain, target: self, action: #selector(scrollAmount))
        toolbar.items = [selectedItem, clear, flex, jump]
        view.addSubview(toolbar)
    }

    private func layout() {
        [filterControl, listView, toolbar].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            filterControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            filterControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            filterControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            listView.topAnchor.constraint(equalTo: filterControl.bottomAnchor, constant: 8),
            listView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            listView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            listView.bottomAnchor.constraint(equalTo: toolbar.topAnchor),
        ])
    }

    private func reloadFirstPage() {
        listView.page = 0
        listView.total = OrderFactory.filteredTotal(filter)
        listView.showNotice = "加载中…"
        listView.isLoading = true
        DemoNetwork.fetch({ OrderFactory.page(0, filter: self.filter) }) { [weak self] rows in
            guard let self else { return }
            self.listView.reset(rows)
            self.loadedCount = rows.count
            self.listView.isLoading = false
            self.refreshIndicators()
            self.listView.showNotice = "上拉加载 · 点表头排序 · 左锁单号/勾选"
            self.listView.reloadFooter()
        }
    }

    private func refreshIndicators() {
        let rows = listView.rowDatas.compactMap { $0 as? OrderRow }
        let done = rows.filter { $0.status == .done }.count
        let shipping = rows.filter { $0.status == .shipping }.count
        let pending = rows.filter { $0.status == .pending }.count
        listView.totalView.resetIndicators([
            .green("完成 \(done)"),
            .yellow("运输 \(shipping)"),
            .red("待发 \(pending)"),
        ])
        listView.total = OrderFactory.filteredTotal(filter)
    }

    @objc private func filterChanged() {
        let index = filterControl.selectedSegmentIndex
        filter = index == 0 ? nil : OrderStatus.allCases[index - 1]
        listView.clearSelection()
        listView.clearSorts()
        reloadFirstPage()
    }

    @objc private func clearSelection() {
        listView.clearSelection()
    }

    @objc private func scrollAmount() {
        if let column = listView.headers.firstIndex(of: .amount) {
            listView.scrollToColumn(at: column, animated: true)
        }
    }

    @objc private func mutateSelected() {
        let ids = listView.selectRows
        guard !ids.isEmpty else {
            demoAlert("请先勾选订单")
            return
        }
        listView.isLoading = true
        var changed = 0
        for (index, model) in listView.rowDatas.enumerated() {
            guard var order = model as? OrderRow, ids.contains(order.identifier) else { continue }
            order.amount += 50
            order.status = .shipping
            listView.update(at: index, order)
            changed += 1
        }
        listView.isLoading = false
        refreshIndicators()
        listView.reloadFooter()
        listView.showNotice = "已更新 \(changed) 条"
    }

    @objc private func batchDelete() {
        let ids = listView.selectRows
        guard !ids.isEmpty else {
            demoAlert("请先勾选要删除的订单")
            return
        }
        let remain = listView.rowDatas.compactMap { $0 as? OrderRow }.filter { !ids.contains($0.identifier) }
        listView.isLoading = true
        listView.reset(remain)
        listView.isLoading = false
        loadedCount = remain.count
        refreshIndicators()
        listView.reloadFooter()
        listView.showNotice = "已删除 \(ids.count) 条（仅当前已加载集）"
    }

    // MARK: Delegate

    func listExcelView(
        _ excelView: ListExcelView<OrderHeader>,
        headerContentAt header: OrderHeader,
        column: Int
    ) -> Excel.Content? {
        header == .select ? .select : nil
    }

    func listExcelView(
        _ excelView: ListExcelView<OrderHeader>,
        footerContentAt header: OrderHeader,
        column: Int
    ) -> Excel.Content? {
        let rows = listView.rowDatas.compactMap { $0 as? OrderRow }
        switch header {
            case .amount:
                return .decimal(rows.reduce(0) { $0 + $1.amount }, .currency)
            case .customer:
                return .text("\(rows.count) 单")
            default:
                return nil
        }
    }

    func listExcelView(
        _ excelView: ListExcelView<OrderHeader>,
        backgroundColorAt row: Int,
        rowModel: Excel.RowModel
    ) -> UIColor? {
        guard let order = rowModel as? OrderRow else { return nil }
        if order.status == .cancelled { return DemoPalette.warning }
        if order.status == .done { return DemoPalette.success }
        return row.isMultiple(of: 2) ? DemoPalette.zebra : nil
    }

    func listExcelView(_ excelView: ListExcelView<OrderHeader>, didSortAt column: Excel.SortColumn<OrderHeader>?) {
        guard let column else { return }
        var rows = listView.rowDatas.compactMap { $0 as? OrderRow }
        let ascending = column.type == .ascending
        switch column.header {
            case .orderNo:
                rows.sort { ascending ? $0.orderNo < $1.orderNo : $0.orderNo > $1.orderNo }
            case .customer:
                rows.sort { ascending ? $0.customer < $1.customer : $0.customer > $1.customer }
            case .amount:
                rows.sort { ascending ? $0.amount < $1.amount : $0.amount > $1.amount }
            case .createdAt:
                rows.sort { ascending ? $0.createdAt < $1.createdAt : $0.createdAt > $1.createdAt }
            default:
                return
        }
        listView.isLoading = true
        listView.reset(rows)
        listView.isLoading = false
        listView.reloadFooter()
    }

    func listExcelView(_ excelView: ListExcelView<OrderHeader>, selectedRowsChanged identifiers: Set<String>) {
        selectedItem.title = "已选 \(identifiers.count)"
    }

    func listExcelView(_ excelView: ListExcelView<OrderHeader>, requestNext page: Int) {
        listView.showNotice = "加载第 \(page + 1) 页…"
        DemoNetwork.fetch(delay: 0.65, { OrderFactory.page(page, filter: self.filter) }) { [weak self] rows in
            guard let self else { return }
            self.listView.isLoading = true
            self.listView.page = page
            self.listView.append(rows)
            self.loadedCount += rows.count
            self.listView.isLoading = false
            self.refreshIndicators()
            self.listView.reloadFooter()
            let total = OrderFactory.filteredTotal(self.filter)
            self.listView.showNotice = self.loadedCount >= total
                ? "已全部加载 (\(total))"
                : "已加载 \(self.loadedCount)/\(total)"
        }
    }

    func listExcelView(
        _ excelView: ListExcelView<OrderHeader>,
        didSelectRowAt row: Int,
        rowModel: Excel.RowModel,
        column: Int?,
        header: OrderHeader?
    ) {
        guard let order = rowModel as? OrderRow, header != .select else { return }
        listView.showNotice = "\(order.orderNo) · \(order.customer) · \(header?.title ?? "")"
    }
}
