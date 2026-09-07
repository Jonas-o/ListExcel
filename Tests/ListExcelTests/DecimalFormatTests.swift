//
//  DecimalFormatTests.swift
//  ListExcelTests
//

import XCTest
@testable import ListExcel

final class DecimalFormatTests: XCTestCase {
    func testNoneOmitsGroupingAndKeepsFraction() {
        let value = Decimal(string: "1234.5")!
        let text = value.formatted(.none, locale: Excel.Locale.enUS)
        XCTAssertFalse(text.contains(","))
        XCTAssertTrue(text.contains("1234"))
        XCTAssertTrue(text.contains("5"))
    }

    func testCurrencyUsesLocaleDefaultCode() {
        let value = Decimal(string: "12.5")!
        let zh = value.formatted(.currency, locale: Excel.Locale.zhCN)
        XCTAssertFalse(zh.isEmpty)
        let usd = value.formatted(.currency(code: "USD"), locale: Excel.Locale.zhCN)
        XCTAssertTrue(usd.contains("US") || usd.contains("$") || usd.contains("USD"))
    }

    func testPercentTreatsValueAsRatio() {
        let text = Decimal(string: "0.15")!.formatted(.percent, locale: Excel.Locale.enUS)
        XCTAssertTrue(text.contains("15"))
    }

    func testCustomClosure() {
        let text = Decimal(3).formatted(.custom { value, _ in "X-\(value)" }, locale: Excel.Locale.enUS)
        XCTAssertEqual(text, "X-3")
    }
}

@MainActor
final class LocalizedTextConfigurationTests: XCTestCase {
    func testFooterSumTitleNilHidesFallback() {
        let (list, _, window) = TestListFactory.makeExternalList(footerHeight: 44, footerSumTitle: nil)
        defer { window.isHidden = true }
        list.reset([TestIdentifiedRow(identifier: "1", name: "n", value: "v")])
        XCTAssertNil(list.genContent(at: .footer, column: 0))
    }

    func testTotalTextNilHidesLabel() {
        let (list, _, window) = TestListFactory.makeList()
        defer { window.isHidden = true }
        list.configuration.excel.locale = Excel.Locale.zhCN
        list.configuration.totalText = nil
        list.applyConfiguration()
        list.total = 9
        XCTAssertTrue(list.totalView.subviews.contains { view in
            (view as? UILabel)?.isHidden == true || list.configuration.resolvedTotalText(for: 9) == nil
        })
        XCTAssertNil(list.configuration.resolvedTotalText(for: 9))
    }

    func testLocaleDefaultTotalTextFollowsLocale() {
        var configuration = ListExcelView<TestHeader>.Configuration()
        configuration.excel.locale = Excel.Locale.enUS
        configuration.totalText = .localeDefault
        XCTAssertEqual(configuration.resolvedTotalText(for: 3), "Total 3")

        configuration.excel.locale = Excel.Locale.zhCN
        XCTAssertEqual(configuration.resolvedTotalText(for: 3), "共计3条")
    }

    func testCustomOverridesLocaleDefault() {
        var configuration = ListExcelView<TestHeader>.Configuration()
        configuration.excel.locale = Excel.Locale.enUS
        configuration.clearSortTitle = .custom("Wipe")
        XCTAssertEqual(configuration.resolvedClearSortTitle(), "Wipe")
        configuration.footerSumTitle = .custom("Sum")
        XCTAssertEqual(configuration.resolvedFooterSumTitle(), "Sum")
    }
}
