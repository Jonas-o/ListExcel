//
//  ListExcelView.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

/// 面向业务的列表视图：表头 / 内容行 / 表尾、列宽、排序、多选、底栏与分页钩子。
///
/// 数据写入优先 ``reload(readsCache:_:)`` / ``append(_:)``；配置写入用 ``mutateConfiguration``。
/// 交互与内容经 ``ListExcelDelegate``；可选 ``ListExcelCacheStore`` 做列布局缓存。
public class ListExcelView<T>: UIView where T: Excel.Header {
    private let cellClasses: [Excel.Cell.ClassType: Excel.Cell.Type]
    private lazy var excelBridge = ListExcelExcelBridge(owner: self)
    lazy var excelView = Excel(
        delegate: excelBridge,
        configuration: configuration.excel,
        cellClasses: cellClasses
    )
    /// 底部合计栏（合计文案、指示器、左侧操作按钮，以及排序提示等中间附属视图）。
    public let totalView = ListExcelTotalView()
    var canLoadMore = true
    let bottomNoticeLabel = UILabel()
    let currentSortLabel = UILabel()
    let clearSortButton = NormalButton(title: "")

    /// 数据源 + Cell 处理 + 交互。须由宿主强持有（弱引用）。
    public weak var delegate: (any ListExcelDelegate<T>)?

    /// 可选列布局缓存。弱引用，须由宿主强持有实现对象。
    ///
    /// - `reload(readsCache: true)`：闭包未写的表头 / 排序 / 锁列 / 排序提示与放大开关从 store 读取。
    /// - 点排序、``clearSorts()``、图片列放大：包调用 store 的 `save*`。
    /// - ``validatedSortColumn()``：按 store 校验请求用排序，不刷新界面。
    ///
    /// 为 `nil` 时上述读写均跳过。切换多份缓存时改此指针即可。
    public weak var cacheStore: (any ListExcelCacheStore<T>)?
    var headerLongPressTarget: ListExcelHeaderLongPressTarget?

    /// 列表配置（对外只读）。写入请用 ``mutateConfiguration`` / ``reload(readsCache:_:)``。
    public internal(set) var configuration: Configuration

    /// 在 `hasPermission` 之后的额外列过滤；仅初始化注入，之后不可改。
    public let customHeadersFilter: (T) -> Bool

    // MARK: - 列宽缓存（见 ListExcelView+ColumnWidth；权威结果为 `widths`）

    /// 当前各列最终宽度（ceil + min/max clamp 后）。引擎与公开查询均以此为准。
    var widths: [CGFloat] = []
    /// Content 量字结果缓存：键含文案指纹 + 字体 + padding/spacing + locale。
    /// `select` / `image` 不进此字典；换表头 / 测宽 metrics 变化时随 `invalidateWidthCache` 清空。
    var contentWidthCache: [ContentWidthKey: CGFloat] = [:]
    /// 稳定行键 → 该行对各列的宽度贡献。仅 `uniqueRowWidthKey` 非 nil 时写入。
    var rowColumnWidths: [RowWidthKey: [Int: CGFloat]] = [:]
    /// 无稳定键或同 id 冲突的行：按下标存贡献。下标随 `rowDatas` 变化，须在 diff / append 时重算。
    var orphanRowContributions: [Int: [Int: CGFloat]] = [:]
    /// 表头各列量字贡献（含可排序列额外 chrome）。
    var headerColumnWidths: [Int: CGFloat] = [:]
    /// 表尾各列量字贡献（跳过 select / image）。
    var footerColumnWidths: [Int: CGFloat] = [:]
    /// 稳定行键 → 各列 `ContentWidthKey?` 指纹，供 `applyResetDiff` 判断能否复用 `rowColumnWidths`。
    var rowContentFingerprints: [RowWidthKey: [ContentWidthKey?]] = [:]
    /// `ModelIdentifier.identifier` → 出现次数。`> 1` 时该 id 不能进 `rowColumnWidths`（改走 orphan）。
    var modelIdCounts: [String: Int] = [:]

    enum PendingUIRefresh {
        case none
        case fullReconcile
    }

    var pendingUIRefresh: PendingUIRefresh = .none
    var reloadDebouncer = Debouncer(interval: 0.1)
    /// 当前可见列（经 `hasPermission` + `customHeadersFilter` 投影）。写入请用 ``reload(readsCache:_:)`` 的 `Batch.headers`。
    public internal(set) var headers: [T] = []
    /// 当前内容行。写入请用 ``reload(readsCache:_:)`` 的 `Batch.rowDatas` 或 ``append(_:)``。
    public internal(set) var rowDatas: [any Excel.RowModel] = []

