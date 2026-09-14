//
//  ListExcelView.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

public class ListExcelView<T>: UIView where T: Excel.Header {
    private let cellClasses: [Excel.Cell.ClassType: Excel.Cell.Type]
    private lazy var excelBridge = ListExcelExcelBridge(owner: self)
    lazy var excelView = Excel(
        delegate: excelBridge,
        configuration: configuration.excel,
        cellClasses: cellClasses
    )
    public let totalView = ListExcelTotalView()
    var canLoadMore = true
    let bottomNoticeLabel = UILabel()
    let currentSortLabel = UILabel()
    let clearSortButton = NormalButton(title: "")

    public weak var delegate: (any ListExcelDelegate<T>)?

    /// 列表配置（对外只读）。写入请用 `mutateConfiguration` / `reload`。
    public internal(set) var configuration: Configuration

    /// 在 `hasPermission` 之后的额外列过滤；仅初始化注入，之后不可改。
    public let customHeadersFilter: (T) -> Bool

    // 列宽权威结果（向上取整 / clamp 后）
    var widths: [CGFloat] = []
    // 列宽增量缓存（见 ListExcelView+ColumnWidth）
    var contentWidthCache: [ContentWidthKey: CGFloat] = [:]
    var rowColumnWidths: [RowWidthKey: [Int: CGFloat]] = [:]
    var orphanRowContributions: [Int: [Int: CGFloat]] = [:]
    var headerColumnWidths: [Int: CGFloat] = [:]
    var footerColumnWidths: [Int: CGFloat] = [:]
    var rowContentFingerprints: [RowWidthKey: [ContentWidthKey?]] = [:]
    var modelIdCounts: [String: Int] = [:]

    enum PendingUIRefresh {
        case none
        case fullReconcile
    }

    var pendingUIRefresh: PendingUIRefresh = .none
    var reloadDebouncer = Debouncer(interval: 0.1)
    /// 当前可见列（赋值路径会按 `hasPermission` + `customHeadersFilter` 过滤）。
    public internal(set) var headers: [T] = []
    public internal(set) var rowDatas: [any Excel.RowModel] = []

    // Excel 布局（由 configuration 驱动；锁列数经 clamp，保证 leading+trailing ≤ 列数）
    var leadingLockCount: Int { configuration.excel.leadingLockCount }
    var trailingLockCount: Int { configuration.excel.trailingLockCount }
    var headerHeight: CGFloat { configuration.excel.headerHeight }
    var footerHeight: CGFloat { configuration.excel.footerHeight }
    var rowHeight: CGFloat { configuration.resolvedRowHeight }

    // 表格数据
    public var total: Int = 0 {
        didSet {
            totalView.resetTotalText(configuration.resolvedTotalText(for: total))
        }
    }

    public var page: Int = 0
    /// 分页 / 请求中为 `true` 时，写入 API / `reloadData` / `reload` 的表格刷新会推迟到恢复为 `false`。
    /// 推荐顺序：`isLoading = true` → `append`/`reset`/… → `isLoading = false`（结束走一次整表对齐）。
    public var isLoading = false {
        didSet {
            if !isLoading, pendingUIRefresh == .fullReconcile {
                pendingUIRefresh = .none
                performResetStyleUIRefresh()
            }
        }
    }

    // selection 控制
    public internal(set) var selectRows: Set<String> = [] {
        didSet {
            delegate?.listExcelView(self, selectedRowsChanged: selectRows)
        }
    }

    public internal(set) var sortColumn: Excel.SortColumn<T>? {
        didSet {
            if let sortColumn, !containsSortColumn(sortColumn) {
                self.sortColumn = nil
                return
            }
            currentSortLabel.text = nil
            currentSortLabel.isHidden = true
            clearSortButton.isHidden = true
            if configuration.showsSortHint, let sortColumn {
                currentSortLabel.text = configuration.resolvedSortHint(for: sortColumn)
                currentSortLabel.isHidden = false
                clearSortButton.isHidden = false
            }
            setNeedsLayout()
        }
    }

