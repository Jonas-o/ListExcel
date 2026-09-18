# ListExcel

面向 iOS 的 Swift 表格组件库：提供基础矩阵引擎 `Excel`，以及带列定义、排序、多选、分页与合计栏的通用列表 `ListExcelView`。

| | |
|---|---|
| 平台 | iOS 13+ |
| 语言 | Swift 5.9+ |
| 分发 | Swift Package Manager |
| 依赖 | 仅 UIKit |

## 特性

- 左右锁定列与横向同步滚动
- 列排序、行多选、触底分页
- 声明式列内容（`Excel.Content`）+ 可选 Delegate 回退
- 写入 API 驱动的列宽增量计算（`reload` / `append`）
- 可替换 Cell 类型与自定义输入框

## 安装

在 `Package.swift` 中：

```swift
dependencies: [
    .package(url: "https://github.com/Jonas-o/ListExcel.git", from: "0.1.0")
]
```

在 Xcode：File → Add Package Dependencies… → 填入仓库 URL。

```swift
import ListExcel
```

## 快速开始

```swift
enum OrderHeader: String, CaseIterable, Excel.Header {
    case name, amount, select

    var title: String { rawValue }

    var sortBy: String {
        self == .name ? "name" : ""
    }

    func content(for model: Excel.RowModel, row: Int) -> Excel.Content? {
        guard let order = model as? OrderRow else { return nil }
        switch self {
        case .name: return .text(order.name)
        case .amount: return .decimal(order.amount)
        case .select: return .select
        }
    }
}

struct OrderRow: Excel.RowModel, Excel.ModelIdentifier {
    var identifier: String
    var name: String
    var amount: Decimal
}

final class OrdersController: UIViewController, ListExcelDelegate {
    typealias T = OrderHeader

    private lazy var listView = ListExcelView<OrderHeader>(configuration: {
        var config = ListExcelView<OrderHeader>.Configuration()
        config.excel.leadingLockCount = 1
        config.showsTotalView = true
        return config
    }())

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(listView)
        listView.frame = view.bounds
        listView.delegate = self

        listView.reload { batch in
            batch.headers = OrderHeader.allCases
            batch.rowDatas = [
                OrderRow(identifier: "1", name: "A-100", amount: 12.5),
                OrderRow(identifier: "2", name: "B-200", amount: 8),
            ]
        }
    }
}
```

日常改数据请走写入 API，不要直接赋值 `headers` / `rowDatas`。

`reload { $0.headers }` 写入时会按 `Header.hasPermission` 与初始化注入的 `customHeadersFilter` 投影可见列；`sortColumn` 仅保留 `header` + `type`，可经 `Batch.sortColumn` 恒写回，并用 `sortBy` 对齐当前可见列（不在可见集则自动清空）。

## 架构一览

| 类型 | 职责 |
|------|------|
| `Excel` | 矩阵渲染引擎（`UITableView` + 锁列 `UICollectionView`） |
| `ListExcelView<T>` | 业务列表层（`T: Excel.Header`）：列宽、排序、多选、分页、合计 |
| `ListExcelTotalView` | 底部合计 / 指示器 / 操作按钮 |

Delegate 可按需组合，也可直接用别名 `ListExcelDelegate`：

| 协议 | 内容 |
|------|------|
| `ListExcelDataSource` | 表头/行/表尾内容与背景色 |
| `ListExcelCellHandling` | `handleHeader` / `handleRow` / `handleFooter` |
| `ListExcelInteractionDelegate` | 点击、排序、多选、分页 |

### 仅使用 `Excel`

不需要列定义 / 排序 / 分页时，实现 `ExcelDelegate` 并直接持有引擎：

