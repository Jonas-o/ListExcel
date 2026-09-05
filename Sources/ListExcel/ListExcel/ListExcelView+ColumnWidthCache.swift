//
//  ListExcelView+ColumnWidthCache.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension ListExcelView {
    enum RowWidthKey: Hashable {
        case modelId(String)
        case objectId(ObjectIdentifier)
    }

    /// 量字缓存键；select / image / nil 不产生键、不写入缓存。
    struct ContentWidthKey: Hashable {
        let kind: String
        let payload: String
        let fontName: String
        let pointSize: CGFloat
        let paddingHorizontal: CGFloat
        let cellMargin: CGFloat
    }

    public enum ColumnWidthPolicy {
        /// 全量重测并写回 `widths`（可重建缓存）
        case recalculate
        /// 不重测，沿用当前 `widths`
        case keep
        /// 按行/表头表尾贡献再 `recompute`，不清空字典后盲算
        case reconcile
    }
}

extension ListExcelView {
    func rowWidthKey(for model: Excel.RowModel) -> RowWidthKey? {
        if let id = (model as? Excel.ModelIdentifier)?.identifier {
            return .modelId(id)
        }
        // `any RowModel as? AnyObject` 总会成功（命中 existential 盒子），须先判断真实类型是否为 class
        guard type(of: model) is AnyClass else { return nil }
        return .objectId(ObjectIdentifier(model as AnyObject))
    }

    /// 仅当 key 稳定且（对 modelId）全局唯一时可用于 `rowColumnWidths`。
    func uniqueRowWidthKey(for model: Excel.RowModel) -> RowWidthKey? {
        guard let key = rowWidthKey(for: model) else { return nil }
        if case let .modelId(id) = key, modelIdCounts[id, default: 0] > 1 {
            return nil
        }
        return key
    }

    func rebuildModelIdCounts() {
        var counts: [String: Int] = [:]
        for row in rowDatas {
            if let id = (row as? Excel.ModelIdentifier)?.identifier {
                counts[id, default: 0] += 1
            }
        }
        modelIdCounts = counts
    }

    func invalidateWidthCache() {
        contentWidthCache.removeAll()
        rowColumnWidths.removeAll()
        orphanRowContributions.removeAll()
        headerColumnWidths.removeAll()
        footerColumnWidths.removeAll()
        rowContentFingerprints.removeAll()
        widths = []
    }

    func contentWidthKey(for content: Excel.Content?, font: UIFont) -> ContentWidthKey? {
        guard let content else { return nil }
        let excel = configuration.excel
        let padding = excel.cellPadding.horizontalValue
        let margin = excel.cellMargin
        let fontName = font.fontName
        let size = font.pointSize

        switch content {
            case .select, .image:
                return nil
            case let .text(text):
                return ContentWidthKey(
                    kind: "text",
                    payload: text ?? "",
                    fontName: fontName,
                    pointSize: size,
                    paddingHorizontal: padding,
                    cellMargin: margin
                )
            case let .decimal(decimal, style, hiddenZero):
                let text = DecimalLabel.DecimalTuple(decimal, style: style, hiddenZero: hiddenZero).text
                return ContentWidthKey(
                    kind: "decimal",
                    payload: "\(text)|\(String(describing: style))|\(hiddenZero)",
                    fontName: fontName,
                    pointSize: size,
                    paddingHorizontal: padding,
                    cellMargin: margin
                )
            case let .decimals(values):
                let payload = values.map { "\($0.text)|\(String(describing: $0.style))|\($0.hiddenZero)" }.joined(separator: ";")
                return ContentWidthKey(
                    kind: "decimals",
                    payload: payload,
                    fontName: fontName,
                    pointSize: size,
                    paddingHorizontal: padding,
                    cellMargin: margin
                )
            case let .iconText(style, text):
                let styleToken: String
                switch style {
                    case .delete: styleToken = "delete"
                    case .clear: styleToken = "clear"
                    case let .custom(image):
                        styleToken = "custom:\(image.size.width)x\(image.size.height)"
                }
                return ContentWidthKey(
                    kind: "iconText",
                    payload: "\(styleToken)|\(text ?? "")",
                    fontName: fontName,
                    pointSize: size,
                    paddingHorizontal: padding,
                    cellMargin: margin
                )
            case let .textField(text):
                return ContentWidthKey(
                    kind: "textField",
                    payload: text ?? "",
                    fontName: fontName,
                    pointSize: size,
                    paddingHorizontal: padding,
                    cellMargin: margin
                )
            case let .cornerText(text, leading, trailing):
                return ContentWidthKey(
                    kind: "cornerText",
                    payload: "\(text ?? "")|\(leading?.text ?? "")|\(trailing?.text ?? "")",
                    fontName: fontName,
                    pointSize: size,
                    paddingHorizontal: padding,
                    cellMargin: margin
                )
            case let .cornerDecimal(decimal, style, leading, trailing):
                let text = style.string(with: decimal) ?? ""
                return ContentWidthKey(
                    kind: "cornerDecimal",
                    payload: "\(text)|\(String(describing: style))|\(leading?.text ?? "")|\(trailing?.text ?? "")",
                    fontName: fontName,
                    pointSize: size,
                    paddingHorizontal: padding,
                    cellMargin: margin
                )
            case let .cornerTextField(text, leading, trailing):
                return ContentWidthKey(
                    kind: "cornerTextField",
                    payload: "\(text ?? "")|\(leading?.text ?? "")|\(trailing?.text ?? "")",
                    fontName: fontName,
                    pointSize: size,
                    paddingHorizontal: padding,
                    cellMargin: margin
                )
        }
    }

