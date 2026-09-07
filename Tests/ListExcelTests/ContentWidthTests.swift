//
//  ContentWidthTests.swift
//  ListExcelTests
//

import XCTest
@testable import ListExcel

final class ContentWidthTests: XCTestCase {
    private let font = UIFont.systemFont(ofSize: 14)
    private let configuration = Excel.Configuration()

    func testTextContentHasPositiveWidth() {
        let width = Excel.Content.text("Hello").contentWidth(with: font, configuration: configuration)
        XCTAssertNotNil(width)
        XCTAssertGreaterThan(width ?? 0, 0)
    }

    func testLongerTextIsWider() {
        let short = Excel.Content.text("A").contentWidth(with: font, configuration: configuration) ?? 0
        let long = Excel.Content.text(String(repeating: "W", count: 40))
            .contentWidth(with: font, configuration: configuration) ?? 0
        XCTAssertGreaterThan(long, short)
    }

    func testSelectContentWidthIsNil() {
        XCTAssertNil(Excel.Content.select.contentWidth(with: font, configuration: configuration))
    }

    func testImageContentWidthIsNil() {
        XCTAssertNil(Excel.Content.image.contentWidth(with: font, configuration: configuration))
    }

    func testEmptyTextContentWidthIsNil() {
        XCTAssertNil(Excel.Content.text("").contentWidth(with: font, configuration: configuration))
        XCTAssertNil(Excel.Content.text(nil).contentWidth(with: font, configuration: configuration))
    }

    func testDecimalContentHasWidth() {
        let width = Excel.Content.decimal(12.34, .decimal)
            .contentWidth(with: font, configuration: configuration)
        XCTAssertNotNil(width)
        XCTAssertGreaterThan(width ?? 0, 0)
    }

    func testTextFieldContentHasWidth() {
        let width = Excel.Content.textField("input")
            .contentWidth(with: font, configuration: configuration)
        XCTAssertNotNil(width)
        XCTAssertGreaterThan(width ?? 0, 0)
    }

    func testIconTextContentIncludesIcon() {
        let textOnly = Excel.Content.text("Hi").contentWidth(with: font, configuration: configuration) ?? 0
        let withIcon = Excel.Content.iconText(.delete, "Hi")
            .contentWidth(with: font, configuration: configuration) ?? 0
        XCTAssertGreaterThan(withIcon, textOnly)
    }

    func testCornerTextUsesMaxOfBodyAndCorners() {
        let width = Excel.Content.cornerText(
            "Body",
            leadingCorner: .init(1, style: .none),
            trailingCorner: .init(2, style: .none)
        ).contentWidth(with: font, configuration: configuration)
        XCTAssertNotNil(width)
        XCTAssertGreaterThan(width ?? 0, 0)
    }

    func testDecimalsUsesMaxLineWidth() {
        let width = Excel.Content.decimals([
            .init(1),
            .init(12345),
        ]).contentWidth(with: font, configuration: configuration)
        XCTAssertNotNil(width)
        let single = Excel.Content.decimal(12345).contentWidth(with: font, configuration: configuration) ?? 0
        XCTAssertEqual(width ?? 0, single, accuracy: 0.5)
    }

    func testCornerDecimalAndCornerTextFieldHaveWidth() {
        let d = Excel.Content.cornerDecimal(9.9, .none, leadingCorner: .init(1))
            .contentWidth(with: font, configuration: configuration)
        let f = Excel.Content.cornerTextField("x", trailingCorner: .init(2))
            .contentWidth(with: font, configuration: configuration)
        XCTAssertNotNil(d)
        XCTAssertNotNil(f)
    }

    func testIconTextWithoutLabelStillHasIconWidth() {
        let width = Excel.Content.iconText(.delete, nil)
            .contentWidth(with: font, configuration: configuration)
        XCTAssertNotNil(width)
        XCTAssertGreaterThan(width ?? 0, 0)
    }
}
