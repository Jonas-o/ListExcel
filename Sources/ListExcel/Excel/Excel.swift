//
//  Excel.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

public class Excel: UIView {
    private let reusableCellIdentifier = "ExcelCell"
    public let contentView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .white
        // 通过 UICollectionView 实现高亮点击效果和事件处理，当 UICollectionView 隐藏的时候 UITableView 可触发 didSelectRow
        view.allowsSelection = true
        view.allowsMultipleSelection = false
        view.rowHeight = 44
        view.estimatedRowHeight = 0
        view.sectionHeaderHeight = 0
        view.estimatedSectionHeaderHeight = 0
        view.sectionFooterHeight = 0
        view.estimatedSectionFooterHeight = 0
        if #available(iOS 15.0, *) {
            view.fillerRowHeight = 0
            view.sectionHeaderTopPadding = 0
            view.isPrefetchingEnabled = false
        }
        view.alwaysBounceVertical = true
        view.tableFooterView = UIView()
        view.separatorStyle = .none
        return view
    }()

    private let headerCell = ExcelTableViewCell(style: .default, reuseIdentifier: "HeaderCell")
    private let footerCell = ExcelTableViewCell(style: .default, reuseIdentifier: "FooterCell")
    private let footerShadowImageView: UIImageView = {
        let image = UIImage.lex("lex_side_blur")
            .lex_baked(orientation: .right)?
            .resizableImage(
                withCapInsets: .init(0, 10),
                resizingMode: .stretch
            )
        return UIImageView(image: image)
    }()

    private weak var delegate: (any ExcelDelegate)?
    private var cellRegisters: [Excel.Cell.Register]
    private var rowHeights: [Int: CGFloat] = [:]
    private var columnWidths: [Int: CGFloat] = [:]
    /// 各行横向滚动共享偏移；cell layout / willDisplay 据此回写，避免 frame 变更把 offset 冲掉。
    private(set) var currentOffset: CGFloat = 0

    /// 布局 / 外观 / 行为配置（对外只读）。写入请用 `applyConfiguration`。
    public internal(set) var configuration: Configuration

    /// - Parameters:
    ///   - cellClasses: 覆盖默认 `ClassType` → Cell 映射（仅初始化生效，之后不可改）
    public init(
        delegate: any ExcelDelegate,
        configuration: Configuration = .init(),
        cellClasses: [Cell.ClassType: Cell.Type] = [:]
    ) {
        self.delegate = delegate
        self.configuration = configuration
        cellRegisters = Cell.ClassType.allCases.map { type in
            if let cellClass = cellClasses[type] {
                return Cell.Register(type, cellClass: cellClass, custom: "Custom")
            }
            return Cell.Register(type)
        }
        super.init(frame: .zero)
        backgroundColor = .white

        contentView.delegate = self
        contentView.dataSource = self
        contentView.register(ExcelTableViewCell.self, forCellReuseIdentifier: reusableCellIdentifier)
        addSubview(contentView)

        headerCell.row = .header
        headerCell.dataSource = delegate
        headerCell.parentExcel = self
        headerCell.register(cellRegisters)
        headerCell.contentDidScrollOnHorizontal = { [weak self] cell, offset in
            self?.resetAllContentOffset(cell, offset: offset)
        }

        footerShadowImageView.isHidden = true
        addSubview(footerShadowImageView)

        footerCell.row = .footer
        footerCell.dataSource = delegate
        footerCell.parentExcel = self
        footerCell.register(cellRegisters)
        footerCell.contentDidScrollOnHorizontal = { [weak self] cell, offset in
            self?.resetAllContentOffset(cell, offset: offset)
        }
        addSubview(footerCell)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 应用配置并刷新。传入新配置会先写入 `configuration`；不传则用当前值刷新。
    public func applyConfiguration(_ configuration: Configuration? = nil) {
        if let configuration {
            self.configuration = configuration
        }
        syncSelectionTypeToVisibleCells()
        reloadData()
    }

    /// 将 `configuration.selectionType` 同步到可见行 cell。
    func syncSelectionTypeToVisibleCells() {
        let type = configuration.selectionType
        visibleTableViewCell.forEach { $0.selectionType = type }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        if !footerCell.isHidden {
            footerCell.frame = .init(width, configuration.footerHeight)
            footerCell.bottom = height
            footerShadowImageView.frame = .init(0, footerCell.y - 10, footerCell.width, 10)
        }
        contentView.frame = bounds.inset(by: .bottom(footerCell.height))
        contentView.layoutIfNeeded()
        reloadFooterShadow()
    }

    public func resetContentOffset() {
        currentOffset = 0
        visibleTableViewCell.forEach { $0.resetContentOffset(0) }
    }
    
    public func reloadData() {
        resetRowHeights()
        resetColumnWidths()
        reloadHeader()
        reloadFooter()
        contentView.reloadData()
        setNeedsLayout()
    }

    public func reloadHeader() {
        headerCell.contentView.backgroundColor = delegate?.excel(self, backgroundColorAt: .header) ?? .clear
        headerCell.rowHeight = headerHeight
        headerCell.columnWidths = columnWidths
        headerCell.isHidden = headerCell.rowHeight == 0
        headerCell.reloadData(currentOffset)
        headerCell.setNeedsLayout()
        setNeedsLayout()
    }

    public func reloadFooter() {
        footerCell.contentView.backgroundColor = delegate?.excel(self, backgroundColorAt: .footer) ?? .clear
        footerCell.rowHeight = configuration.footerHeight
        footerCell.columnWidths = columnWidths
        footerCell.isHidden = footerCell.rowHeight == 0
        footerCell.reloadData(currentOffset)
        footerCell.setNeedsLayout()
        setNeedsLayout()
    }

    public func reloadCell(at matrix: Excel.Matrix) {
        let cell: ExcelTableViewCell?
        switch matrix.row {
            case .header:
                cell = headerCell
            case .footer:
                cell = footerCell
            default:
                cell = contentView.cellForRow(at: IndexPath(row: matrix.row.rawValue, section: 0)) as? ExcelTableViewCell
        }
        cell?.reloadCell(at: matrix.column)
    }

    public func reloadCells(at matrixs: [Excel.Matrix]) {
        matrixs.forEach { reloadCell(at: $0) }
    }
    
    public func reloadColumnWidth(_ column: Int, reason row: Excel.Matrix.Row? = nil) {
        let width = delegate?.excel(self, columnWidthAt: column) ?? 0
        columnWidths[column] = width
        visibleTableViewCell.forEach {
            $0.columnWidths[column] = width
            $0.reloadCellWidth(at: column)
        }
        if let row {
            DispatchQueue.main.async {
                let cell: ExcelTableViewCell?
                switch row {
                    case .header:
                        cell = self.headerCell
                    case .footer:
                        cell = self.footerCell
                    default:
                        cell = self.contentView.cellForRow(at: IndexPath(row: row.rawValue, section: 0)) as? ExcelTableViewCell
                }
                cell?.scrollRectToVisible(at: column)
            }
        }
    }

    /// 在数据源已反映新行数之后调用。插入前按 delegate 拉齐列宽快照，有变化才刷可见 cell。
    public func insertRows(at indexPaths: [IndexPath], with animation: UITableView.RowAnimation = .none) {
        syncColumnWidthsFromDelegateRefreshingVisibleIfNeeded()
        for indexPath in indexPaths {
            let height = resolvedRowHeight(at: indexPath.row)
            rowHeights[indexPath.row] = height
        }
        contentView.insertRows(at: indexPaths, with: animation)
        setNeedsLayout()
        reloadFooterShadow()
    }

    /// 在数据源已反映目标行内容之后调用。刷新前按 delegate 拉齐列宽快照，有变化才刷可见 cell。
    public func reloadRows(at indexPaths: [IndexPath], with animation: UITableView.RowAnimation = .none) {
        syncColumnWidthsFromDelegateRefreshingVisibleIfNeeded()
        for indexPath in indexPaths {
            let height = resolvedRowHeight(at: indexPath.row)
            rowHeights[indexPath.row] = height
        }
        contentView.reloadRows(at: indexPaths, with: animation)
        setNeedsLayout()
        reloadFooterShadow()
    }
    
    public func scrollToColumn(at column: Int, animated: Bool = true) {
        let cell = visibleTableViewCell.first
        cell?.scrollRectToVisible(at: column, animated: animated)
    }
    
    public func scrollToMatrix(at matrix: Matrix, animated: Bool = true) {
        let cell = visibleTableViewCell.first
        cell?.scrollRectToVisible(at: matrix.column, animated: animated)
        if matrix.row.isCell {
            let indexPath = IndexPath(row: matrix.row.rawValue, section: 0)
            let visibleRect = contentView.rectForRow(at: indexPath)
            if !visibleRect.isEmpty, visibleRect.isValidated {
                contentView.scrollRectToVisible(visibleRect, animated: animated)
            } else {
                contentView.scrollToRow(at: indexPath, at: .middle, animated: animated)
            }
        }
    }

    public func matrix(for cell: Excel.Cell) -> Matrix? {
        var matrix: Matrix?
        visibleTableViewCell.forEach {
            guard let column = $0.column(for: cell), let row = $0.row else { return }
            matrix = Matrix(column: column, row: row)
        }
        return matrix
    }

    public func cellForMatrix(at matrix: Matrix) -> Excel.Cell? {
        let cell: ExcelTableViewCell?
        switch matrix.row {
            case .header:
                cell = headerCell
            case .footer:
                cell = footerCell
            default:
                cell = contentView.cellForRow(at: IndexPath(row: matrix.row.rawValue, section: 0)) as? ExcelTableViewCell
        }
        return cell?.cellForColumn(at: matrix.column)
    }
    
    public var headerView: UIView { headerCell }
    public var footerView: UIView { footerCell }

    public var visibleCells: [Excel.Cell] {
        visibleTableViewCell.flatMap { $0.visibleCells }
    }

    public var matrixsForVisible: [Matrix] {
        visibleTableViewCell.compactMap { cell -> [Matrix]? in
            guard let row = cell.row else { return nil }
            return cell.columnsForVisible.map { Matrix(column: $0, row: row) }
        }.flatMap { $0 }
    }
}

