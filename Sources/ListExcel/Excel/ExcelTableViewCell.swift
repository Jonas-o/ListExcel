//
//  ExcelTableViewCell.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

final class ExcelTableViewCell: BaseTableViewCell {
    let emptyIdentifier = "Excel.Cell.Empty"
    let leadingCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.scrollDirection = .horizontal
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.backgroundColor = .clear
        view.allowsSelection = true
        view.allowsMultipleSelection = false
        view.isScrollEnabled = false
        view.isPrefetchingEnabled = false
        return view
    }()

    private let leadingShadowImageView: UIImageView = {
        let image = UIImage.lex("lex_side_blur").lex_image(with: .down)
        return UIImageView(image: image?.resizableImage(withCapInsets: .init(10, 0), resizingMode: .stretch))
    }()

    let contentCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.scrollDirection = .horizontal
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.backgroundColor = .clear
        view.allowsSelection = true
        view.allowsMultipleSelection = false
        view.alwaysBounceVertical = false
        view.alwaysBounceHorizontal = true
        view.isPrefetchingEnabled = false
        return view
    }()

    private lazy var contentTap = UITapGestureRecognizer(target: self, action: #selector(contentCollectionViewDidTap(_:)))

    let trailingCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.scrollDirection = .horizontal
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.backgroundColor = .clear
        view.allowsSelection = true
        view.allowsMultipleSelection = false
        view.isScrollEnabled = false
        view.isPrefetchingEnabled = false
        return view
    }()

    private let trailingShadowImageView = UIImageView(image: UIImage.lex("lex_side_blur").resizableImage(withCapInsets: .init(10, 0), resizingMode: .stretch))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectedBackgroundView = UIView()
        collectionViews.forEach {
            $0.delegate = self
            $0.dataSource = self
            $0.register(Excel.Cell.self, forCellWithReuseIdentifier: emptyIdentifier)
            contentView.addSubview($0)
        }
        leadingShadowImageView.isHidden = true
        trailingShadowImageView.isHidden = true
        contentView.insertSubview(leadingShadowImageView, belowSubview: leadingCollectionView)
        contentView.insertSubview(trailingShadowImageView, belowSubview: trailingCollectionView)

        contentTap.delegate = self
        contentCollectionView.addGestureRecognizer(contentTap)
        
        initSubviews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func initSubviews() {
        super.initSubviews()
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectedBackgroundView?.backgroundColor = .clear
        dataSource = nil
        parentExcel = nil
        row = nil
        rowHeight = 0
        columnWidths = [:]
        contentDidScrollOnHorizontal = nil
        selectionType = .row()
        cellRegisters = []
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        var contenStartX: CGFloat = 0
        leadingCollectionView.isHidden = leadingCount == 0
        if !leadingCollectionView.isHidden {
            let leadingWidth = (0 ..< leadingCount).compactMap { columnWidths[$0] }.reduce(0, +)
            leadingCollectionView.frame = .init(leadingWidth, rowHeight)
            contenStartX = leadingCollectionView.right

            leadingShadowImageView.frame = .init(leadingCollectionView.right, 0, 10, leadingCollectionView.height)
        }

        var contenRight: CGFloat = 0
        trailingCollectionView.isHidden = trailingCount == 0
        if !trailingCollectionView.isHidden {
            let contentIndexEnd = leadingCount + contentCount
            let trailingIndexEnd = leadingCount + contentCount + trailingCount
            let trailingWidth = (contentIndexEnd ..< trailingIndexEnd).compactMap { columnWidths[$0] }.reduce(0, +)
            trailingCollectionView.frame = .init(contentView.width - trailingWidth, 0, trailingWidth, rowHeight)
            contenRight = trailingCollectionView.width

            trailingShadowImageView.frame = .init(trailingCollectionView.x - 10, 0, 10, trailingCollectionView.height)
        }

        contentCollectionView.isHidden = contentCount == 0
        if !contentCollectionView.isHidden {
            holdOffset = true
            contentCollectionView.frame = contentView.bounds.inset(by: .init(0, contenStartX, 0, contenRight))
            holdOffset = false
        }
        contentCollectionView.layoutIfNeeded()
        // frame / contentSize 变化会把 contentOffset 冲掉，按共享偏移回写
        if let parentExcel {
            resetContentOffset(parentExcel.currentOffset)
        }
        reloadShadow()
        contentView.lex_refreshBorderLayers()
    }

    @objc private func contentCollectionViewDidTap(_ sender: UITapGestureRecognizer) {
        guard let row, row.isCell, selectionType.isRow, let parentExcel, sender == contentTap else { return }
        setHighlighted(false, animated: true)
        dataSource?.excel(parentExcel, didSelectRowAt: row, column: nil)
    }

    weak var dataSource: (any ExcelDelegate)?
    weak var parentExcel: Excel?

    var selectionType: Excel.SelectionType = .row() {
        didSet {
            switch selectionType {
                case .none:
                    selectionStyle = .none
                case let .cell(color):
                    selectionStyle = .none
                    visibleCells.forEach { $0.highlightedColor = color }
                case let .row(color), let .rowSelection(color):
                    // 行选依赖 selectedBackgroundView；selectionStyle=.none 时 UIKit 不会展示
                    selectionStyle = .default
                    selectedBackgroundView?.backgroundColor = color
            }
        }
    }

    /// 当前行号
    var row: Excel.Matrix.Row?
    /// 当前行高
    var rowHeight: CGFloat = 0
    var columnWidths: [Int: CGFloat] = [:]
    var contentDidScrollOnHorizontal: ((ExcelTableViewCell, CGFloat) -> Void)?
    private var cellRegisters: [Excel.Cell.Register] = []

    private var holdOffset = false
    public func reloadData(_ contentOffset: CGFloat) {
        collectionViews.forEach { $0.reloadData() }
        setNeedsLayout()
    }
    
    public func resetContentOffset(_ contentOffset: CGFloat) {
        holdOffset = true
        contentCollectionView.contentOffset = .init(contentOffset, 0)
        holdOffset = false
    }

    public func reloadCell(at column: Int) {
        guard let value = exToIndexPath(column) else { return }
        value.collectionView.reloadItems(at: [value.indexPath])
    }

    /// 仅刷新宽度，不涉及数据重载
    public func reloadCellWidth(at column: Int) {
        guard let value = exToIndexPath(column) else { return }
        value.collectionView.collectionViewLayout.invalidateLayout()
        if value.collectionView != contentCollectionView {
            setNeedsLayout()
            layoutIfNeeded()
        }
    }

    public func column(for cell: Excel.Cell) -> Int? {
        var column: Int?
        collectionViews.forEach {
            guard let indexPath = $0.indexPath(for: cell) else { return }
            column = exToColumn($0, indexPath: indexPath)
        }
        return column
    }

    public func cellForColumn(at column: Int) -> Excel.Cell? {
        guard let value = exToIndexPath(column) else { return nil }
        return value.collectionView.cellForItem(at: value.indexPath) as? Excel.Cell
    }
    
    public func scrollRectToVisible(at column: Int, animated: Bool = true) {
        guard let value = exToIndexPath(column), value.collectionView == contentCollectionView else { return }
        if let cell = contentCollectionView.cellForItem(at: value.indexPath) {
            let visibleRect = contentCollectionView.convert(cell.frame, from: cell.superview)
            contentCollectionView.scrollRectToVisible(visibleRect, animated: animated)
        } else {
            contentCollectionView.scrollToItem(at: value.indexPath, at: .centeredHorizontally, animated: animated)
        }
    }

    var visibleCells: [Excel.Cell] {
        collectionViews.flatMap { $0.visibleCells.compactMap { $0 as? Excel.Cell } }
    }

    var columnsForVisible: [Int] {
        collectionViews.flatMap { collectionView in
            collectionView.indexPathsForVisibleItems
                .compactMap { exToColumn(collectionView, indexPath: $0) }
        }
    }
}

