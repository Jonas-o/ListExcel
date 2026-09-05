//
//  ExcelTypes.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension Excel {
    /// 排序类型
    public enum OrderType: String, Codable {
        case none = ""
        /// 升序
        case ascending = "ASC"
        /// 降序
        case descending = "DESC"

        public static var `default`: Self { .descending }
    }

    public struct Matrix {
        public enum Row {
            case header
            case footer
            case cell(Int)

            public var rawValue: Int {
                switch self {
                    case .header: return -1
                    case .footer: return -2
                    case let .cell(value): return value
                }
            }

            public var isHeader: Bool { rawValue == Row.header.rawValue }
            public var isFooter: Bool { rawValue == Row.footer.rawValue }
            public var isCell: Bool { rawValue >= 0 }
        }

        public let column: Int
        public let row: Row

        public init(column: Int, row: Row) {
            self.column = column
            self.row = row
        }
    }

    /// Cell 的点击效果, 不包括 header & footer
    public enum SelectionType {
        case none
        case cell(UIColor = UIColor(red: 247 / 255, green: 247 / 255, blue: 247 / 255, alpha: 1))
        case row(UIColor = UIColor(red: 247 / 255, green: 247 / 255, blue: 247 / 255, alpha: 1))
        /// 接管所有的 row 点击
        case rowSelection(UIColor = UIColor(red: 247 / 255, green: 247 / 255, blue: 247 / 255, alpha: 1))

        public var color: UIColor? {
            switch self {
                case let .cell(color), let .row(color), let .rowSelection(color):
                    return color
                default: return nil
            }
        }

        public var isNone: Bool {
            switch self {
                case .none: return true
                default: return false
            }
        }

        public var isCell: Bool {
            switch self {
                case .cell: return true
                default: return false
            }
        }

        public var isRow: Bool {
            switch self {
                case .row, .rowSelection: return true
                default: return false
            }
        }
    }
}
