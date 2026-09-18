//
//  ListExcelCacheStore.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

/// 可选的列布局缓存。宿主自行实现落盘；包只在读写时机调用本协议。
///
/// 挂到 ``ListExcelView/cacheStore`` 后：
/// - `reload(readsCache: true)`：闭包**未写**的字段从本协议读取并填入 `Batch`；写过的以闭包为准。
/// - 点排序 / 清除排序 / 图片列放大：包调用 `saveSortColumn` / `saveEnlargeImageRows`。
/// - ``ListExcelView/validatedSortColumn()``：按本协议的表头投影并校验排序，不刷新界面。
///
/// 不设置 `cacheStore` 时，包内不读不写，行为与未接入缓存时一致。
///
/// 读侧用属性（无副作用）；写侧用 `save*`，避免与 `reload` 合并路径混淆。
public protocol ListExcelCacheStore<Header>: AnyObject {
    associatedtype Header: Excel.Header

    /// 全量表头（或当前缓存的列序）。提交时仍会经 `hasPermission` 与 `customHeadersFilter` 投影为可见列。
    var headers: [Header] { get }
    /// 左侧锁定列数；提交后可能被包 clamp 到可见列范围内。
    var leadingLockCount: Int { get }
    /// 右侧锁定列数；提交后可能被包 clamp 到可见列范围内。
    var trailingLockCount: Int { get }
    /// 缓存的排序。可见列校验由包在 `reload` / ``ListExcelView/validatedSortColumn()`` 中完成。
    var sortColumn: Excel.SortColumn<Header>? { get }

    /// 是否展示底栏排序提示与「清除排序」。默认 `false`。
    var showsSortHint: Bool { get }
    /// 是否允许图片列头切换放大行高。默认 `false`。
    var supportsEnlargeImageRows: Bool { get }
    /// 当前是否处于放大行高。默认 `false`。
    var enlargeImageRows: Bool { get }

    /// 将排序写入缓存。`nil` 表示已清除。点表头排序、``ListExcelView/clearSorts()`` 时由包调用。
    func saveSortColumn(_ column: Excel.SortColumn<Header>?)
    /// 将放大行高状态写入缓存。用户点击图片列头切换时由包调用。
    func saveEnlargeImageRows(_ enlarged: Bool)
}

public extension ListExcelCacheStore {
    var showsSortHint: Bool { false }
    var supportsEnlargeImageRows: Bool { false }
    var enlargeImageRows: Bool { false }
    func saveSortColumn(_ column: Excel.SortColumn<Header>?) {}
    func saveEnlargeImageRows(_ enlarged: Bool) {}
}

/// 泛型 `ListExcelView` 不能直接做 `@objc` target。
final class ListExcelHeaderLongPressTarget: NSObject {
    let handler: (UILongPressGestureRecognizer) -> Void

    init(_ handler: @escaping (UILongPressGestureRecognizer) -> Void) {
        self.handler = handler
    }

    @objc func handle(_ gesture: UILongPressGestureRecognizer) {
        handler(gesture)
    }
}
