//
//  LocalRefreshDemoViewController.swift
//  ListExcelExample
//

import ListExcel
import UIKit

enum LocalHeader: String, CaseIterable, Excel.Header {
    case name
    case a
    case b
    case c

    var title: String { rawValue.uppercased() }

    func content(for model: Excel.RowModel, row: Int) -> Excel.Content? {
        guard let item = model as? LocalRow else { return nil }
        switch self {
            case .name: return .text(item.name)
            case .a: return .text(item.a)
            case .b: return .text(item.b)
            case .c: return .text(item.c)
        }
    }
}

struct LocalRow: Excel.RowModel, Excel.ModelIdentifier {
    var identifier: String
    var name: String
    var a: String
    var b: String
    var c: String
}

/// `reloadCell` / `reloadCells` / `scrollToMatrix` 局部刷新演示。
final class LocalRefreshDemoViewController: UIViewController, ListExcelDataSource, ListExcelCellHandling, ListExcelInteractionDelegate {
    typealias T = LocalHeader

    private let listView = ListExcelView<LocalHeader>()
    private let bar = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureBar()
        configureList()
        layout()
        listView.reset((0 ..< 30).map {
            LocalRow(identifier: "l-\($0)", name: "R\($0)", a: "a\($0)", b: "b\($0)", c: "c\($0)")
        })
        listView.total = listView.rowDatas.count
        listView.showNotice = "用下方按钮做局部刷新 / 定位"
    }

    private func configureBar() {
        bar.axis = .horizontal
        bar.spacing = 6
        bar.distribution = .fillEqually
        [
            ("刷单格", #selector(reloadOneCell)),
            ("刷多格", #selector(reloadManyCells)),
            ("滚到矩阵", #selector(scrollMatrix)),
            ("刷表头", #selector(reloadHeaderOnly)),
        ].forEach { title, sel in
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.addTarget(self, action: sel, for: .touchUpInside)
            bar.addArrangedSubview(button)
        }
        view.addSubview(bar)
    }

    private func configureList() {
        var configuration = ListExcelView<LocalHeader>.Configuration()
        configuration.excel.headerHeight = 40
        configuration.excel.rowHeight = 44
        configuration.excel.leadingLockCount = 1
        configuration.showsTotalView = true
        configuration.excel.selectionType = .cell()

        listView.applyConfiguration(configuration)
        listView.delegate = self
        listView.setHeaders(LocalHeader.allCases)
        view.addSubview(listView)
    }

    private func layout() {
        [bar, listView].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            bar.heightAnchor.constraint(equalToConstant: 36),

            listView.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 4),
            listView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            listView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            listView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    @objc private func reloadOneCell() {
        guard var row = listView.rowDatas.first as? LocalRow else { return }
        row.a = "A@\(Int(Date().timeIntervalSince1970) % 1000)"
        // 先改数据再局部刷：用 update 同步缓存，再演示 reloadCell
        listView.update(at: 0, row)
        listView.reloadCell(at: .init(column: 1, row: .cell(0)))
        listView.showNotice = "reloadCell (0, a)"
    }

    @objc private func reloadManyCells() {
        guard listView.rowDatas.count > 2 else { return }
        var r1 = listView.rowDatas[1] as! LocalRow
        var r2 = listView.rowDatas[2] as! LocalRow
        r1.b = "B*"
        r2.c = "C*"
        listView.update(at: 1, r1)
        listView.update(at: 2, r2)
        listView.reloadCells(at: [
            .init(column: 2, row: .cell(1)),
            .init(column: 3, row: .cell(2)),
        ])
        listView.showNotice = "reloadCells 两格"
    }

    @objc private func scrollMatrix() {
        let row = min(18, listView.rowDatas.count - 1)
        listView.scrollToMatrix(at: .init(column: 3, row: .cell(row)), animated: true)
        listView.showNotice = "scrollToMatrix col=c row=\(row)"
    }

    @objc private func reloadHeaderOnly() {
        listView.reloadHeader()
        listView.showNotice = "reloadHeader()"
    }
}
