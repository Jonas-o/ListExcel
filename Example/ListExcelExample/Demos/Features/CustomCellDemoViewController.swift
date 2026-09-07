//
//  CustomCellDemoViewController.swift
//  ListExcelExample
//

import ListExcel
import UIKit

/// 自定义 TextCell：浅底 + 左侧色条。
final class BadgeTextCell: Excel.TextCell {
    private let stripe = UIView()

    override func initSubviews() {
        super.initSubviews()
        stripe.backgroundColor = .systemIndigo
        contentView.insertSubview(stripe, at: 0)
    }

    override func applyAppearance() {
        super.applyAppearance()
        contentView.backgroundColor = UIColor.systemIndigo.withAlphaComponent(0.06)
        textLabel.textColor = .systemIndigo
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        stripe.frame = CGRect(x: 0, y: 6, width: 3, height: contentView.bounds.height - 12)
        stripe.layer.cornerRadius = 1.5
    }
}

enum CustomHeader: String, CaseIterable, Excel.Header {
    case name
    case note

    var title: String { self == .name ? "名称" : "备注" }

    func content(for model: Excel.RowModel, row: Int) -> Excel.Content? {
        guard let item = model as? CustomRow else { return nil }
        return self == .name ? .text(item.name) : .text(item.note)
    }
}

struct CustomRow: Excel.RowModel, Excel.ModelIdentifier {
    var identifier: String
    var name: String
    var note: String
}

/// `cellClasses` 覆盖默认 TextCell。
final class CustomCellDemoViewController: UIViewController, ListExcelDataSource, ListExcelCellHandling, ListExcelInteractionDelegate {
    typealias T = CustomHeader

    private lazy var listView = ListExcelView<CustomHeader>(
        frame: .zero,
        configuration: {
            var configuration = ListExcelView<CustomHeader>.Configuration()
            configuration.excel.headerHeight = 44
            configuration.excel.rowHeight = 48
            configuration.showsTotalView = true
            return configuration
        }(),
        cellClasses: [
            .text: BadgeTextCell.self,
        ]
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        listView.applyConfiguration()
        listView.delegate = self
        listView.setHeaders(CustomHeader.allCases)
        listView.reset((0 ..< 16).map {
            CustomRow(identifier: "c-\($0)", name: "自定义 Cell \($0 + 1)", note: "BadgeTextCell 替换 .text")
        })
        listView.total = listView.rowDatas.count
        listView.showNotice = "init(cellClasses: [.text: BadgeTextCell.self])"
        view.addSubview(listView)
        listView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            listView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            listView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            listView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            listView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }
}
