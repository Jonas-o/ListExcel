//
//  ExcelDelegate.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

/// 底层矩阵引擎数据源与交互。实现类型须为 `NSObject` 子类（可用 `weak`）。
///
/// 布局类尺寸（锁列、表头/表尾行高、默认行高）在 `Excel.Configuration`，不在本协议。
public protocol ExcelDelegate: NSObjectProtocol {
    /// 内容行数（不含表头 / 表尾）。
    func numberOfRows(in excel: Excel) -> Int
    /// 列数；须与列宽、dequeue / handle 的 column 下标一致。
    func numberOfColumns(in excel: Excel) -> Int

    /// 单行行高；返回 `nil` 时使用 `excel.configuration.rowHeight`。
    func excel(_ excel: Excel, rowHeightAt row: Int) -> CGFloat?

    /// 列宽（pt）。未实现时默认 `0`，列会不可见，纯 Excel 用法务必实现。
    func excel(_ excel: Excel, columnWidthAt column: Int) -> CGFloat

    /// 返回该格应 dequeue 的 `ClassType`；`nil` 或未注册类型时显示空占位 Cell。
    func excel(_ excel: Excel, dequeueReusableCellAt matrix: Excel.Matrix) -> Excel.Cell.ClassType?

    /// 配置已 dequeue 的 Cell（绑定文案、图片、输入框等）。在 Appearance 注入之后调用。
    func excel(_ excel: Excel, handle cell: some Excel.Cell, at matrix: Excel.Matrix)

    /// 整行背景色（含 `.header` / `.footer` / `.cell`）；`nil` 为透明。
    func excel(_ excel: Excel, backgroundColorAt row: Excel.Matrix.Row) -> UIColor?

    func excel(_ excel: Excel, didSelectHeaderAt column: Int)

    /// - Parameter column: 点中的列；整行点选（`selectionType` 为 row 系）时为 `nil`。
    func excel(_ excel: Excel, didSelectRowAt row: Excel.Matrix.Row, column: Int?)

    func excel(_ excel: Excel, didSelectFooterAt column: Int)

    // MARK: Scroll

    /// 以下为常用 `UIScrollViewDelegate` 包装（非完整协议）。引擎可能先执行内部逻辑再回调（如 footer 阴影、取消行高亮）。
    /// `scrollView` 一般为 `excel.contentView`。

    func excel(_ excel: Excel, scrollViewDidScroll scrollView: UIScrollView)
    func excel(_ excel: Excel, scrollViewWillBeginDragging scrollView: UIScrollView)
    func excel(_ excel: Excel, scrollViewWillEndDragging scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>)
    func excel(_ excel: Excel, scrollViewDidEndDragging scrollView: UIScrollView, willDecelerate decelerate: Bool)
    func excel(_ excel: Excel, scrollViewWillBeginDecelerating scrollView: UIScrollView)
    func excel(_ excel: Excel, scrollViewDidEndDecelerating scrollView: UIScrollView)
    func excel(_ excel: Excel, scrollViewDidEndScrollingAnimation scrollView: UIScrollView)
    /// 默认 `true`。
    func excel(_ excel: Excel, scrollViewShouldScrollToTop scrollView: UIScrollView) -> Bool
    func excel(_ excel: Excel, scrollViewDidScrollToTop scrollView: UIScrollView)
}

public extension ExcelDelegate {
    func excel(_ excel: Excel, rowHeightAt row: Int) -> CGFloat? { nil }
    func excel(_ excel: Excel, columnWidthAt column: Int) -> CGFloat { 0 }
    func excel(_ excel: Excel, backgroundColorAt row: Excel.Matrix.Row) -> UIColor? { nil }
    func excel(_ excel: Excel, didSelectHeaderAt column: Int) { }
    func excel(_ excel: Excel, didSelectRowAt row: Excel.Matrix.Row, column: Int?) { }
    func excel(_ excel: Excel, didSelectFooterAt column: Int) { }

    func excel(_ excel: Excel, scrollViewDidScroll scrollView: UIScrollView) { }
    func excel(_ excel: Excel, scrollViewWillBeginDragging scrollView: UIScrollView) { }
    func excel(_ excel: Excel, scrollViewWillEndDragging scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) { }
    func excel(_ excel: Excel, scrollViewDidEndDragging scrollView: UIScrollView, willDecelerate decelerate: Bool) { }
    func excel(_ excel: Excel, scrollViewWillBeginDecelerating scrollView: UIScrollView) { }
    func excel(_ excel: Excel, scrollViewDidEndDecelerating scrollView: UIScrollView) { }
    func excel(_ excel: Excel, scrollViewDidEndScrollingAnimation scrollView: UIScrollView) { }
    func excel(_ excel: Excel, scrollViewShouldScrollToTop scrollView: UIScrollView) -> Bool { true }
    func excel(_ excel: Excel, scrollViewDidScrollToTop scrollView: UIScrollView) { }
}