```swift
final class MatrixController: UIViewController, ExcelDelegate {
    private var excelView: Excel!

    func numberOfRows(in excel: Excel) -> Int { 20 }
    func numberOfColumns(in excel: Excel) -> Int { 5 }

    override func viewDidLoad() {
        super.viewDidLoad()
        var configuration = Excel.Configuration()
        configuration.leadingLockCount = 1
        let excel = Excel(delegate: self, configuration: configuration)
        view.addSubview(excel)
        excelView = excel
        excel.reloadData()
    }

    func excel(_ excel: Excel, columnWidthAt column: Int) -> CGFloat { 72 }

    func excel(_ excel: Excel, dequeueReusableCellAt matrix: Excel.Matrix) -> Excel.Cell.ClassType? {
        matrix.row.isHeader ? .headerText : .text
    }

    func excel(_ excel: Excel, handle cell: some Excel.Cell, at matrix: Excel.Matrix) {
        cell.bindContent(.text("\(matrix.column)"), context: .init(textAlignment: .center))
    }
}
```

完整用法见 Example 中的「纯 Excel 引擎」场景。

## 内容绑定

单元格内容按优先级取值（命中即停）：

1. `Header.content(for:row:)` — 列上声明式绑定
2. `ListExcelDataSource` 的 `contentAt` / `headerContentAt` / `footerContentAt`

表头两者皆空时默认 `.text(header.title)`。  
Footer 第 0 列皆空且 `footerSumTitle != nil` 时显示合计标题（默认 `.localeDefault`）。

常见 `Excel.Content`：

- `.text` / `.decimal` / `.decimals`（数字格式跟 `excel.locale`）
- `.select` / `.image` / `.iconText`
- `.textField` / `.cornerText` / `.cornerTextField` / …

`Content` 负责选型与常规字段；图片等无法用 Content 表达的内容，在 `handleRow` / `handleHeader` / `handleFooter` 中配置。

### 图片列放大行高

```swift
listView.mutateConfiguration {
    $0.supportsEnlargeImageRows = true
    $0.enlargedRowHeight = 72
}
```

开启后：若未自定义 `headerContentAt`，且该列首行内容为 `.image`，包内会为表头注入 `.iconText(放大/缩小图标, header.title)`；点击即可切换 `enlargeImageRows`。宿主自定义表头时包不接管。

图列宽会取 `max(表头/文字贡献…, resolvedRowHeight)`（`ImageCell` 无 padding），放大切换只轻量重算列宽，不清文字测宽缓存。

## 数据写入

`headers` / `rowDatas` 对外只读。通过下列 API 修改（先更新数据与列宽，再刷新 UI）：

| API | 作用 |
|-----|------|
| `reload { … }` | 批量写入 `headers` / `rowDatas` / 配置等；换列会清空列宽缓存并全量重测；换行会 diff 列宽缓存，`selectRows` 与新 id 交集保留（除非 `clearsSelection`） |
| `append(_:)` | 尾部追加；只测新行；条件允许时 `insertRows` |

按下标或按 `ModelIdentifier` 改某一行时，在 `reload` 里改 `rowDatas` 副本再写回即可。

### 批量写入与 `isLoading`

`isLoading == true` 时，写入 / `reloadData` / `reload` 的表格刷新不立刻刷表，只记待对齐；设回 `false` 后以 `.keep` 整表刷新一次。

```swift
listView.isLoading = true
listView.append(nextPage)
listView.total = totalCount
listView.page = page
listView.isLoading = false
```

日常改数据优先用写入 API。需要强制重测列宽并整表刷新时再调用无参 `reloadData()`。

### `reload(readsCache:_:)` 批量写入

一次提交配置与数据的子集变更，内部只对齐一次 UI。`Batch.configuration` / `Batch.sortColumn` 预填当前值且**始终写回**；`headers` / `rowDatas` / `total` / `page` / `isLoading` 为 Optional，**仅赋值时才写入**；`clearsSelection` 控制是否清空选中（默认 `false`，若同时写了 `rowDatas` 则按 id 裁剪保留）。

挂了 `cacheStore` 时，`readsCache` 默认为 `true`：闭包没写的表头、排序、锁列，以及 `showsSortHint` / `supportsEnlargeImageRows` / `enlargeImageRows`，用 store 补上；闭包写过的字段优先。`readsCache: false` 这次不读 store。`mutateConfiguration` 固定不读 store。请求前要用缓存排序、但不想刷表时，读 `validatedSortColumn()`。表头长按在识别成功（`.began`）时回调 `didLongPressHeader`。

