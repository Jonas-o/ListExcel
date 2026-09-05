# 列宽增量计算与 rowDatas / headers 写封闭 — 执行方案

> 状态：已落地（实现与三次补丁方案对齐；宿主侧 `headers`/`rowDatas` 为 `public internal(set)`，模块外不可写）  
> 范围：`ListExcelView` 数据 / 表头写入 API + 列宽缓存策略 + 宽度双层同步 + 条件化 UI 刷新（insert / reloadRows）  
> 不做：按行高、列宽采样 limit、开放任意 `rowDatas` / `headers` 写入、image 列随资源动态变宽

---

## 目标

1. `rowDatas` / `headers` **只读对外**：`public private(set)`；行写入口：`reset` / `append` / `update(at:)` / `replace(_:)`；表头写入口：`setHeaders(_:)`。
2. **列宽增量**：`append` 只测新行（并按需重测 footer）；`reset` **不清空缓存**，靠 diff；`update` / `replace` 单行增量（并按需重测 footer）；`setHeaders` 一律 invalidate + 全量重测。
3. **组合识别**：行 key = `ModelIdentifier` → `ObjectIdentifier` → 无 key / **同 id 冲突** 行走 orphan 或列扫描（见专节）；量字用 Content 指纹字典（兜底，成本已知）。
4. **同行高不变**；与现有 `isLoading` 门闩兼容。
5. **UI 刷新有条件**：`insertRows` / `reloadRows` 不能无脑用；见「阶段 3.5」。
6. **宽度同步是库的责任**：权威在 `ListExcelView.widths`；Excel.`columnWidths` 为布局快照；增量 UI 由 Excel 在 `insertRows` / `reloadRows` 内 **按快照是否变化** 拉齐并决定是否刷可见 cell（见阶段 W）。

### 前提（类型系统）

- 当前为 `[any Excel.RowModel]`，**不保证**全表同为 class 或同为 struct，可异构。
- 策略必须带 fallback；不能假设全员有 `ModelIdentifier` 或全是引用类型。

---

## 阶段 0：API 面（对外契约）

### `ListExcelView`

```swift
public private(set) var rowDatas: [any Excel.RowModel] = []
public private(set) var headers: [T] = []
// 实现注：Swift 跨文件 extension 需 `public internal(set)`，对库外宿主仍不可写。

/// 整表替换；列宽缓存做 diff，不清空字典后盲目全扔
public func reset(_ rows: [any Excel.RowModel])

/// 尾部追加；只测新行（并按需重测 footer）
public func append(_ rows: [any Excel.RowModel])

/// 按下标替换一行
public func update(at index: Int, _ row: any Excel.RowModel)

/// 按业务 id 替换一行（用新行的 identifier 查找）
@discardableResult
public func replace(_ row: some Excel.RowModel & Excel.ModelIdentifier) -> Bool

/// 替换表头 / 列定义；必定 invalidate 列宽缓存并全量重测，UI 走 reset 式整表刷新
public func setHeaders(_ headers: [T])
```

说明：

- **无** `reload: Bool`。每次写入口都按阶段 3.5 触发 UI；批量多次写靠 `isLoading = true` → 多次写入 → `isLoading = false` → 一次 `fullReconcile`。
- `replace`：用 `row.identifier` 在表中查找并替换；找不到 → **no-op 并返回** `false`。同 id 多行时约定取 **第一个**。查找键仅为业务 id，**不**涉及 OID ↔ ModelId 互换（那是 `update(at:)` 的 key 迁移问题，见阶段 3）。
- `update` 越界 → no-op（或 debug precondition）；`append([])` → 不触发 UI。
- 宿主不能再 `rowDatas = …` / `rowDatas.append` / `headers = …`。

### README

补「数据写入」章节：`setHeaders` / `reset` / `append` / `update` / `replace` + 与 `isLoading` 顺序；并说明 `reset` 会清理无效 `selectRows`。

---

## 阶段 H：`headers` 变更（方案 A）

`numberOfColumns == headers.count`。`widths`、`rowColumnWidths` 的列下标、header/footer 测量都绑定在 `headers` 上，属于**结构性**变更，比单行数据更重。

