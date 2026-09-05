//
//  ListExcelView+ColumnWidth.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension ListExcelView {
    /// 兼容旧路径 / `ColumnWidthPolicy.recalculate`：全量测宽（走缓存结构）。
    func calculateColumnWidths() {
        measureHeaderFooter()
        rebuildAllRowWidthContributions()
        recomputeWidthsFromRowContributions()
    }

    /// 单列重算（公开 `reloadCellWidth` 使用）。会更新该列表头/表尾缓存条目，并扫描全部行文案；
    /// 不完整重建 `rowColumnWidths`，可能与行级增量缓存短暂不一致——需要严格一致时请 `reloadData()`。
    func calculateColumnWidth(_ column: Int) -> CGFloat {
        guard 0 ..< headers.count ~= column else { return 0 }
        let header = headers[column]
        var candidates: [CGFloat] = []

        if headerHeight > 0,
           let content = genContent(at: .header, column: column),
           let width = cachedContentWidth(content, font: configuration.excel.headerFont) {
            var headerWidth = width
            if content.targetClassType == .text, !header.sortBy.isEmpty {
                headerWidth += 20 + 8
            }
            candidates.append(headerWidth)
            headerColumnWidths[column] = headerWidth
        }

        if footerHeight > 0, let content = genContent(at: .footer, column: column) {
            switch content {
                case .select, .image:
                    break
                default:
                    if let width = cachedContentWidth(content, font: configuration.excel.footerFont) {
                        candidates.append(width)
                        footerColumnWidths[column] = width
                    }
            }
        }

        for index in rowDatas.indices {
            guard let content = genContent(at: .cell(index), column: column) else { continue }
            switch content {
                case .select, .image:
                    continue
                default:
                    if let width = cachedContentWidth(content, font: configuration.excel.rowFont) {
                        candidates.append(width)
                    }
            }
        }

        let computed = ceil(candidates.max() ?? 0)
        let limitMin = header.minWidth ?? 44
        let limitMax = header.maxWidth
        return min(max(computed, limitMin), limitMax)
    }
}
