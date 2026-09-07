//
//  ExcelLocale.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import Foundation

extension Excel {
    /// 常用 Locale 预设；`Configuration.locale` 类型仍为 `Foundation.Locale`。
    public enum Locale {
        public static var current: Foundation.Locale { .current }

        public static var zhCN: Foundation.Locale {
            Foundation.Locale(identifier: "zh_CN")
        }

        public static var enUS: Foundation.Locale {
            Foundation.Locale(identifier: "en_US")
        }

        public static var jaJP: Foundation.Locale {
            Foundation.Locale(identifier: "ja_JP")
        }
    }
}
