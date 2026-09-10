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
    public let totalView = ExcelTotalView()
    var canLoadMore = true
    private let bottomNoticeLabel = UILabel()
    private let currentSortLabel = UILabel()
    private let clearSortButton = NormalButton(title: "")

    public weak var delegate: (any ListExcelDelegate<T>)?

    /// 列表配置（对外只读）。写入请用 `applyConfiguration` / `mutateConfiguration` / `reload`。
    public internal(set) var configuration: Configuration

    // 列宽权威结果（向上取整 / clamp 后）
    var widths: [CGFloat] = []
    // 列宽增量缓存（见 ListExcelView+ColumnWidthCache）
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
    private var reloadDebouncer = Debouncer(interval: 0.1)
    public internal(set) var headers: [T] = []
    public internal(set) var rowDatas: [any Excel.RowModel] = []

    // Excel 布局（由 configuration 驱动）
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
    /// 分页 / 请求中为 `true` 时，写入 API / `reloadData` / `applyConfiguration` 的表格刷新会推迟到恢复为 `false`。
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
    public init(
        frame: CGRect = .zero,
        configuration: Configuration = .init(),
        cellClasses: [Excel.Cell.ClassType: Excel.Cell.Type] = [:]
    ) {
        self.configuration = configuration
        self.cellClasses = cellClasses
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
        // 中间可横滑区域：排序提示 / 清除 / notice；左右由 ExcelTotalView 固定 action 与合计/指示器
        totalView.leadingAccessoryViews = [currentSortLabel, clearSortButton, bottomNoticeLabel]
        syncListChrome()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 应用配置并刷新表格。传入新配置会先写入 `configuration`；不传则用当前值。
    /// 列表附属 UI（合计栏文案等）立即同步；表格刷新与 `reloadData` 相同，受 `isLoading` 门闩约束。
    public func applyConfiguration(_ configuration: Configuration? = nil) {
        if let configuration {
            self.configuration = configuration
        }
        syncListChrome()
        setNeedsLayout()
        invalidateWidthCache()
        reloadData(immediate: true, widthPolicy: .recalculate)
    }

    /// 在当前配置上批改后调用 ``applyConfiguration(_:)``，适合宿主改若干字段。
    public func mutateConfiguration(_ update: (inout Configuration) -> Void) {
        var configuration = configuration
        update(&configuration)
        applyConfiguration(configuration)
    }

    func syncListChrome() {
        var excelConfiguration = configuration.excel
        // enlargeImageRows 时把解析后的行高写入引擎，避免再依赖 Delegate 属性
        excelConfiguration.rowHeight = configuration.resolvedRowHeight
        excelView.configuration = excelConfiguration
        excelView.syncSelectionTypeToVisibleCells()
        clearSortButton.setTitle(configuration.resolvedClearSortTitle(), for: .normal)
        totalView.isHidden = !configuration.showsTotalView
        totalView.resetTotalText(configuration.resolvedTotalText(for: total))
        bottomNoticeLabel.font = configuration.excel.rowFont
        bottomNoticeLabel.textColor = configuration.excel.textColor.withAlphaComponent(0.6)
        currentSortLabel.font = configuration.excel.rowFont
        currentSortLabel.textColor = configuration.excel.textColor.withAlphaComponent(0.6)
        let current = sortColumn
        sortColumn = current
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

    /// 刷新表格。宿主无参调用默认全量重算列宽（`.recalculate`）。
    /// `isLoading == true` 时只标记待刷新，待加载结束后以 `.keep` 整表对齐。
    /// - Parameter immediate: `true` 跳过防抖立刻执行；连续调用时默认防抖合并（0.1s）。
    /// - Parameter widthPolicy: `.recalculate`（默认）/ `.keep` / `.reconcile`。
    public func reloadData(immediate: Bool = false, widthPolicy: ColumnWidthPolicy = .recalculate) {
        guard !isLoading else {
            pendingUIRefresh = .fullReconcile
            return
        }
        pendingUIRefresh = .none
        reloadDebouncer.perform(immediate: immediate) { [weak self] in
            guard let self else { return }
            switch widthPolicy {
                case .recalculate:
                    self.calculateColumnWidths()
                case .keep:
                    if self.widths.count != self.headers.count {
                        self.calculateColumnWidths()
                    }
                case .reconcile:
                    self.measureHeaderFooter()
                    self.recomputeWidthsFromRowContributions()
            }
            self.excelView.reloadData()
        }
    }

    public func reloadHeader() {
        excelView.reloadHeader()
    }

    public func reloadFooter() {
        excelView.reloadFooter()
    }
    
    /// 仅刷新内容，不涉及宽度变化
    public func reloadCell(at matrix: Excel.Matrix) {
        excelView.reloadCell(at: matrix)
    }
    
    /// 仅刷新内容，不涉及宽度变化
    public func reloadCells(at matrixs: [Excel.Matrix]) {
        excelView.reloadCells(at: matrixs)
    }

    /// 单列重算并同步到 Excel。不完整重建行级增量缓存；需严格一致时请 `reloadData()`。
    public func reloadCellWidth(_ column: Int, row: Excel.Matrix.Row? = nil) {
        guard
            widths.count == headers.count,
            0 ..< widths.count ~= column
        else {
            reloadData(immediate: true, widthPolicy: .recalculate)
            return
        }
        widths[column] = calculateColumnWidth(column)
        excelView.reloadColumnWidth(column, reason: row)
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
