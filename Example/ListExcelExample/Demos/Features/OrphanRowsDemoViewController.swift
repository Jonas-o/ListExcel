//
//  OrphanRowsDemoViewController.swift
//  ListExcelExample
//

import ListExcel
import UIKit

enum OrphanHeader: String, CaseIterable, Excel.Header {
    case kind
    case name
    case value

    var title: String {
        switch self {
            case .kind: return "类型"
            case .name: return "名称"
            case .value: return "值"
        }
    }

    func content(for model: Excel.RowModel, row: Int) -> Excel.Content? {
        if let row = model as? IdentRow {
            switch self {
                case .kind: return .text("id")
                case .name: return .text(row.name)
                case .value: return .text(row.value)
            }
        }
        if let row = model as? PlainRow {
            switch self {
                case .kind: return .text("plain")
                case .name: return .text(row.name)
                case .value: return .text(row.value)
            }
        }
        if let row = model as? ClassRow {
            switch self {
                case .kind: return .text("class")
                case .name: return .text(row.name)
                case .value: return .text(row.value)
            }
        }
        return nil
    }
}

struct IdentRow: Excel.RowModel, Excel.ModelIdentifier {
    var identifier: String
    var name: String
    var value: String
}

struct PlainRow: Excel.RowModel {
    var name: String
    var value: String
}

final class ClassRow: Excel.RowModel {
    var name: String
    var value: String
    init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

/// 无 ModelIdentifier / class 行 / 重复 id → orphan 列宽路径。
final class OrphanRowsDemoViewController: UIViewController, ListExcelDataSource, ListExcelCellHandling, ListExcelInteractionDelegate {
    typealias T = OrphanHeader

    private let listView = ListExcelView<OrphanHeader>()
    private let bar = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureBar()
        configureList()
        layout()
        seedMixed()
    }

    private func configureBar() {
        bar.axis = .horizontal
        bar.distribution = .fillEqually
        bar.spacing = 6
        [
            ("混合行", #selector(seedMixed)),
            ("重复 id", #selector(seedDup)),
            ("恢复唯一", #selector(seedUnique)),
            ("加长 plain", #selector(widenPlain)),
        ].forEach { title, sel in
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.addTarget(self, action: sel, for: .touchUpInside)
            bar.addArrangedSubview(button)
        }
        view.addSubview(bar)
    }

    private func configureList() {
        var configuration = ListExcelView<OrphanHeader>.Configuration()
        configuration.excel.headerHeight = 40
        configuration.excel.rowHeight = 44
        configuration.showsTotalView = true
        listView.configuration = configuration
        listView.applyConfiguration()
        listView.delegate = self
        listView.setHeaders(OrphanHeader.allCases)
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

    @objc private func seedMixed() {
        listView.reset([
            IdentRow(identifier: "1", name: "有 id", value: "10"),
            PlainRow(name: "无 id plain", value: "20"),
            ClassRow(name: "class 实例", value: "30"),
            IdentRow(identifier: "2", name: "有 id-2", value: "40"),
        ])
        listView.total = listView.rowDatas.count
        listView.showNotice = "mixed: id + plain + class（后两者走 orphan）"
    }

    @objc private func seedDup() {
        listView.reset([
            IdentRow(identifier: "dup", name: "冲突 A", value: "1"),
            IdentRow(identifier: "dup", name: "冲突 B", value: String(repeating: "8", count: 18)),
            PlainRow(name: "plain", value: "x"),
        ])
        listView.total = listView.rowDatas.count
        listView.showNotice = "同 id 冲突 → 字典降级 orphan"
    }

    @objc private func seedUnique() {
        listView.reset([
            IdentRow(identifier: "dup", name: "唯一", value: "solo"),
        ])
        listView.total = 1
        listView.showNotice = "冲突解除，id 重回唯一字典"
    }

    @objc private func widenPlain() {
        listView.append([
            PlainRow(name: "更长 plain 名称用于撑宽", value: String(repeating: "W", count: 24)),
        ])
        listView.total = listView.rowDatas.count
        listView.showNotice = "append plain → orphan 贡献加宽"
    }
}
