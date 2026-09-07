//
//  PureExcelDemoViewController.swift
//  ListExcelExample
//

import ListExcel
import UIKit

/// 不经过 `ListExcelView`，直接使用底层 `Excel`。
final class PureExcelDemoViewController: UIViewController, ExcelDelegate {
    private var excelView: Excel!

    private let titles = ["锁列", "A", "B", "C", "D"]
    private var rows: [[String]] = (0 ..< 25).map { i in
        ["#\(i)", "A\(i)", "B\(i)", String(repeating: "C", count: i % 8 + 1), "D\(i)"]
    }

    func numberOfRows(in excel: Excel) -> Int { rows.count }
    func numberOfColumns(in excel: Excel) -> Int { titles.count }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "加一行",
            style: .plain,
            target: self,
            action: #selector(appendRow)
        )

        var configuration = Excel.Configuration()
        configuration.headerHeight = 44
        configuration.footerHeight = 36
        configuration.rowHeight = 44
        configuration.leadingLockCount = 1
        configuration.trailingLockCount = 0

        let excel = Excel(delegate: self, configuration: configuration)
        excel.selectionType = .cell()
        view.addSubview(excel)
        excelView = excel
        excel.reloadData()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        excelView?.frame = view.safeAreaLayoutGuide.layoutFrame
    }

    @objc private func appendRow() {
        let i = rows.count
        rows.append(["#\(i)", "A\(i)", "B\(i)", "C\(i)", "D\(i)"])
        excelView.insertRows(at: [IndexPath(row: i, section: 0)], with: .automatic)
    }

    func excel(_ excel: Excel, columnWidthAt column: Int) -> CGFloat {
        column == 0 ? 56 : (column == 3 ? 120 : 72)
    }

    func excel(_ excel: Excel, dequeueReusableCellAt matrix: Excel.Matrix) -> Excel.Cell.ClassType? {
        matrix.row.isHeader ? .headerText : .text
    }

    func excel(_ excel: Excel, handle cell: some Excel.Cell, at matrix: Excel.Matrix) {
        let text: String?
        switch matrix.row {
            case .header: text = titles[matrix.column]
            case .footer: text = matrix.column == 0 ? "合计" : "\(rows.count)"
            case let .cell(row): text = rows[row][matrix.column]
        }
        cell.bindContent(.text(text), context: .init(textAlignment: .center))
    }

    func excel(_ excel: Excel, backgroundColorAt row: Excel.Matrix.Row) -> UIColor? {
        if case let .cell(index) = row, index.isMultiple(of: 2) {
            return UIColor.secondarySystemBackground
        }
        return nil
    }
}