extension ExcelTableViewCell {
    var leadingCount: Int {
        max(parentExcel?.configuration.leadingLockCount ?? 0, 0)
    }

    var contentCount: Int {
        guard let parentExcel else { return 0 }
        let columns = dataSource?.numberOfColumns(in: parentExcel) ?? 0
        return max(columns - leadingCount - trailingCount, 0)
    }

    var trailingCount: Int {
        max(parentExcel?.configuration.trailingLockCount ?? 0, 0)
    }

    var collectionViews: [UICollectionView] {
        [contentCollectionView, leadingCollectionView, trailingCollectionView]
    }

    func register(_ registers: [Excel.Cell.Register]) {
        guard !registers.isEmpty else { return }
        for register in registers {
            if let index = cellRegisters.firstIndex(where: { $0.type == register.type }) {
                cellRegisters[index] = register
            } else {
                cellRegisters.append(register)
            }
            collectionViews.forEach {
                $0.register(register.class, forCellWithReuseIdentifier: register.identifier)
            }
        }
    }

    func exToColumn(_ collectionView: UICollectionView, indexPath: IndexPath) -> Int? {
        let column: Int
        switch collectionView {
            case leadingCollectionView:
                column = indexPath.item
            case contentCollectionView:
                column = indexPath.item + leadingCount
            case trailingCollectionView:
                column = indexPath.item + leadingCount + contentCount
            default:
                return nil
        }
        return column
    }