    func cachedContentWidth(_ content: Excel.Content, font: UIFont) -> CGFloat? {
        guard let key = contentWidthKey(for: content, font: font) else {
            return content.contentWidth(with: font, configuration: configuration.excel)
        }
        if let cached = contentWidthCache[key] {
            return cached
        }
        guard let width = content.contentWidth(with: font, configuration: configuration.excel) else {
            return nil
        }
        contentWidthCache[key] = width
        return width
    }

    func measureRow(_ model: Excel.RowModel, index: Int) -> [Int: CGFloat] {
        var contrib: [Int: CGFloat] = [:]
        var fingerprints: [ContentWidthKey?] = []
        fingerprints.reserveCapacity(headers.count)
        let font = configuration.excel.rowFont
        for column in headers.indices {
            let content = genContent(at: .cell(index), column: column)
            fingerprints.append(contentWidthKey(for: content, font: font))
            guard let content else { continue }
            if case .select = content { continue }
            if case .image = content { continue }
            if let width = cachedContentWidth(content, font: font) {
                contrib[column] = width
            }
        }

        if let key = uniqueRowWidthKey(for: model) {
            orphanRowContributions.removeValue(forKey: index)
            rowColumnWidths[key] = contrib
            rowContentFingerprints[key] = fingerprints
        } else {
            if let key = rowWidthKey(for: model), case .modelId = key {
                rowColumnWidths.removeValue(forKey: key)
                rowContentFingerprints.removeValue(forKey: key)
            }
            orphanRowContributions[index] = contrib
        }
        return contrib
    }

    func measureHeaderWidths() {
        var result: [Int: CGFloat] = [:]
        guard headerHeight > 0 else {
            headerColumnWidths = result
            return
        }
        let font = configuration.excel.headerFont
        for (column, header) in headers.enumerated() {
            let content = genContent(at: .header, column: column)
            guard let content, let base = cachedContentWidth(content, font: font) else { continue }
            var width = base
            if content.targetClassType == .text, !header.sortBy.isEmpty {
                width += 20 + 8
            }
            result[column] = width
        }
        headerColumnWidths = result
    }

    func measureFooterWidths() {
        var result: [Int: CGFloat] = [:]
        guard footerHeight > 0 else {
            footerColumnWidths = result
            return
        }
        let font = configuration.excel.footerFont
        for column in headers.indices {
            guard let content = genContent(at: .footer, column: column) else { continue }
            if case .select = content { continue }
            if case .image = content { continue }
            if let width = cachedContentWidth(content, font: font) {
                result[column] = width
            }
        }
        footerColumnWidths = result
    }

    func measureHeaderFooter() {
        measureHeaderWidths()
        measureFooterWidths()
    }

    func recomputeWidthsFromRowContributions() {
        let columnCount = headers.count
        guard columnCount > 0 else {
            widths = []
            return
        }
        var next = Array(repeating: CGFloat(0), count: columnCount)
        for column in 0 ..< columnCount {
            var candidates: [CGFloat] = []
            if let h = headerColumnWidths[column] { candidates.append(h) }
            if let f = footerColumnWidths[column] { candidates.append(f) }
            for contrib in rowColumnWidths.values {
                if let w = contrib[column] { candidates.append(w) }
            }
            for contrib in orphanRowContributions.values {
                if let w = contrib[column] { candidates.append(w) }
            }
            let computed = ceil(candidates.max() ?? 0)
            let header = headers[column]
            let limitMin = header.minWidth ?? 44
            let limitMax = header.maxWidth
            next[column] = min(max(computed, limitMin), limitMax)
        }
        widths = next
    }

    /// 全量重建行贡献（`setHeaders` / `recalculate` / 冲突 orphan 重算等）。
    func rebuildAllRowWidthContributions() {
        rebuildModelIdCounts()
        rowColumnWidths.removeAll()
        orphanRowContributions.removeAll()
        rowContentFingerprints.removeAll()
        for (index, model) in rowDatas.enumerated() {
            _ = measureRow(model, index: index)
        }
    }

    func rebuildOrphanRowContributions() {
        orphanRowContributions.removeAll()
        for (index, model) in rowDatas.enumerated() {
            if uniqueRowWidthKey(for: model) == nil {
                _ = measureRow(model, index: index)
            }
        }
    }
}