private extension Excel {
    var headerHeight: CGFloat {
        configuration.headerHeight
    }

    var numberOfRows: Int {
        delegate?.numberOfRows(in: self) ?? 0
    }

    var numberOfColumns: Int {
        delegate?.numberOfColumns(in: self) ?? 0
    }

    func resolvedRowHeight(at row: Int) -> CGFloat {
        delegate?.excel(self, rowHeightAt: row) ?? configuration.rowHeight
    }

    var visibleTableViewCell: [ExcelTableViewCell] {
        (contentView.visibleCells + [headerCell, footerCell].filter { !$0.isHidden })
            .compactMap { $0 as? ExcelTableViewCell }
    }

    func resetRowHeights() {
        var rowHeights: [Int: CGFloat] = [:]
        (0 ..< numberOfRows).forEach { row in
            rowHeights[row] = resolvedRowHeight(at: row)
        }
        self.rowHeights = rowHeights
    }

    func resetColumnWidths() {
        var columnWidths: [Int: CGFloat] = [:]
        (0 ..< numberOfColumns).forEach { column in
            columnWidths[column] = delegate?.excel(self, columnWidthAt: column) ?? 0
        }
        self.columnWidths = columnWidths
    }

    /// 对比旧快照与 delegate 现值；仅变化列写入字典并刷新可见 cell（含 header/footer）。
    func syncColumnWidthsFromDelegateRefreshingVisibleIfNeeded() {
        let count = numberOfColumns
        var changed: [Int] = []
        for column in 0 ..< count {
            let width = delegate?.excel(self, columnWidthAt: column) ?? 0
            if columnWidths[column] != width {
                columnWidths[column] = width
                changed.append(column)
            }
        }
        columnWidths.keys.filter { $0 >= count }.forEach { columnWidths.removeValue(forKey: $0) }
        guard !changed.isEmpty else { return }
        for column in changed {
            let width = columnWidths[column] ?? 0
            visibleTableViewCell.forEach {
                $0.columnWidths[column] = width
                $0.reloadCellWidth(at: column)
            }
        }
    }