### 契约

```text
setHeaders(newHeaders):
  1. headers = newHeaders
  2. invalidateWidthCache()
     // 清 contentWidthCache、rowColumnWidths、orphan、headerColumnWidths、footerColumnWidths
  3. measureHeaderFooter()   // 分拆写入 header/footer；含排序加宽
  4. 按当前 rowDatas 全量 measureRow（唯一 key → rowColumnWidths；否则 orphan）
  5. recomputeWidthsFromRowContributions()  // 保证 widths.count == headers.count
  6. performUIRefresh(after: .setHeaders)  // reloadData(..., widthPolicy: .keep)
```

约定：

- 列数或列语义变化后，**禁止**假设旧 `widths` / Excel.`columnWidths` 仍有效。
- 首版不做「同 count 局部 invalidate」；凡 `setHeaders` 一律全量重测 + reset 式 UI。
- 推荐顺序：先 `setHeaders` 再 `reset`（若两者都要换）；不提供 `reset(headers:rows:)`（可选后续增强）。

| API | `!isLoading` | `isLoading` |
| --- | --- | --- |
| `setHeaders` | 整表 reload（`.keep`；列宽已全量重建） | pending `fullReconcile` |

---

## 阶段 W：宽度双层模型与强制同步

### 分层（合理，非设计错误）

| 层 | 角色 |
| --- | --- |
| `ListExcelView.widths` | **权威计算结果**（扫 Content、min/max、排序箭头、header/footer 贡献等） |
| Excel.`columnWidths` / `rowHeights` | **布局快照**：刷新前从 delegate 拉齐，cell 布局直接查字典，避免 layout 时反复问 delegate |

`ListExcelView` 经 `columnWidthAt` 喂给 Excel，是该设计的标准用例。全量 `Excel.reloadData()` 已会 `resetColumnWidths()`，故旧路径在「先算好 `widths` 再 reload」下是安全的。

**不推荐**：布局时每次问 delegate（打掉「刷新前取好」初衷）。

### 单一职责：Excel 增量 API 内「拉齐 + 按变化刷可见」

**不**再并列维护 `syncColumnWidthsToExcel` 与 `refreshColumnWidthsForAccessibleCells`。统一为 Excel 侧能力（List 只保证先更新 `rowDatas` 与 `widths`，再调增量 UI）：

```text
// Excel.insertRows / reloadRows 改 UI 之前（防御性主路径）：
1. 按 numberOfColumns 从 delegate 拉取每列宽度
2. 与当前 columnWidths 逐列比较（列数变化视为全变）
3. 有差异的列：
     写入 columnWidths[col]
     刷新可见 ExcelTableViewCell（含 header/footer）该列 itemSize / reloadCellWidth
4. 无差异：不刷可见区 layout；字典已与 delegate 一致即可
5. 再执行 insertRows / reloadRows
```

| 路径 | List 职责 | Excel 职责 |
| --- | --- | --- |
| `append` / `update` / `replace` 增量 UI | 先改数据与 `widths` → 再调 `insertRows` / `reloadRows` | 拉齐快照；**仅当宽度相对旧快照有变化时**刷可见 cell |
| `performResetStyleUIRefresh` / 整表 `reloadData` | 按 `widthPolicy` 决定是否重算 `widths` | `resetColumnWidths` + 整表 reload |
| `setHeaders` / `applyConfiguration` | invalidate + 重测 `widths` → reset 式 UI | 同上 |
| 公开 `reloadCellWidth`（若保留） | 重算该列写入 `widths` → 调 Excel `reloadColumnWidth` | 写字典 + 刷可见该列 |

原则：

- **权威在 List.`widths`**；Excel 字典是布局缓存。
- **是否刷可见 cell**：由 Excel 对比「旧 `columnWidths` vs delegate 现值」决定。
- 现网宽度经 `ceil`，比较用 `CGFloat` 精确相等即可。
- 宿主不应绕过 List 直接对业务表调 Excel 增量 API。

---

## 阶段 1：内部缓存结构

