//
//  ConfigChromeDemoViewController.swift
//  ListExcelExample
//

import ListExcel
import UIKit

enum ChromeHeader: String, CaseIterable, Excel.Header {
    case name
    case score

    var title: String { self == .name ? "名称" : "分数" }
    var sortBy: String { self == .score ? "score" : "" }

    func content(for model: Excel.RowModel, row: Int) -> Excel.Content? {
        guard let item = model as? ChromeRow else { return nil }
        return self == .name ? .text(item.name) : .decimal(item.score, .decimal)
    }
}

struct ChromeRow: Excel.RowModel, Excel.ModelIdentifier {
    var identifier: String
    var name: String
    var score: Decimal
}

/// 对照 `showsTotalView` / `totalText` / `sortHintText`。
final class ConfigChromeDemoViewController: UIViewController, ListExcelDataSource, ListExcelCellHandling, ListExcelInteractionDelegate {
    typealias T = ChromeHeader

    private let listView = ListExcelView<ChromeHeader>()
    private let bar = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureBar()
        configureList()
        layout()
        reloadSeed()
    }

    private func configureBar() {
        bar.axis = .horizontal
        bar.distribution = .fillEqually
        bar.spacing = 6
        [
            ("切换合计栏", #selector(toggleTotal)),
            ("自定义文案", #selector(applyCustomProviders)),
            ("恢复默认", #selector(applyDefaultProviders)),
        ].forEach { title, sel in
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.addTarget(self, action: sel, for: .touchUpInside)
            bar.addArrangedSubview(button)
        }
        view.addSubview(bar)
    }

    private func configureList() {
        var configuration = ListExcelView<ChromeHeader>.Configuration()
        configuration.excel.headerHeight = 40
        configuration.excel.rowHeight = 44
        configuration.showsTotalView = true
        configuration.showsSortHint = true
        listView.configuration = configuration
        listView.applyConfiguration()
        listView.delegate = self
        listView.setHeaders(ChromeHeader.allCases)
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

    private func reloadSeed() {
        listView.reset((0 ..< 12).map {
            ChromeRow(identifier: "ch-\($0)", name: "项 \($0 + 1)", score: Decimal(60 + $0 * 3))
        })
        listView.total = listView.rowDatas.count
        listView.showNotice = "点分数表头看 sortHint；切换合计栏显隐"
    }

    @objc private func toggleTotal() {
        listView.configuration.showsTotalView.toggle()
        listView.applyConfiguration()
        listView.showNotice = listView.configuration.showsTotalView ? "showsTotalView=true" : "showsTotalView=false"
    }

    @objc private func applyCustomProviders() {
        listView.configuration.totalText = .custom { "共 \($0) 条 · Demo" }
        listView.configuration.sortHintText = .custom { column in
            "排序:\(column.header.title)/\(column.type.rawValue)"
        }
        listView.configuration.clearSortTitle = .custom("清排序")
        listView.applyConfiguration()
        listView.total = listView.rowDatas.count
        listView.showNotice = "已套用自定义 total/sortHint"
    }

    @objc private func applyDefaultProviders() {
        listView.configuration.totalText = .localeDefault
        listView.configuration.sortHintText = .localeDefault
        listView.configuration.clearSortTitle = .localeDefault
        listView.applyConfiguration()
        listView.total = listView.rowDatas.count
        listView.showNotice = "已恢复默认 LocalizedText"
    }

    func listExcelView(_ excelView: ListExcelView<ChromeHeader>, didSortAt column: Excel.SortColumn<ChromeHeader>?) {
        guard let column, column.header == .score else { return }
        var rows = listView.rowDatas.compactMap { $0 as? ChromeRow }
        let asc = column.type == .ascending
        rows.sort { asc ? $0.score < $1.score : $0.score > $1.score }
        listView.reset(rows)
    }
}
