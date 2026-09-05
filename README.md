# ListExcel

iOS Swift 表格组件：基础表格 `Excel` + 泛型通用列表 `ListExcelView`。

支持左右锁定列、列排序、行多选、分页加载与底部合计栏。

## 组件

| 组件 | 说明 |
|------|------|
| `Excel` | 基础表格（`UITableView` + 左右锁定列 `UICollectionView`） |
| `ListExcelView<T>` | 泛型通用列表（`T: Excel.Header`） |
| `ExcelTotalView` | 底部合计 / 指示器 / 操作按钮 |

## 目录

```
ListExcel/
├── Package.swift
├── Sources/ListExcel/
│   ├── Excel/                 # 基础表格引擎
│   │   ├── Excel.swift
│   │   ├── ExcelTypes.swift
│   │   ├── ExcelDelegate.swift
│   │   ├── ExcelTableViewCell.swift
│   │   ├── ExcelConfiguration.swift
│   │   ├── ExcelTheme.swift
│   │   ├── ExcelTextField.swift
│   │   └── Cells/
│   ├── ListExcel/             # 通用列表
│   │   ├── ListExcelView.swift
│   │   ├── ListExcelView+*.swift
│   │   ├── ListExcelDelegate.swift
│   │   ├── ListExcelConfiguration.swift
│   │   └── ExcelModels.swift
│   ├── ExcelTotalView.swift
│   ├── DecimalLabel.swift
│   ├── Support/
│   └── Resources/
└── README.md
```

Delegate 可按需只遵循子集协议，或使用组合别名 `ListExcelDelegate`：

- `ListExcelDataSource` — 内容 / 背景色
- `ListExcelCellHandling` — handleHeader / handleRow / handleFooter
- `ListExcelInteractionDelegate` — 点击 / 排序 / 多选 / 分页

## 接入

**SPM**

```swift
.package(url: "https://github.com/Jonas-o/ListExcel.git", from: "0.1.0")
```

> 当前仅支持 Swift Package Manager；CocoaPods 暂不维护。

## 数据写入

`headers` / `rowDatas` 对外只读（模块内可写）；请通过下列 API 改数据（**先改数据与列宽，再刷新 UI**）：

| API | 作用 |
|-----|------|
| `setHeaders(_:)` | 换表头/列定义；清空列宽缓存并全量重测；整表刷新 |
| `reset(_:)` | 整表替换行；列宽缓存 diff；`selectRows` 与新数据 id **交集保留** |
| `append(_:)` | 尾部追加；只测新行；条件允许时 `insertRows` |
| `update(at:_:)` | 按下标换一行；`reloadRows` |
| `replace(_:)` | 按 `ModelIdentifier` 找**第一个**匹配行并 `update` |

不要再写 `listView.rowDatas = …` / `listView.headers = …`。

### `isLoading` 与批量写入

`isLoading == true` 时，写入 API / `reloadData` / `applyConfiguration` **不立刻刷新表格**，只记 `fullReconcile`；`isLoading = false` 后以 **`widthPolicy: .keep`** 整表对齐（不回放 insert）。

```swift
listView.isLoading = true
listView.append(pageRows)   // 可多次
listView.isLoading = false  // 一次整表对齐
```

### `reloadData` 与列宽策略

```swift
listView.reloadData()
// 等价于 widthPolicy: .recalculate（宿主无参即全量重测列宽）

listView.reloadData(immediate: true, widthPolicy: .keep) // 库内 reset 式刷新使用
```

`applyConfiguration` 会 `invalidate` 列宽缓存后 `.recalculate`。

### `clearSelection`

只刷新 `.select` 列（找不到该列时 fallback `.keep` 整表 reload），不重算列宽。

## 数据绑定

行/表头/表尾内容有两条来源，**按优先级取值**（命中即停）：

1. **`Header.content(for:row:)`** — 列上声明式绑定（适合列逻辑固定）
2. **`ListExcelDataSource` 的 `contentAt` / `headerContentAt` / `footerContentAt`** — Delegate 集中提供

