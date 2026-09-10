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
- 写入 API 驱动的列宽增量计算（`reset` / `append` / `update` / `replace`）
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

        listView.setHeaders(OrderHeader.allCases)
        listView.reset([
            OrderRow(identifier: "1", name: "A-100", amount: 12.5),
            OrderRow(identifier: "2", name: "B-200", amount: 8),
        ])
    }
}
```

日常改数据请走写入 API，不要直接赋值 `headers` / `rowDatas`。

## 架构一览

| 类型 | 职责 |
|------|------|
| `Excel` | 矩阵渲染引擎（`UITableView` + 锁列 `UICollectionView`） |
| `ListExcelView<T>` | 业务列表层（`T: Excel.Header`）：列宽、排序、多选、分页、合计 |
| `ExcelTotalView` | 底部合计 / 指示器 / 操作按钮 |

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

## 数据写入

`headers` / `rowDatas` 对外只读。通过下列 API 修改（先更新数据与列宽，再刷新 UI）：

| API | 作用 |
|-----|------|
| `setHeaders(_:)` | 换列定义；清空列宽缓存并全量重测；整表刷新 |
| `reset(_:)` | 整表替换；列宽缓存 diff；`selectRows` 与新 id 交集保留 |
| `append(_:)` | 尾部追加；只测新行；条件允许时 `insertRows` |
| `update(at:_:)` | 按下标替换一行 |
| `replace(_:)` | 按 `ModelIdentifier` 找第一个匹配行并 `update` |

### 批量写入与 `isLoading`

`isLoading == true` 时，写入 / `reloadData` / `applyConfiguration` 不立刻刷表，只记待对齐；设回 `false` 后以 `.keep` 整表刷新一次。

```swift
listView.isLoading = true
listView.append(nextPage)
listView.total = totalCount
listView.page = page
listView.isLoading = false
```

日常改数据优先用写入 API。需要整表重刷时再调用 `reloadData`；列宽策略（`.recalculate` / `.keep` / `.reconcile`）仅在该路径使用，细节见 API 注释。

### `reload(_:)` 批量写入

一次提交配置与数据的子集变更，内部只对齐一次 UI。`Batch.configuration` 预填当前值且**始终写回**；`headers` / `rowDatas` / `total` / `page` / `isLoading` 为 Optional，**仅赋值时才写入**；`clearsSelection` 控制是否清空选中（默认 `false`，若同时写了 `rowDatas` 则按 id 裁剪保留）。

```swift
listView.reload { batch in
    batch.configuration.excel.selectionType = .row()
    batch.rowDatas = nextPage
    batch.total = totalCount
    batch.page = page
    batch.isLoading = false
}
```

适合分页、切换选中模式等需要同时改配置与数据的场景；仅改配置时仍可用 `mutateConfiguration` / `applyConfiguration`。

## 配置

布局与外观集中在 `ListExcelView.Configuration`（内含 `Excel.Configuration`）。  
`configuration` 对外**只读**（`public internal(set)`），不能直接赋值；写入请用 `applyConfiguration` / `mutateConfiguration` / `reload`。

选中模式仅存在于 `configuration.excel.selectionType`（`.none` / `.cell()` / `.row()` / `.rowSelection()`），不再有 `ListExcelView.selectionType` 顶层属性。

```swift
// 初始化或整份替换：
var config = ListExcelView<OrderHeader>.Configuration()
config.excel.rowHeight = 56
config.excel.selectionType = .row()
listView.applyConfiguration(config)

listView.mutateConfiguration { config in
    config.excel.leadingLockCount = 2
    config.excel.locale = Excel.Locale.zhCN   // enUS / jaJP / current
    config.footerSumTitle = .localeDefault   // 或 .custom("本页合计") / nil
    config.totalText = .custom { "共 \($0) 条" }
}

// 运行时切换选中模式：
listView.reload { $0.configuration.excel.selectionType = .cell() }

// 无参重刷当前 configuration：
listView.applyConfiguration()
```

| API | 何时用 |
|-----|--------|
| `mutateConfiguration` | 在当前配置上改若干字段并刷新（推荐） |
| `applyConfiguration` | 整份替换配置，或无参按当前值重刷 |
| `reload(_:)` | 配置与 headers/rows/total/page/isLoading 批量提交 |
| `reloadData` | 需要整表重刷（日常改数据优先用写入 API） |

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