建议文件：`ListExcelView+ColumnWidthCache.swift`（或并入 `ListExcelView+ColumnWidth.swift`）。

```text
enum RowWidthKey: Hashable {
  case modelId(String)
  case objectId(ObjectIdentifier)
}

contentWidthCache: [ContentWidthKey: CGFloat]
  // 仅缓存「有数值贡献」的量宽结果；select/image/nil 不写入假 CGFloat

rowColumnWidths: [RowWidthKey: [Int: CGFloat]]
  // 仅「唯一」稳定 key 的行；同 modelId 多行不进此字典（见 1.5）

orphanRowContributions: [[Int: CGFloat]]
  // 无 key、以及同 id 冲突行的贡献

/// header / footer 分拆存储，按列 merge 进 recompute（禁止互相覆盖）
headerColumnWidths: [Int: CGFloat]
footerColumnWidths: [Int: CGFloat]

widths: [CGFloat]  // 始终维持 count == headers.count（见 recompute）
```

### `RowWidthKey` 解析

```text
func rowWidthKey(for model: RowModel) -> RowWidthKey? {
  if let id = (model as? ModelIdentifier)?.identifier { return .modelId(id) }
  if let obj = model as? AnyObject { return .objectId(ObjectIdentifier(obj)) }
  return nil
}
```

### 同 `modelId` 多行（不进字典）

`rowColumnWidths[.modelId]` 若允许多行共用同一键会互相覆盖 → max/收窄错误。

**定稿**：

```text
统计当前 rowDatas 中各 modelId 出现次数（或在写入时维护）。
若某 modelId 出现次数 > 1：
  - 这些行全部视为「冲突行」：不写入 / 从 rowColumnWidths 移除该 .modelId
  - 其列宽贡献进入 orphan（或对该列做「冲突行 + 无 key 行」扫描后并入 max）
若出现次数 == 1：
  - 正常按 .modelId 进入 rowColumnWidths
ObjectIdentifier 行：不同实例 key 不同，无此冲突；无 key 仍走 orphan。
```

`replace` 仍按 id 找**第一个**下标改数据；列宽侧不假设 id 全局唯一。

### `ContentWidthKey`

由 `Content` 稳定描述 + `font` 特征 + padding/margin 相关常量组成。

| Content | 指纹 / 缓存 | 量宽行为 |
| --- | --- | --- |
| `.text` / decimal / decimals / iconText / textField / corner* | 可哈希 key；有宽度则写入 `contentWidthCache` | 有文案则贡献 max |
| `.select` | **不**写入 `contentWidthCache`（直接跳过） | 现网 `nil` → 不贡献 max；靠其它贡献与 `minWidth` |
| `.image` | **不**写入 `contentWidthCache`（直接跳过） | 同上 |
| `nil` | 跳过 | 不贡献 |

- **禁止**为 select/image 存假 `CGFloat` 占位。
- 配置变更 → 清空所有宽度相关缓存后全量重建。
- 选中态 / 图片资源变化不驱动列宽失效（范围外：业务 `invalidate`）。

---

## 阶段 1.5：无 key / 冲突行（orphan）

```text
唯一稳定 key：measure → rowColumnWidths[key]
无 key 或同 modelId 冲突：measure → orphan（或列扫描）
recompute：
  确保 widths 长度为 headers.count
  widths[col] = clamp(
    max(headerColumnWidths[col],
        footerColumnWidths[col],
        max over rowColumnWidths[*][col],
        max over orphan[*][col]),
    minWidth, maxWidth)
  // ceil 与现网一致
```

### orphan 生命周期

| 操作 | orphan / 冲突行 |
| --- | --- |
| `append`（唯一 key） | **保留** orphan；新行写字典 |
| `append`（无 key 或导致某 id 变为重复） | 新贡献进 orphan；若某 id 从 1→2，将该 id **移出** `rowColumnWidths` 并改走 orphan/扫描 |
| `reset` / `setHeaders` | 按本轮数据重建：唯一 key 进字典，其余进 orphan |
| `update` 无 key / 冲突 | orphan 整表重算或列扫描 |
| `update` 唯一 key ↔ 唯一 key | 字典迁移；不碰无关 orphan |
| `invalidateWidthCache` | 清空 orphan 与字典 |