    func exToIndexPath(_ column: Int) -> (collectionView: UICollectionView, indexPath: IndexPath)? {
        let collectionView: UICollectionView
        let indexPath: IndexPath
        if leadingCount > 0, 0 ..< leadingCount ~= column {
            collectionView = leadingCollectionView
            indexPath = IndexPath(item: column, section: 0)
        } else if contentCount > 0, leadingCount ..< leadingCount + contentCount ~= column {
            collectionView = contentCollectionView
            indexPath = IndexPath(item: column - leadingCount, section: 0)
        } else if trailingCount > 0, leadingCount + contentCount ..< leadingCount + contentCount + trailingCount ~= column {
            collectionView = trailingCollectionView
            indexPath = IndexPath(item: column - leadingCount - contentCount, section: 0)
        } else {
            return nil
        }
        return (collectionView, indexPath)
    }

    func reloadShadow() {
        let notFull = contentCollectionView.contentSize.width <= contentCollectionView.width
        let hasOffset = contentCollectionView.contentOffset.x <= 0
        leadingShadowImageView.isHidden = leadingCollectionView.isHidden || notFull || hasOffset

        let fullOffset = contentCollectionView.contentSize.width <= contentCollectionView.contentOffset.x + contentCollectionView.width
        trailingShadowImageView.isHidden = trailingCollectionView.isHidden || notFull || fullOffset
    }
}

extension ExcelTableViewCell {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == contentTap {
            guard let row else { return false }
            let isTarget = gestureRecognizer.lex_targetView == gestureRecognizer.view && row.isCell && selectionType.isRow
            if isTarget {
                setHighlighted(false, animated: true)
            }
            return isTarget
        }
        if super.responds(to: #selector(gestureRecognizerShouldBegin(_:))) {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        return false
    }

    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer == contentTap {
            guard let row else { return false }
            let isTarget = touch.view == contentCollectionView && row.isCell && selectionType.isRow
            if isTarget {
                setHighlighted(true, animated: true)
            }
            // 控制 contentTap 仅接受点击到 contentCollectionView 本身的事件
            return isTarget
        }
        return true
    }
}

extension ExcelTableViewCell: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let _ = row, let column = exToColumn(collectionView, indexPath: indexPath) else {
            return .zero
        }
        return .init(columnWidths[column] ?? 0, rowHeight)
    }

    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let _ = row else { return 0 }
        switch collectionView {
            case leadingCollectionView: return leadingCount
            case contentCollectionView: return contentCount
            case trailingCollectionView: return trailingCount
            default: return 0
        }
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let row, let parentExcel, let column = exToColumn(collectionView, indexPath: indexPath) else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: emptyIdentifier, for: indexPath)
        }
        let matrix = Excel.Matrix(column: column, row: row)
        let cellType = dataSource?.excel(parentExcel, dequeueReusableCellAt: matrix)
        let register = cellType.flatMap { type in cellRegisters.first { $0.type == type } }
        guard let register else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: emptyIdentifier, for: indexPath)
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: register.identifier, for: indexPath)
        guard let cell = cell as? Excel.Cell else { return cell }
        let appearance = Excel.Appearance(configuration: parentExcel.configuration, row: row)
        cell.appearance = appearance
        cell.applyAppearance()
        if let color = selectionType.color {
            cell.highlightedColor = color
        }
        dataSource?.excel(parentExcel, handle: cell, at: matrix)
        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        switch row {
            case .cell:
                switch selectionType {
                    case .none:
                        // 图片 Cell 支持点击
                        return collectionView.cellForItem(at: indexPath) is Excel.ImageCell
                    case .cell:
                        let cell = collectionView.cellForItem(at: indexPath) as? Excel.Cell
                        cell?.setHighlighted(true, animated: true)
                    case .row, .rowSelection:
                        setHighlighted(true, animated: true)
                }
                return true
            default: return true
        }
    }

    public func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        switch row {
            case .cell:
                switch selectionType {
                    case .cell:
                        let cell = collectionView.cellForItem(at: indexPath) as? Excel.Cell
                        cell?.setHighlighted(false, animated: true)
                    case .row, .rowSelection:
                        setHighlighted(false, animated: true)
                    default: break
                }
            default: break
        }
    }

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let row, let parentExcel, let column = exToColumn(collectionView, indexPath: indexPath) else {
            return
        }
        switch row {
            case .header:
                dataSource?.excel(parentExcel, didSelectHeaderAt: column)
            case .footer:
                dataSource?.excel(parentExcel, didSelectFooterAt: column)
            case .cell:
                dataSource?.excel(parentExcel, didSelectRowAt: row, column: column)
        }
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        reloadShadow()
        guard scrollView == contentCollectionView, !holdOffset else { return }
        contentDidScrollOnHorizontal?(self, scrollView.contentOffset.x)
    }

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard let row, row.isCell && selectionType.isRow, isHighlighted else { return }
        setHighlighted(false, animated: true)
    }
}
