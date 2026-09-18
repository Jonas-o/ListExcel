//
//  ExcelLocale.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import Foundation

extension Excel {
    /// 常用 Locale 预设；赋给 ``Excel/Configuration/locale``（类型仍为 `Foundation.Locale`）。
    public enum Locale {
        /// 系统当前 Locale。
        public static var current: Foundation.Locale { .current }

        /// 简体中文（`zh_CN`）。
        public static var zhCN: Foundation.Locale {
            Foundation.Locale(identifier: "zh_CN")
        }

        /// 美式英语（`en_US`）。
        public static var enUS: Foundation.Locale {
            Foundation.Locale(identifier: "en_US")
        }

        /// 日语（`ja_JP`）。
        public static var jaJP: Foundation.Locale {
            Foundation.Locale(identifier: "ja_JP")
        }
    }
}