---

## 阶段 2：测量原语

| 方法 | 职责 |
| --- | --- |
| `measureRow` | `genContent` → 有数值才查/写 `contentWidthCache`；select/image/nil 跳过缓存；按唯一 key / orphan 规则落库 |
| `measureHeaderWidths()` | 逐列测 header；**必须复刻现网排序加宽**：`text` 且 `!sortBy.isEmpty` 时 `width + 20 + 8`；写入 `headerColumnWidths`（按列赋值，不清空未测列以外的 footer） |
| `measureFooterWidths()` | 逐列测 footer（`footerHeight == 0` 可跳过并清空/置零 footer 贡献）；写入 `footerColumnWidths` |
| `measureHeaderFooter()` | 调用上述两者；**分拆存储**，recompute 时按列 `max(header, footer, …)` |
| `recomputeWidthsFromRowContributions()` | **先** `widths = Array(repeating: 适合初值, count: headers.count)` 或逐列写入使 `widths.count == headers.count`；再按列 clamp；空 `headers` → `widths = []` |
| `invalidateWidthCache()` | 清空量字字典、行贡献、orphan、header/footer 分拆缓存 |

### header / footer 写入约定（按列 merge）

- **分拆**：`headerColumnWidths` 与 `footerColumnWidths` 独立。
- 仅重测 footer（`append`/`update`）时：只更新 `footerColumnWidths`，**禁止**重建一个合并字典时丢掉 header（含排序加宽）。
- 仅重测 header（少见）时同理，不动 footer。

### 重测时机

| 写入口 | header / footer |
| --- | --- |
| `append` | `footerHeight > 0` → `measureFooterWidths()`；header 通常不变可跳过 |
| `update` / `replace` | 同上 |
| `reset` / `setHeaders` | `measureHeaderFooter()` 全量 |
| 仅选中态 | 不重测 |

---

## 阶段 3：写入口（数据 + 列宽）

数据与列宽先落地；**UI 刷新统一走阶段 3.5**。

### UITableView 时序（强制）

```text
1. 先更新 rowDatas（及列宽缓存 / widths）
2. 使 numberOfRows / columnWidthAt 已反映新状态
3. 再调用 Excel.insertRows / reloadRows / reloadData
禁止：先 insert 再改 rowDatas
```

### `append(rows)`

```text
若 rows.isEmpty: return

oldCount = rowDatas.count
rowDatas += rows                    // ① 先改数据

for (offset, row) in rows.enumerated():
  measureRow(row, index: oldCount + offset)
  // 唯一 key → 字典；无 key / 冲突 → orphan；保留旧 orphan

若 footerHeight > 0:
  measureFooterWidths()             // 只改 footerColumnWidths

recomputeWidthsFromRowContributions()  // widths.count == headers.count

performUIRefresh(after: .append(from: oldCount))  // ② 再改 UI
```

### `reset(rows)`

```text
按唯一 RowWidthKey 分 added / removed / kept（冲突 id 不进字典差分，整批进 orphan 重建）
removed：从 rowColumnWidths 删除
added / 变化 kept：measureRow
无 key + 冲突 id：重建 orphan
measureHeaderFooter()
recomputeWidthsFromRowContributions()

// 选中态（非列宽核心，迁移约定）：
selectRows = selectRows ∩ 当前仍存在的 RowSelection.identifier 集合
// 或更简单：reset 时 selectRows.removeAll() / 只保留仍在新 rows 中的 id

performUIRefresh(after: .reset)
```

### `update(at:index, row)`

```text
guard 0 ..< rowDatas.count ~= index else { return }

oldKey = rowWidthKey(rowDatas[index])
rowDatas[index] = row               // ① 先改数据
newKey = rowWidthKey(row)
处理字典迁移 / 冲突降级为 orphan（见 1.5）
measureRow…
若 footerHeight > 0: measureFooterWidths()
recomputeWidthsFromRowContributions()
performUIRefresh(after: .update(index:))  // ② 再 UI
```