表头若两者皆无，默认 `.text(header.title)`。  
Footer 第 0 列若皆无且配置了 `footerSumTitle`，显示合计标题。

`Content` 决定 Cell 类型并填充常规字段；**无法用 Content 表达的**（如 `.image` 的实际图片）在 `handleRow` / `handleHeader` / `handleFooter` 里配置。

## 配置

通过 `ListExcelView.Configuration` / `Excel.Configuration` 统一配置布局与外观；Cell 在展示前由 `Excel.Appearance` 注入。

### `applyConfiguration` vs `reloadData`

| API | 何时用 |
|-----|--------|
| `applyConfiguration()` / `applyConfiguration(_:)` | 改了**布局 / 外观 / 文案类配置**后调用；先同步列表附属 UI，再 invalidate 列宽并 `.recalculate` 刷新 |
| `reloadData()` | 需要**整表重刷**且接受默认全量重测列宽时；日常改数据请优先用 `reset` / `append` / `update` / `replace` |

只改 `configuration`（或其字段）**不会**自动刷新，必须再调 `applyConfiguration()`。  
只改数据则调 `reloadData()` 即可，不必再 apply（除非同时改了配置）。

#### `isLoading` 与刷新

`isLoading == true` 时，`reloadData` / `applyConfiguration` **不会立刻刷新表格**（附属 chrome 仍会随 apply 更新），只记下待刷新；待 `isLoading = false` 后会 **立即**补刷一次。

推荐分页顺序：

```swift
listView.isLoading = true
// 请求…
listView.append(pageRows)  // 或 reset(firstPage)
listView.total = …
listView.page = …
listView.isLoading = false
```

```swift
var config = ListExcelView<MyHeader>.Configuration()
config.excel.rowHeight = 48
config.excel.accentColor = .systemBlue
config.excel.leadingLockCount = 2
config.showsSortHint = false

let listView = ListExcelView<MyHeader>(configuration: config)

// 运行时批改配置后主动应用
listView.configuration.excel.rowHeight = 56
listView.configuration.showsSortHint = true
listView.applyConfiguration()

// 数据更新
listView.setHeaders(myHeaders)
listView.reset(myRows)
```

也可直接传入新配置：`listView.applyConfiguration(config)`。

排序提示文案可通过 `sortHintProvider` 覆盖；合计文案可通过 `totalTextProvider` 覆盖。

## 自定义输入框

默认使用 `Excel.TextFieldCell<ExcelTextField>` / `Excel.CornerTextFieldCell<ExcelTextField>`。  
宿主可在**初始化**时用自己的 `UITextField` 子类覆盖 Cell 映射（仅生效一次，之后不可改；需遵循 `ExcelTextInput`）：

```swift
final class MyTextField: UITextField, ExcelTextInput {
    // 已有 init(frame:) 即可；可按需实现 resetAppearance()
}

let listView = ListExcelView<MyHeader>(
    configuration: config,
    cellClasses: [
        .textField: Excel.TextFieldCell<MyTextField>.self,
        .cornerTextField: Excel.CornerTextFieldCell<MyTextField>.self,
    ]
)
```

在 `handleRow` 中配置业务属性：

```swift
func listExcelView(
    _ excelView: ListExcelView<MyHeader>,
    handleRow cell: some Excel.Cell,
    union: Excel.CellUnion<MyHeader>
) {
    if let cell = cell as? Excel.TextFieldCell<MyTextField> {
        cell.textField.keyboardType = .decimalPad
        cell.editingAction = { _, field, event in
            // field 类型为 MyTextField
        }
    }
}
```

`Content` 仍使用 `.textField("...")` / `.cornerTextField(...)`，业务侧输入配置留在宿主，不进入 ListExcel。

## 后续待办

- [ ] 示例工程与单元测试
- [ ] 正式发版