    // Excel 布局（由 configuration 驱动；锁列数经 clamp，保证 leading+trailing ≤ 列数）
    var leadingLockCount: Int { configuration.excel.leadingLockCount }
    var trailingLockCount: Int { configuration.excel.trailingLockCount }
    var headerHeight: CGFloat { configuration.excel.headerHeight }
    var footerHeight: CGFloat { configuration.excel.footerHeight }
    var rowHeight: CGFloat { configuration.resolvedRowHeight }

    /// 总条数；驱动底栏合计文案（见 ``Configuration/totalText``）。可直接赋值，或经 `Batch.total` 写入。
    public var total: Int = 0 {
        didSet {
            totalView.resetTotalText(configuration.resolvedTotalText(for: total))
        }
    }

    /// 当前已加载到的页码（宿主维护；触底回调参数为 `page + 1`）。
    public var page: Int = 0
    /// 分页 / 请求中为 `true` 时，写入 API / `reloadData` / `reload` 的表格刷新会推迟到恢复为 `false`。
    /// 推荐顺序：`isLoading = true` → `append` / `reload` → `isLoading = false`（结束走一次整表对齐）。
    public var isLoading = false {
        didSet {
            if !isLoading, pendingUIRefresh == .fullReconcile {
                pendingUIRefresh = .none
                performResetStyleUIRefresh()
            }
        }
    }

    /// 当前多选集合；元素为 `Excel.ModelIdentifier.identifier`。变化时回调 ``ListExcelInteractionDelegate/listExcelView(_:selectedRowsChanged:)``。
    public internal(set) var selectRows: Set<String> = [] {
        didSet {
            delegate?.listExcelView(self, selectedRowsChanged: selectRows)
        }
    }

    /// 当前排序。不在可见列内会被自动清空。写入优先 ``reload`` 的 `Batch.sortColumn`，或由用户点表头 / ``clearSorts()`` 改变。
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

    /// 底栏中间区域的提示文案（与排序提示并列）。`nil` 隐藏。
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
    ///   - frame: 初始 frame；通常随后由 Auto Layout / `layoutSubviews` 覆盖。
    ///   - configuration: 初始配置副本。
    ///   - cellClasses: 覆盖默认 `ClassType` → Cell 映射（仅初始化生效，之后不可改）。
    ///   - customHeadersFilter: `hasPermission` 之后的额外列过滤（仅初始化生效）。
    public init(frame: CGRect = .zero, configuration: Configuration = .init(), cellClasses: [Excel.Cell.ClassType: Excel.Cell.Type] = [:], customHeadersFilter: @escaping (T) -> Bool = { _ in true }) {
        self.configuration = configuration
        self.cellClasses = cellClasses
        self.customHeadersFilter = customHeadersFilter
        super.init(frame: frame)
        addSubview(excelView)
        addSubview(totalView)
        installHeaderLongPress()
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

    /// 底层纵向 `UITableView`（可设 `tableHeaderView` 等）。
    public var tableView: UITableView {
        excelView.contentView
    }

    /// 表头行视图（含列集合；可挂额外手势，包已内置长按转发）。
    public var headerView: UIView { excelView.headerView }
    /// 表尾行视图。
    public var footerView: UIView { excelView.footerView }

    /// 当前可见的矩阵 Cell（含表头 / 表尾可见部分）。
    public var visibleCells: [Excel.Cell] { excelView.visibleCells }
    /// 与 `visibleCells` 对应的矩阵坐标。
    public var matrixsForVisible: [Excel.Matrix] { excelView.matrixsForVisible }

    /// 由可见 Cell 反查矩阵坐标；不在可见区域时可能为 `nil`。
    public func matrix(for cell: Excel.Cell) -> Excel.Matrix? {
        excelView.matrix(for: cell)
    }

    /// 取指定矩阵上的可见 Cell；不可见时为 `nil`。
    public func cellForMatrix(at matrix: Excel.Matrix) -> Excel.Cell? {
        excelView.cellForMatrix(at: matrix)
    }

    /// 纵向滚到顶部。
    public func scrollToTop() {
        tableView.lex_scrollToTop()
    }

    /// 将各行横向滚动偏移重置为 0（与表头 / 表尾对齐）。
    public func resetContentOffset() {
        excelView.resetContentOffset()
    }

    /// 横向滚到指定列（带动画可选）。
    public func scrollToColumn(at column: Int, animated: Bool = true) {
        excelView.scrollToColumn(at: column, animated: animated)
    }

    /// 滚到指定矩阵：横向对齐列，纵向对齐内容行（若为 `.cell`）。
    public func scrollToMatrix(at matrix: Excel.Matrix, animated: Bool = true) {
        excelView.scrollToMatrix(at: matrix, animated: animated)
    }

    /// 内容行数（不含表头 / 表尾）。
    public var numberOfRows: Int {
        rowDatas.count
    }

    /// 可见列数。
    public var numberOfColumns: Int {
        headers.count
    }
}