### `replace`

```text
找第一个 identifier 匹配的 index → update(at:index, row)；否则 false
```

### `setHeaders`

见阶段 H（同样：先改 `headers` 与 `widths`，再 UI）。

---

## 阶段 3.5：条件化 UI 刷新（insert / reloadRows / 门闩）

> **原则**：所有写入口 UI 受 `isLoading` 约束；门闩期间不积压 insert；结束后 `performResetStyleUIRefresh()`（`.keep`）。增量路径遵守「先数据后 UI」。

### 3.5.1 Pending 与 `isLoading`

```text
enum PendingUIRefresh {
  case none
  case fullReconcile
}

isLoading == true 且需要刷新 → pendingUIRefresh = .fullReconcile；return
isLoading → false 且 pending == fullReconcile → performResetStyleUIRefresh()；清 pending
```

| 写入 | `isLoading` | UI |
| --- | --- | --- |
| 任一写入口 | `true` | 只改数据与列宽；pending |
| `append` | `false` | **数据已更新后** `insertRows`（Excel 内 diff 刷可见宽） |
| `update` / `replace` | `false` | **数据已更新后** `reloadRows` |
| `reset` / `setHeaders` | `false` | 整表 reload **`.keep`** |
| loading 结束 | — | reset 式 reload **`.keep`** |

### 3.5.2 `append`（`!isLoading`）

```text
// 进入本步前：rowDatas / widths 已是终态
Excel.insertRows(at: 新行 indexPaths, .none)
  // 内部：快照 diff → 按需刷可见 → insert
视需要 reloadFooter；全选表头等局部 reloadCell
```

### 3.5.3 `update` / `reset` / `setHeaders`

```text
update/replace：Excel.reloadRows（内部同样 diff）
reset/setHeaders/loading结束：
  reloadData(immediate: true, widthPolicy: .keep)
```

### 3.5.4 Excel API

```swift
func insertRows(at indexPaths: [IndexPath], with animation: UITableView.RowAnimation)
func reloadRows(at indexPaths: [IndexPath], with animation: UITableView.RowAnimation)
```

内部：阶段 W 的 diff；补新行 `rowHeights`（勿盲目抹掉其它行高）；保持横向 `contentOffset`；需要时 `reloadFooter`。  
**前提**：调用时 dataSource 的 `numberOfRows` 已含新行（List 已先改 `rowDatas`）。

---

## 阶段 4：与通用 `reloadData` / `clearSelection` 衔接

```swift
enum ColumnWidthPolicy {
  case recalculate  // 全量重测并写回 widths（可重建缓存结构）
  case keep         // 不重测；沿用当前 widths
  case reconcile    // 按字典+orphan+header/footer 再 recompute，不清空后盲算
}

/// 宿主无参调用即默认全量重测
reloadData(immediate: Bool = false, widthPolicy: ColumnWidthPolicy = .recalculate)
```

| 场景 | widthPolicy |
| --- | --- |
| 宿主 `reloadData()` / `reloadData(immediate:)`（**不传** widthPolicy） | **`.recalculate`**（默认，不加参） |
| `applyConfiguration` | invalidate 后 `.recalculate` |
| `performResetStyleUIRefresh` / loading 结束 / `reset`/`setHeaders` 的 UI | **`.keep`**（内部显式传入） |
| `clearSelection` | 局部刷 select 列；fallback 时 `.keep` |

### `clearSelection`

```text
selectRows.removeAll()
若有 .select 列 → 只刷该列 header + 可见行（+ footer 若需）
否则 → reloadData(widthPolicy: .keep)
```

### `selectRows` 与数据迁移（非列宽核心，约定清理）

| 时机 | 行为 |
| --- | --- |
| `reset` | 清理：只保留仍存在于新 `rowDatas` 的 id，或整表 `removeAll` 后再按需选（实现选一种并写 README） |
| `append` | 通常不改 `selectRows` |
| `update`/`replace` | 若旧行 id 被换掉，从 `selectRows` 移除旧 id；新 id 不自动选中 |
| `setHeaders` | 不强制改选中（列变化不直接等于行 id 变化） |

