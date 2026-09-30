//
//  Array+SafeSubscript.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import Foundation

extension RandomAccessCollection where Index == Int {
    /// 安全下标：越界返回 `nil`，避免崩溃。
    subscript(safe index: Int) -> Element? {
        guard index >= startIndex, index < endIndex else { return nil }
        return self[index]
    }
}
