//
//  MutationLabViewController.swift
//  ListExcelExample
//

import ListExcel
import UIKit

enum LabHeader: String, CaseIterable, Excel.Header {
    case select
    case code
    case title
    case value
    case note

    var title: String {
        switch self {
            case .select: return ""
            case .code: return "编码"
            case .title: return "标题"
            case .value: return "数值"
            case .note: return "说明"
        }
    }

    var sortBy: String { self == .title || self == .value ? rawValue : "" }

    func content(for model: Excel.RowModel, row: Int) -> Excel.Content? {
        guard let item = model as? LabRow else { return nil }
        switch self {
            case .select: return .select
            case .code: return .text(item.code)
            case .title: return .text(item.title)
            case .value: return .text(item.value)
            case .note: return .text(item.note)
        }
    }
}

struct LabRow: Excel.RowModel, Excel.ModelIdentifier {
    var identifier: String
    var code: String
    var title: String
    var value: String
    var note: String
}

final class MutationLabViewController: UIViewController, ListExcelDataSource, ListExcelCellHandling, ListExcelInteractionDelegate {
    typealias T = LabHeader

    private let listView = ListExcelView<LabHeader>()
    private let logView = UITextView()
    private let actionsView = UIScrollView()
    private let actionsStack = UIStackView()
    private var seq = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        configureList()
        configureLog()
        configureActions()
        layout()
        seed()
    }

    private func configureList() {
        var configuration = ListExcelView<LabHeader>.Configuration()
        configuration.excel.headerHeight = 40
        configuration.excel.footerHeight = 36
        configuration.excel.rowHeight = 40
        configuration.excel.leadingLockCount = 1
        configuration.footerSumTitle = .custom("Footer")
        configuration.showsTotalView = true
        configuration.showsSortHint = true
        configuration.excel.selectionType = .row()

        listView.applyConfiguration(configuration)
        listView.delegate = self
        listView.setHeaders(LabHeader.allCases)
        view.addSubview(listView)
    }

    private func configureLog() {
        logView.isEditable = false
        logView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        logView.backgroundColor = UIColor.secondarySystemBackground
        logView.layer.cornerRadius = 8
        logView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        view.addSubview(logView)
    }

    private func configureActions() {
        actionsStack.axis = .vertical
        actionsStack.spacing = 8
        actionsStack.alignment = .fill
        let buttons: [(String, Selector)] = [
            ("reset 10 行", #selector(actReset)),
            ("append 5 行 (isLoading)", #selector(actAppend)),
            ("update 第 0 行加长 value", #selector(actUpdate)),
            ("replace 首个选中/首行", #selector(actReplace)),
            ("setHeaders 去掉 note", #selector(actSetHeadersNarrow)),
            ("setHeaders 恢复全列", #selector(actSetHeadersFull)),
            ("reloadData .recalculate", #selector(actRecalculate)),
            ("reloadData .keep", #selector(actKeep)),
            ("reloadData .reconcile", #selector(actReconcile)),
            ("reloadCellWidth(value)", #selector(actReloadCellWidth)),
            ("clearSelection / clearSorts", #selector(actClearMeta)),
            ("制造重复 id 再 reset 唯一", #selector(actDuplicateId)),
        ]
        buttons.forEach { title, sel in
            let button = UIButton(type: .system)
            button.contentHorizontalAlignment = .left
            button.setTitle("  \(title)", for: .normal)
            button.backgroundColor = UIColor.tertiarySystemFill
            button.layer.cornerRadius = 8
            button.heightAnchor.constraint(equalToConstant: 36).isActive = true
            button.addTarget(self, action: sel, for: .touchUpInside)
            actionsStack.addArrangedSubview(button)
        }
        actionsView.addSubview(actionsStack)
        view.addSubview(actionsView)
        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            actionsStack.topAnchor.constraint(equalTo: actionsView.contentLayoutGuide.topAnchor),
            actionsStack.leadingAnchor.constraint(equalTo: actionsView.contentLayoutGuide.leadingAnchor),
            actionsStack.trailingAnchor.constraint(equalTo: actionsView.contentLayoutGuide.trailingAnchor),
            actionsStack.bottomAnchor.constraint(equalTo: actionsView.contentLayoutGuide.bottomAnchor),
            actionsStack.widthAnchor.constraint(equalTo: actionsView.frameLayoutGuide.widthAnchor),
        ])
    }

    private func layout() {
        [listView, logView, actionsView].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            actionsView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            actionsView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            actionsView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            actionsView.heightAnchor.constraint(equalToConstant: 180),

            listView.topAnchor.constraint(equalTo: actionsView.bottomAnchor, constant: 8),
            listView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            listView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            listView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.42),

            logView.topAnchor.constraint(equalTo: listView.bottomAnchor, constant: 8),
            logView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            logView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            logView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
        ])
    }

    private func seed() {
        listView.reset(makeRows(count: 8, prefix: "seed"))
        listView.total = listView.rowDatas.count
        log("seed \(listView.rowDatas.count) rows, cols=\(listView.numberOfColumns)")
    }

    private func snapshot() -> String {
        "rows=\(listView.numberOfRows) cols=\(listView.numberOfColumns) selected=\(listView.selectRows.count)"
    }

    private func log(_ message: String) {
        let line = "[\(shortTime)] \(message)\n"
        logView.text = (logView.text ?? "") + line
        let end = NSRange(location: max((logView.text as NSString).length - 1, 0), length: 1)
        logView.scrollRangeToVisible(end)
        listView.showNotice = message
    }

    private var shortTime: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }

    private func makeRows(count: Int, prefix: String) -> [LabRow] {
        (0 ..< count).map { index in
            seq += 1
            return LabRow(
                identifier: "\(prefix)-\(seq)",
                code: String(format: "C%03d", seq),
                title: "标题\(seq)",
                value: index.isMultiple(of: 3) ? String(repeating: "9", count: 12 + index) : "\(seq)",
                note: "note-\(seq)"
            )
        }
    }

    // MARK: Actions

    @objc private func actReset() {
        listView.isLoading = true
        listView.reset(makeRows(count: 10, prefix: "reset"))
        listView.isLoading = false
        listView.total = listView.rowDatas.count
        log("reset → \(snapshot())")
    }

    @objc private func actAppend() {
        listView.isLoading = true
        listView.append(makeRows(count: 5, prefix: "append"))
        listView.isLoading = false
        listView.total = listView.rowDatas.count
        log("append+isLoading → \(snapshot())")
    }

    @objc private func actUpdate() {
        guard var row = listView.rowDatas.first as? LabRow else { return }
        row.value = String(repeating: "W", count: 40)
        row.note = "updated"
        listView.update(at: 0, row)
        log("update(0) long value → \(snapshot())")
    }

    @objc private func actReplace() {
        let id = listView.selectRows.first ?? (listView.rowDatas.first as? LabRow)?.identifier
        guard let id,
              var row = listView.rowDatas.compactMap({ $0 as? LabRow }).first(where: { $0.identifier == id })
        else { return }
        row.title = "替换\(seq)"
        row.value = "R\(seq)"
        let ok = listView.replace(row)
        log("replace(\(id)) ok=\(ok) → \(snapshot())")
    }

    @objc private func actSetHeadersNarrow() {
        listView.setHeaders([.select, .code, .title, .value])
        log("setHeaders narrow → \(snapshot())")
    }

    @objc private func actSetHeadersFull() {
        listView.setHeaders(LabHeader.allCases)
        log("setHeaders full → \(snapshot())")
    }

    @objc private func actRecalculate() {
        listView.reloadData(immediate: true, widthPolicy: .recalculate)
        log("reloadData .recalculate → \(snapshot())")
    }

    @objc private func actKeep() {
        listView.reloadData(immediate: true, widthPolicy: .keep)
        log("reloadData .keep → \(snapshot())")
    }

    @objc private func actReconcile() {
        listView.reloadData(immediate: true, widthPolicy: .reconcile)
        log("reloadData .reconcile → \(snapshot())")
    }

    @objc private func actReloadCellWidth() {
        guard let column = listView.headers.firstIndex(of: .value),
              var row = listView.rowDatas.first as? LabRow
        else { return }
        row.value = String(repeating: "Q", count: 28)
        listView.update(at: 0, row)
        listView.reloadCellWidth(column)
        log("update+reloadCellWidth(value) → \(snapshot())")
    }

    @objc private func actClearMeta() {
        listView.clearSelection()
        listView.clearSorts()
        log("clearSelection + clearSorts → \(snapshot())")
    }

    @objc private func actDuplicateId() {
        let dup = LabRow(identifier: "dup", code: "DUP", title: "冲突A", value: "1", note: "a")
        let dup2 = LabRow(identifier: "dup", code: "DUP", title: "冲突B", value: String(repeating: "8", count: 20), note: "b")
        listView.reset([dup, dup2])
        log("duplicate id → \(snapshot())")
        listView.reset([LabRow(identifier: "dup", code: "DUP", title: "唯一", value: "3", note: "solo")])
        log("back to unique id → \(snapshot())")
    }

    // MARK: Delegate

    func listExcelView(
        _ excelView: ListExcelView<LabHeader>,
        headerContentAt header: LabHeader,
        column: Int
    ) -> Excel.Content? {
        header == .select ? .select : nil
    }

    func listExcelView(
        _ excelView: ListExcelView<LabHeader>,
        footerContentAt header: LabHeader,
        column: Int
    ) -> Excel.Content? {
        header == .title ? .text("\(listView.rowDatas.count) rows") : nil
    }

    func listExcelView(_ excelView: ListExcelView<LabHeader>, selectedRowsChanged identifiers: Set<String>) {
        log("selected=\(identifiers.count)")
    }

    func listExcelView(_ excelView: ListExcelView<LabHeader>, didSortAt column: Excel.SortColumn<LabHeader>?) {
        guard let column else { return }
        var rows = listView.rowDatas.compactMap { $0 as? LabRow }
        let asc = column.type == .ascending
        switch column.header {
            case .title: rows.sort { asc ? $0.title < $1.title : $0.title > $1.title }
            case .value: rows.sort { asc ? $0.value < $1.value : $0.value > $1.value }
            default: return
        }
        listView.reset(rows)
        log("sorted by \(column.header.title)")
    }

    func listExcelView(_ excelView: ListExcelView<LabHeader>, requestNext page: Int) {
        log("requestNext ignored in lab (page=\(page))")
    }
}
