//
//  DemoCatalogViewController.swift
//  ListExcelExample
//

import UIKit

/// 示例首页：分场景展示 ListExcel 能力。
final class DemoCatalogViewController: UITableViewController {
    private struct Item {
        let title: String
        let subtitle: String
        let make: () -> UIViewController
    }

    private struct Section {
        let title: String
        let items: [Item]
    }

    private lazy var sections: [Section] = [
        Section(title: "业务场景", items: [
            Item(
                title: "订单列表",
                subtitle: "锁列 · 排序 · 多选 · 分页 · 筛选 · 合计 · 批量操作",
                make: { OrdersDemoViewController() }
            ),
            Item(
                title: "库存宽表（双锁列）",
                subtitle: "leading+trailing 锁定 · 横滑 · scrollToColumn",
                make: { DualLockDemoViewController() }
            ),
            Item(
                title: "可编辑报价单",
                subtitle: "TextField / CornerText · handleRow 回写 · replace",
                make: { EditableDemoViewController() }
            ),
            Item(
                title: "媒体与行高",
                subtitle: "Image 列 · Icon 表头切换放大行高 · 斑马纹",
                make: { MediaDemoViewController() }
            ),
        ]),
        Section(title: "能力对照", items: [
            Item(
                title: "Content 画廊",
                subtitle: "decimals / cornerDecimal / cornerTextField / hiddenZero",
                make: { ContentGalleryDemoViewController() }
            ),
            Item(
                title: "选中形态",
                subtitle: "selectionType：none / cell / row / rowSelection",
                make: { SelectionTypesDemoViewController() }
            ),
            Item(
                title: "Delegate 内容回退",
                subtitle: "Header.content≡nil → contentAt / header / footerSumTitle",
                make: { DelegateFallbackDemoViewController() }
            ),
            Item(
                title: "局部刷新与定位",
                subtitle: "reloadCell / reloadCells / scrollToMatrix / reloadHeader",
                make: { LocalRefreshDemoViewController() }
            ),
            Item(
                title: "Orphan 行模型",
                subtitle: "plain / class / 重复 id → 列宽 orphan 路径",
                make: { OrphanRowsDemoViewController() }
            ),
            Item(
                title: "配置与合计栏",
                subtitle: "showsTotalView · totalText · sortHintText",
                make: { ConfigChromeDemoViewController() }
            ),
            Item(
                title: "自定义 Cell",
                subtitle: "init(cellClasses:) 覆盖 TextCell",
                make: { CustomCellDemoViewController() }
            ),
            Item(
                title: "纯 Excel 引擎",
                subtitle: "不用 ListExcelView，直接 Excel + ExcelDelegate",
                make: { PureExcelDemoViewController() }
            ),
        ]),
        Section(title: "调试", items: [
            Item(
                title: "写入 API 实验室",
                subtitle: "setHeaders / reset / append / update / replace / 列宽策略",
                make: { MutationLabViewController() }
            ),
        ]),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "ListExcel Examples"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "unused")
        tableView.tableFooterView = UIView()
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].items.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = sections[indexPath.section].items[indexPath.row]
        let cell: UITableViewCell
        if let reused = tableView.dequeueReusableCell(withIdentifier: "cell") {
            cell = reused
        } else {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        }
        if #available(iOS 14.0, *) {
            var config = cell.defaultContentConfiguration()
            config.text = item.title
            config.secondaryText = item.subtitle
            cell.contentConfiguration = config
        } else {
            cell.textLabel?.text = item.title
            cell.detailTextLabel?.text = item.subtitle
            cell.detailTextLabel?.numberOfLines = 2
        }
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = sections[indexPath.section].items[indexPath.row]
        let vc = item.make()
        vc.title = item.title
        navigationController?.pushViewController(vc, animated: true)
    }
}