---

## 阶段 5：迁移与兼容

| 旧用法 | 新用法 |
| --- | --- |
| `rowDatas = x; reloadData()` | `reset(x)` |
| `rowDatas += y; reloadData()` | `append(y)` |
| `headers = h; reloadData()` | `setHeaders(h)` |
| 改某一行再整表赋值 | `update` / `replace` 或 `reset` |
| 多次写 + 最后一次 reload | `isLoading = true` → 多次写 → `isLoading = false` |
| 宿主只刷 UI、接受全量重测列宽 | `reloadData()`（默认 `.recalculate`） |

未发版可直接 breaking：去掉可写 `rowDatas` / `headers`，README 同步。

---

## 阶段 6：实现顺序（建议切片）

| 步 | 内容 | 验收 |
| --- | --- | --- |
| 1 | `private(set)` + `reset`/`append`/`setHeaders`（列宽可先全量；先数据后 UI） | 行为等价；性能不验收 |
| 2 | 行缓存 + 同 id→orphan + header/footer 分拆 + 排序加宽 + footer 重测 + `widths.count` 不变式 | 分页增量；冲突 id 不错宽；排序列不缩 |
| 3 | `reset` diff + recompute 收窄 + `selectRows` 清理 | kept 复用；选中无脏 id |
| 4 | `ContentWidthKey`（select/image **跳过**缓存） | 与现网量宽一致 |
| 5 | `update`/`replace` | 单行；可收窄 |
| 6 | pending + loading **`.keep`** | 结束不重算列宽 |
| 7 | Excel `insertRows`/`reloadRows`（快照 diff；调用时数据源已新） | append→insert |
| 8 | `applyConfiguration` invalidate；`clearSelection` 局部刷 | — |
| 9 | README | 契约完整 |

---

## 风险与约定

1. 无 key / **同 modelId 多行**：不进 `rowColumnWidths`，走 orphan 或列扫描。
2. header/footer **分拆 + 按列 merge**；只更新 footer 时不得丢掉 header（含 **排序 +20+8**）。
3. **`recompute` 后 `widths.count == headers.count`**（含空表）。
4. **先改 `rowDatas`/`widths`，再 `insertRows`/`reloadRows`/`reloadData`**。
5. 宿主 `reloadData()` 默认 **`.recalculate`**；库内 reset 式 UI 显式 **`.keep`**。
6. select/image：**不**往 `contentWidthCache` 写假宽，直接跳过。
7. `reset`（及 id 变更的 update）**清理** `selectRows` 脏 id。
8. loading 结束不回放 insert；统一 `.keep` 整表对齐。
9. 可见列宽由 Excel 快照 diff 决定。
10. `headers` 只经 `setHeaders`。

---

## 行身份与缓存手段（备忘）

| 手段 | 角色 |
| --- | --- |
| `append` API 分段 | 发现新行主路径 |
| 唯一 `ModelIdentifier` | 行字典 key；`replace` 定位 |
| 同 id 多行 | 降级 orphan / 列扫描 |
| `ObjectIdentifier` | class 次选 key |
| orphan | 无 key + 冲突 id |
| header/footer 分拆 | 独立缓存，recompute 按列 max |
| Content 指纹 | 仅有数值贡献时写入缓存 |
| Excel 快照 diff | 增量 UI 按需刷可见宽 |
| 先数据后 UI | UITableView 硬约定 |

**最大收益**：`append` 不扫旧行（唯一 key 路径）。

---

## 不做（本方案范围外）

- 按行高；列宽采样 `sampleLimit`
- 开放任意 `rowDatas` / `headers` 写入
- `reload: Bool`；强制 `widthCacheKey`
- 无条件 `insertRows`；image 随资源动态变宽
- `setHeaders` 同 count 局部增量
- 布局阶段每次问 delegate 列宽
- List/Excel 双轨 sync + refreshAccessible
- 把同 id 多行强行拆成复合字典键（已选 orphan/扫描）
