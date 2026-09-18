//
//  ListExcelView+ColumnWidth.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//
//  列宽增量缓存：
//  1. `contentWidthCache` — Content 量字（跨行复用相同文案）
//  2. `rowColumnWidths` / `orphanRowContributions` — 每行对各列的贡献
//  3. `headerColumnWidths` / `footerColumnWidths` — 表头 / 表尾贡献
//  4. `recomputeWidthsFromRowContributions` — 取各列 max + clamp → 写 `widths`
//
//  写路径约定：
//  - 换 headers / 测宽 metrics 变 → `invalidateWidthCache` 后全量重建
//  - `reload` 只换 rows 且 metrics 未变 → `applyResetDiff`（指纹命中则复用行贡献）
//  - `append` → 只 `measureRow` 新行（及冲突降级的旧行）再 `recompute`
//  - 仅行高 / 放大变 → `recompute`（图列 preferred 跟 `resolvedRowHeight`），不清量字缓存
//

import UIKit

extension ListExcelView {
    /// 行级宽度贡献的字典键。
    /// - `modelId`：实现了 `Excel.ModelIdentifier`；同 id 多行时不可用（见 `uniqueRowWidthKey`）。
    /// - `objectId`：class 行模型的身份；struct / 无 id 走 orphan。
    enum RowWidthKey: Hashable {
        case modelId(String)
        case objectId(ObjectIdentifier)
    }

    /// 量字缓存键。字段任一变化都应 miss，避免错误复用宽度。
    /// `select` / `image` / `nil` Content 不产生键、不写入 `contentWidthCache`。
    struct ContentWidthKey: Hashable {
        let kind: String
        let payload: String
        let fontName: String
        let pointSize: CGFloat
        let paddingHorizontal: CGFloat
        let iconTitleSpacing: CGFloat
        let localeIdentifier: String
    }

    /// `reloadData(immediate:widthPolicy:)` 的列宽策略。
    enum ColumnWidthPolicy {
        /// 全量重测并写回 `widths`（可重建缓存）。
        case recalculate
        /// 不重测，沿用当前 `widths`（长度与列数不一致时仍会全量重测）。
        case keep
        /// 按已有行/表头表尾贡献再 `recompute`，不清空量字字典。
        case reconcile
    }
}

extension ListExcelView {
    /// `ColumnWidthPolicy.recalculate`：测表头表尾 → 重建全部行贡献 → `recompute` 写 `widths`。
    func calculateColumnWidths() {
        measureHeaderFooter()
        rebuildAllRowWidthContributions()
        recomputeWidthsFromRowContributions()
    }

    /// 单列重算（公开 `reloadCellWidth`）。更新该列表头/表尾缓存条目，并扫描全部行文案取 max；
    /// **不**完整重建 `rowColumnWidths`，可能与行级增量缓存短暂不一致——需严格一致时请 `reloadData()`。
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

        if columnContainsImage(column) {
            candidates.append(imageColumnPreferredWidth())
        }

        let computed = ceil(candidates.max() ?? 0)
        let limitMin = header.minWidth ?? 44
        let limitMax = header.maxWidth
        return min(max(computed, limitMin), limitMax)
    }
}

extension ListExcelView {
    /// 推导行键：优先 `ModelIdentifier`，否则 class 用 `ObjectIdentifier`；纯 struct 返回 `nil`。
    /// - Note: 不可对 `any RowModel` 直接 `as? AnyObject`（existential 盒子会误判为 class）。
    func rowWidthKey(for model: Excel.RowModel) -> RowWidthKey? {
        if let id = (model as? Excel.ModelIdentifier)?.identifier {
            return .modelId(id)
        }
        // `any RowModel as? AnyObject` 总会成功（命中 existential 盒子），须先判断真实类型是否为 class
        guard type(of: model) is AnyClass else { return nil }
        return .objectId(ObjectIdentifier(model as AnyObject))
    }

    /// 可用于 `rowColumnWidths` 的键：稳定，且 `modelId` 在当前表内全局唯一。
    /// 同 id 多行返回 `nil`，调用方应写入 `orphanRowContributions`。
    func uniqueRowWidthKey(for model: Excel.RowModel) -> RowWidthKey? {
        guard let key = rowWidthKey(for: model) else { return nil }
        if case let .modelId(id) = key, modelIdCounts[id, default: 0] > 1 {
            return nil
        }
        return key
    }

    /// 扫描 `rowDatas` 重建 `modelIdCounts`（append / reset diff / 全量重建前调用）。
    func rebuildModelIdCounts() {
        var counts: [String: Int] = [:]
        for row in rowDatas {
            if let id = (row as? Excel.ModelIdentifier)?.identifier {
                counts[id, default: 0] += 1
            }
        }
        modelIdCounts = counts
    }

    /// 清空全部列宽缓存与 `widths`。换 headers 或测宽相关 configuration 变化时调用。
    func invalidateWidthCache() {
        contentWidthCache.removeAll()
        rowColumnWidths.removeAll()
        orphanRowContributions.removeAll()
        headerColumnWidths.removeAll()
        footerColumnWidths.removeAll()
        rowContentFingerprints.removeAll()
        widths = []
    }

