//
//  MediaDemoViewController.swift
//  ListExcelExample
//

import ListExcel
import UIKit

enum MediaHeader: String, CaseIterable, Excel.Header {
    case thumb
    case title
    case category
    case score
    case views

    var title: String {
        switch self {
            case .thumb: return "封面"
            case .title: return "标题"
            case .category: return "分类"
            case .score: return "评分"
            case .views: return "阅读"
        }
    }

    var sortBy: String {
        switch self {
            case .score, .views, .title: return rawValue
            default: return ""
        }
    }

    func content(for model: Excel.RowModel, row: Int) -> Excel.Content? {
        guard let item = model as? MediaRow else { return nil }
        switch self {
            case .thumb: return .image
            case .title: return .text(item.title)
            case .category: return .iconText(.custom(item.badge), item.category)
            case .score: return .decimal(item.score, .decimal)
            case .views: return .decimal(Decimal(item.views), .none)
        }
    }
}

struct MediaRow: Excel.RowModel, Excel.ModelIdentifier {
    var identifier: String
    var title: String
    var category: String
    var score: Decimal
    var views: Int
    var color: UIColor
    var badge: UIImage
}

enum MediaFactory {
    static func rows() -> [MediaRow] {
        let colors: [UIColor] = [.systemBlue, .systemPink, .systemTeal, .systemIndigo, .systemOrange, .systemPurple]
        let cats = ["设计", "工程", "增长", "运营"]
        return (0 ..< 24).map { index in
            let color = colors[index % colors.count]
            return MediaRow(
                identifier: "media-\(index)",
                title: "案例稿 \(index + 1)：ListExcel 横滑与锁列实践",
                category: cats[index % cats.count],
                score: Decimal(75 + index % 20) / 10,
                views: 120 + index * 37,
                color: color,
                badge: DemoImageFactory.swatch(color, size: CGSize(width: 12, height: 12), corner: 6)
            )
        }
    }
}

final class MediaDemoViewController: UIViewController, ListExcelDataSource, ListExcelCellHandling, ListExcelInteractionDelegate {
    typealias T = MediaHeader

    private let listView = ListExcelView<MediaHeader>()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "切换行高",
            style: .plain,
            target: self,
            action: #selector(toggleRowHeight)
        )

        var configuration = ListExcelView<MediaHeader>.Configuration()
        configuration.excel.headerHeight = 44
        configuration.excel.footerHeight = 0
        configuration.excel.rowHeight = 44
        configuration.excel.enlargedRowHeight = 72
        configuration.excel.leadingLockCount = 1
        configuration.showsTotalView = true
        configuration.showsSortHint = true
        configuration.excel.selectionType = .row()

        listView.applyConfiguration(configuration)
        listView.delegate = self
        listView.setHeaders(MediaHeader.allCases)
        listView.reset(MediaFactory.rows())
        listView.total = listView.rowDatas.count
        listView.showNotice = "点封面列表头图标可切换放大行高"
        view.addSubview(listView)

        listView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            listView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            listView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            listView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            listView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    @objc private func toggleRowHeight() {
        // 与点 icon 表头等价
        listView.configuration.enlargeImageRows.toggle()
        listView.applyConfiguration()
        listView.showNotice = listView.configuration.enlargeImageRows ? "已放大行高" : "已恢复行高"
    }

    func listExcelView(
        _ excelView: ListExcelView<MediaHeader>,
        headerContentAt header: MediaHeader,
        column: Int
    ) -> Excel.Content? {
        // 图片列头用 iconText，点击可切换 enlargeImageRows
        header == .thumb ? .iconText(.delete, nil) : nil
    }

    func listExcelView(
        _ excelView: ListExcelView<MediaHeader>,
        handleRow cell: some Excel.Cell,
        union: Excel.CellUnion<MediaHeader>
    ) {
        guard union.header == .thumb,
              let imageCell = cell as? Excel.ImageCell,
              let row = union.rowModel as? MediaRow
        else { return }
        imageCell.imageView.image = DemoImageFactory.swatch(row.color, size: CGSize(width: 40, height: 40), corner: 8)
        imageCell.imageView.contentMode = .scaleAspectFill
        imageCell.imageView.clipsToBounds = true
        imageCell.imageView.layer.cornerRadius = 8
    }

    func listExcelView(
        _ excelView: ListExcelView<MediaHeader>,
        backgroundColorAt row: Int,
        rowModel: Excel.RowModel
    ) -> UIColor? {
        row.isMultiple(of: 2) ? DemoPalette.zebra : nil
    }

    func listExcelView(_ excelView: ListExcelView<MediaHeader>, didSortAt column: Excel.SortColumn<MediaHeader>?) {
        guard let column else { return }
        var rows = listView.rowDatas.compactMap { $0 as? MediaRow }
        let asc = column.type == .ascending
        switch column.header {
            case .title: rows.sort { asc ? $0.title < $1.title : $0.title > $1.title }
            case .score: rows.sort { asc ? $0.score < $1.score : $0.score > $1.score }
            case .views: rows.sort { asc ? $0.views < $1.views : $0.views > $1.views }
            default: return
        }
        listView.reset(rows)
    }

    func listExcelView(
        _ excelView: ListExcelView<MediaHeader>,
        didSelectRowAt row: Int,
        rowModel: Excel.RowModel,
        column: Int?,
        header: MediaHeader?
    ) {
        guard let item = rowModel as? MediaRow else { return }
        listView.showNotice = "\(item.title) · \(header?.title ?? "")"
    }
}