    func resetAllContentOffset(_ cell: ExcelTableViewCell, offset: CGFloat) {
        currentOffset = offset
        visibleTableViewCell
            .filter { $0 != cell }
            .forEach { $0.resetContentOffset(offset) }
    }

    func reloadFooterShadow() {
        let tableHeaderViewHeight = contentView.tableHeaderView?.height ?? 0
        let realContentSize = rowHeights.values.reduce(0, +) + headerHeight + tableHeaderViewHeight
        let notFull = realContentSize <= contentView.height
        let fullOffset = realContentSize <= contentView.contentOffset.y + contentView.height
        footerShadowImageView.isHidden = footerCell.isHidden || notFull || fullOffset
    }
}

extension Excel: UITableViewDelegate, UITableViewDataSource {
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        headerHeight
    }

    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        headerCell
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        numberOfRows
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        rowHeights[indexPath.row] ?? tableView.rowHeight
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reusableCellIdentifier, for: indexPath)
        guard let cell = cell as? ExcelTableViewCell else { return cell }
        cell.contentView.lex_borderPosition = indexPath.row == 0 ? [.top, .bottom] : .bottom
        cell.backgroundColor = delegate?.excel(self, backgroundColorAt: .cell(indexPath.row)) ?? .clear
        cell.register(cellRegisters)
        cell.row = .cell(indexPath.row)
        cell.rowHeight = rowHeights[indexPath.row] ?? tableView.rowHeight
        cell.columnWidths = columnWidths
        cell.dataSource = delegate
        cell.parentExcel = self
        cell.selectionType = configuration.selectionType
        cell.reloadData(currentOffset)
        cell.contentDidScrollOnHorizontal = { [weak self] cell, offset in
            self?.resetAllContentOffset(cell, offset: offset)
        }
        return cell
    }

    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as? ExcelTableViewCell)?.resetContentOffset(currentOffset)
    }
    
    public func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        configuration.selectionType.isRow
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        delegate?.excel(self, didSelectRowAt: .cell(indexPath.row), column: nil)
    }

    // MARK: UIScrollViewDelegate（仅常用；转 excel(_:scrollView…)）

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        reloadFooterShadow()
        delegate?.excel(self, scrollViewDidScroll: scrollView)
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        delegate?.excel(self, scrollViewWillBeginDragging: scrollView)
    }

    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        delegate?.excel(self, scrollViewWillEndDragging: scrollView, withVelocity: velocity, targetContentOffset: targetContentOffset)
    }

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        contentView.visibleCells.filter { $0.isHighlighted }.forEach { $0.setHighlighted(false, animated: true) }
        delegate?.excel(self, scrollViewDidEndDragging: scrollView, willDecelerate: decelerate)
    }

    public func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        delegate?.excel(self, scrollViewWillBeginDecelerating: scrollView)
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        delegate?.excel(self, scrollViewDidEndDecelerating: scrollView)
    }

    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        delegate?.excel(self, scrollViewDidEndScrollingAnimation: scrollView)
    }

    public func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        delegate?.excel(self, scrollViewShouldScrollToTop: scrollView) ?? true
    }

    public func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        delegate?.excel(self, scrollViewDidScrollToTop: scrollView)
    }
}