    /// 由 Content + 字体生成量字键；不可缓存的类型返回 `nil`。
    func contentWidthKey(for content: Excel.Content?, font: UIFont) -> ContentWidthKey? {
        guard let content else { return nil }
        let excel = configuration.excel
        let locale = excel.locale
        let localeIdentifier = locale.identifier
        let padding = excel.cellPadding.horizontalValue
        let spacing = excel.iconTitleSpacing
        let fontName = font.fontName
        let size = font.pointSize

        func key(kind: String, payload: String) -> ContentWidthKey {
            ContentWidthKey(
                kind: kind,
                payload: payload,
                fontName: fontName,
                pointSize: size,
                paddingHorizontal: padding,
                iconTitleSpacing: spacing,
                localeIdentifier: localeIdentifier
            )
        }

        switch content {
            case .select, .image:
                return nil
            case let .text(text):
                return key(kind: "text", payload: text ?? "")
            case let .decimal(decimal, style, hiddenZero):
                let text = DecimalLabel.DecimalTuple(decimal, style: style, hiddenZero: hiddenZero).text(locale: locale)
                return key(kind: "decimal", payload: "\(text)|\(styleToken(style))|\(hiddenZero)")
            case let .decimals(values):
                let payload = values.map {
                    "\($0.text(locale: locale))|\(styleToken($0.style))|\($0.hiddenZero)"
                }.joined(separator: ";")
                return key(kind: "decimals", payload: payload)
            case let .iconText(style, text):
                let styleToken: String
                switch style {
                    case .delete: styleToken = "delete"
                    case .clear: styleToken = "clear"
                    case let .custom(image):
                        styleToken = "custom:\(image.size.width)x\(image.size.height)"
                }
                return key(kind: "iconText", payload: "\(styleToken)|\(text ?? "")")
            case let .textField(text):
                return key(kind: "textField", payload: text ?? "")
            case let .cornerText(text, leading, trailing):
                return key(
                    kind: "cornerText",
                    payload: "\(text ?? "")|\(leading?.text(locale: locale) ?? "")|\(trailing?.text(locale: locale) ?? "")"
                )
            case let .cornerDecimal(decimal, style, leading, trailing):
                let text = decimal?.formatted(style, locale: locale) ?? ""
                return key(
                    kind: "cornerDecimal",
                    payload: "\(text)|\(styleToken(style))|\(leading?.text(locale: locale) ?? "")|\(trailing?.text(locale: locale) ?? "")"
                )
            case let .cornerTextField(text, leading, trailing):
                return key(
                    kind: "cornerTextField",
                    payload: "\(text ?? "")|\(leading?.text(locale: locale) ?? "")|\(trailing?.text(locale: locale) ?? "")"
                )
        }
    }

    /// `NumberStyle` 写入指纹用的短标记。
    private func styleToken(_ style: DecimalLabel.NumberStyle) -> String {
        switch style {
            case .none: return "none"
            case let .decimal(digits): return "decimal:\(digits.map(String.init) ?? "default")"
            case let .currency(code): return "currency:\(code ?? "locale")"
            case let .percent(digits): return "percent:\(digits.map(String.init) ?? "default")"
            case .custom: return "custom"
        }
    }

    /// 查 / 写 `contentWidthCache`；无键时直接量字且不缓存（如 image 列走 `contentWidth` 兜底）。
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

    /// 测量一行对各列的贡献，并写入 `rowColumnWidths` 或 `orphanRowContributions`，同时更新指纹。
    /// - Returns: 该行 `column → width` 贡献（不含 select / image）。
    @discardableResult
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

    /// 重测表头各列贡献 → `headerColumnWidths`（可排序 text 头额外加 chrome）。
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

    /// 重测表尾各列贡献 → `footerColumnWidths`。
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

    /// 表头 + 表尾一起重测。
    func measureHeaderFooter() {
        measureHeaderWidths()
        measureFooterWidths()
    }

    /// 图列优选宽：与 `ImageCell` 满 bounds、无 cellPadding 对齐，随 `resolvedRowHeight` 变化。
    func imageColumnPreferredWidth() -> CGFloat {
        configuration.resolvedRowHeight
    }

    /// 任一内容行为 `.image` 即视为图列（用于 `recompute` 注入 preferred 宽）。
    func columnContainsImage(_ column: Int) -> Bool {
        guard 0 ..< headers.count ~= column, !rowDatas.isEmpty else { return false }
        for index in rowDatas.indices {
            if case .image = genContent(at: .cell(index), column: column) {
                return true
            }
        }
        return false
    }

    /// 汇总表头 / 表尾 / 行贡献 / 图列 preferred，按列取 max 后 clamp，写回 `widths`。
    /// 不清 `contentWidthCache`；行贡献字典须已是当前数据的最新态。
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
            if columnContainsImage(column) {
                candidates.append(imageColumnPreferredWidth())
            }
            let computed = ceil(candidates.max() ?? 0)
            let header = headers[column]
            let limitMin = header.minWidth ?? 44
            let limitMax = header.maxWidth
            next[column] = min(max(computed, limitMin), limitMax)
        }
        widths = next
    }

    /// 丢弃行级贡献后按当前 `rowDatas` 全量 `measureRow`（换 headers / recalculate 等）。
    func rebuildAllRowWidthContributions() {
        rebuildModelIdCounts()
        rowColumnWidths.removeAll()
        orphanRowContributions.removeAll()
        rowContentFingerprints.removeAll()
        for (index, model) in rowDatas.enumerated() {
            _ = measureRow(model, index: index)
        }
    }

    /// 仅重建 orphan 行贡献（字典行不动）。用于冲突 id 降级后补测。
    func rebuildOrphanRowContributions() {
        orphanRowContributions.removeAll()
        for (index, model) in rowDatas.enumerated() {
            if uniqueRowWidthKey(for: model) == nil {
                _ = measureRow(model, index: index)
            }
        }
    }
}