```swift
listView.cacheStore = store
listView.reload { batch in
    batch.configuration.excel.selectionType = .row()
    batch.rowDatas = nextPage
    batch.total = totalCount
    batch.page = page
    batch.isLoading = false
}
```

适合分页、切换选中模式等需要同时改配置与数据的场景。仅改配置用 `mutateConfiguration`（与 `reload` 共享提交路径：测宽字段未变则不整表重测）；需要强制按当前配置重测列宽时用无参 `reloadData()`。

## 配置

布局与外观集中在 `ListExcelView.Configuration`（内含 `Excel.Configuration`）。  
`configuration` 对外**只读**（`public internal(set)`），不能直接赋值；写入请用 `mutateConfiguration` / `reload`。

选中模式仅存在于 `configuration.excel.selectionType`（`.none` / `.cell()` / `.row()` / `.rowSelection()`），不再有 `ListExcelView.selectionType` 顶层属性。

### `cellPadding` / `iconTitleSpacing`

| 配置 | 作用范围 |
|------|----------|
| `excel.cellPadding` | 含 Label 的 cell 内边距（纯 Label，或 icon/排序图 + Label） |
| `excel.iconTitleSpacing` | 仅当同一 cell 内图标（或排序图）与 title **同时存在**时的间距 |

不适用：`ImageCell` / `SelectCell`（铺满 bounds）、TextField（`textRect` / 边框 inset）。  
`CornerText` / `CornerTextField` 的角标用包内硬编码 metrics，不接入上述两项。

```swift
// 初始化或整份替换：
var config = ListExcelView<OrderHeader>.Configuration()
config.excel.rowHeight = 56
config.excel.selectionType = .row()
listView.reload { $0.configuration = config }

listView.mutateConfiguration { config in
    config.excel.leadingLockCount = 2
    config.excel.locale = Excel.Locale.zhCN   // enUS / jaJP / current
    config.footerSumTitle = .localeDefault   // 或 .custom("本页合计") / nil
    config.totalText = .custom { "共 \($0) 条" }
}

// 运行时切换选中模式（不重测列宽）：
listView.mutateConfiguration { $0.excel.selectionType = .cell() }
// 等价：listView.reload { $0.configuration.excel.selectionType = .cell() }

// 强制按当前 configuration 重测列宽并刷新：
listView.reloadData()
```

| API | 何时用 |
|-----|--------|
| `mutateConfiguration` | 只改配置；测宽相关字段未变时轻量刷新 |
| `reload(_:)` | 配置与 headers/rows/total/page/isLoading 批量提交，或整份替换 configuration |
| `reloadData()` | 强制按当前配置重测列宽并整表刷新 |

数字格式见 `NumberStyle`（`.decimal` / `.currency` / …）；内置文案随 `excel.locale` 的 language（zh / en / ja），`.custom` 优先。

## 自定义 Cell / 输入框

初始化时通过 `cellClasses` 覆盖默认映射（仅生效一次）：

```swift
final class MyTextField: UITextField, ExcelTextInput {}

let listView = ListExcelView<OrderHeader>(
    configuration: config,
    cellClasses: [
        .textField: Excel.TextFieldCell<MyTextField>.self,
        .cornerTextField: Excel.CornerTextFieldCell<MyTextField>.self,
    ]
)
```

在 `handleRow` 中配置键盘、回调等业务属性；`Content` 仍使用 `.textField` / `.cornerTextField`。

## 示例与测试

仓库内 `Example/ListExcelExample.xcodeproj` 以 Local Package 依赖本库，覆盖锁列、排序、编辑、分页、Content 类型等场景：

```bash
open Example/ListExcelExample.xcodeproj
```

单元测试（需 iOS Simulator）：

```bash
xcodebuild test -scheme ListExcel \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

也可在 Xcode 中打开 Package，对 `ListExcel` scheme 执行 Product → Test。

## License

[MIT](LICENSE)