    public var showNotice: String? {
        didSet {
            bottomNoticeLabel.isHidden = true
            if let showNotice {
                bottomNoticeLabel.isHidden = false
                bottomNoticeLabel.text = showNotice
            }
            setNeedsLayout()
        }
    }

    /// - Parameters:
    ///   - cellClasses: 覆盖默认 `ClassType` → Cell 映射（仅初始化生效，之后不可改）
    ///   - customHeadersFilter: `hasPermission` 之后的额外列过滤（仅初始化生效）
    public init(frame: CGRect = .zero, configuration: Configuration = .init(), cellClasses: [Excel.Cell.ClassType: Excel.Cell.Type] = [:], customHeadersFilter: @escaping (T) -> Bool = { _ in true }) {
        self.configuration = configuration
        self.cellClasses = cellClasses
        self.customHeadersFilter = customHeadersFilter
        super.init(frame: frame)
        addSubview(excelView)
        addSubview(totalView)
        totalView.lex_borderPosition = .top

        bottomNoticeLabel.isHidden = true
        bottomNoticeLabel.font = .default
        bottomNoticeLabel.textColor = .textLight

        currentSortLabel.isHidden = true
        currentSortLabel.font = .default
        currentSortLabel.textColor = .textLight

        clearSortButton.isHidden = true
        clearSortButton.lex_tapBlock = { [weak self] _ in
            self?.clearSorts()
        }
        // 中间可横滑区域：排序提示 / 清除 / notice；左右由 ListExcelTotalView 固定 action 与合计/指示器
        totalView.leadingAccessoryViews = [currentSortLabel, clearSortButton, bottomNoticeLabel]
        syncListChrome()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let totalViewHeight = totalView.isHidden ? 0 : totalView.height
        excelView.frame = bounds.inset(by: safeAreaInsets.withBottom(totalViewHeight + safeAreaInsets.bottom))
        totalView.frame = .init(0, excelView.bottom, excelView.width, totalView.height)
        // 排序 / notice 显隐变化后让 totalView 重排中间可滑附属视图
        if !currentSortLabel.isHidden {
            currentSortLabel.sizeToFit()
            clearSortButton.sizeToFit()
        }
        if !bottomNoticeLabel.isHidden {
            bottomNoticeLabel.sizeToFit()
        }
        totalView.setNeedsLayout()
    }
    
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        super.sizeThatFits(size)
        let totalViewHeight = totalView.isHidden ? 0 : totalView.height
        let tableHeaderViewHeight = tableView.tableHeaderView?.height ?? 0
        let realContentSize = tableHeaderViewHeight + headerHeight + rowHeight * CGFloat(numberOfRows) + footerHeight + totalViewHeight
        return .init(min(size.width, .screenWidth), realContentSize)
    }
    
    public var tableView: UITableView {
        excelView.contentView
    }

    public var headerView: UIView { excelView.headerView }
    public var footerView: UIView { excelView.footerView }

    public var visibleCells: [Excel.Cell] { excelView.visibleCells }
    public var matrixsForVisible: [Excel.Matrix] { excelView.matrixsForVisible }

    public func matrix(for cell: Excel.Cell) -> Excel.Matrix? {
        excelView.matrix(for: cell)
    }

    public func cellForMatrix(at matrix: Excel.Matrix) -> Excel.Cell? {
        excelView.cellForMatrix(at: matrix)
    }

    public func scrollToTop() {
        tableView.lex_scrollToTop()
    }
    
    public func resetContentOffset() {
        excelView.resetContentOffset()
    }

    public func scrollToColumn(at column: Int, animated: Bool = true) {
        excelView.scrollToColumn(at: column, animated: animated)
    }
    
    public func scrollToMatrix(at matrix: Excel.Matrix, animated: Bool = true) {
        excelView.scrollToMatrix(at: matrix, animated: animated)
    }



    public var numberOfRows: Int {
        rowDatas.count
    }

    public var numberOfColumns: Int {
        headers.count
    }
}
