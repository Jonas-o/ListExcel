//
//  ExcelCellBindTests.swift
//  ListExcelTests
//

import XCTest
@testable import ListExcel

final class ExcelCellBindTests: XCTestCase {
    func testTextCellBindsTextAndDecimal() {
        let cell = Excel.TextCell(frame: .init(0, 0, 120, 44))
        cell.appearance = .init(configuration: .init(), row: .cell(0))
        cell.applyAppearance()

        cell.bindContent(.text("Hello"), context: .init(textAlignment: .right))
        XCTAssertEqual(cell.textLabel.text, "Hello")
        XCTAssertEqual(cell.textLabel.textAlignment, .right)

        cell.bindContent(.decimal(3.5, .none), context: .init())
        XCTAssertEqual(cell.textLabel.text, "3.5")
    }

    func testSelectCellReflectsSelectionContext() {
        let cell = Excel.SelectCell(frame: .init(0, 0, 44, 44))
        cell.bindContent(.select, context: .init(isSelected: false))
        if case let .square(selected) = cell.style {
            XCTAssertFalse(selected)
        } else {
            XCTFail("expected square style")
        }

        cell.bindContent(.select, context: .init(isSelected: true))
        if case let .square(selected) = cell.style {
            XCTAssertTrue(selected)
        } else {
            XCTFail("expected square style")
        }
    }

    func testHeaderTextCellBindsTitleAndOrderType() {
        let cell = Excel.HeaderTextCell(frame: .init(0, 0, 120, 44))
        cell.appearance = .init(configuration: .init(), row: .header)
        cell.applyAppearance()
        cell.bindContent(.text("Title"), context: .init())
        XCTAssertEqual(cell.textLabel.text, "Title")
        cell.orderType = .ascending
        XCTAssertEqual(cell.orderType, .ascending)
        cell.orderType = .none
        XCTAssertEqual(cell.orderType, .none)
    }

    func testCornerTextCellShowsCorners() {
        let cell = Excel.CornerTextCell(frame: .init(0, 0, 160, 44))
        cell.appearance = .init(configuration: .init(), row: .cell(0))
        cell.applyAppearance()
        cell.bindContent(
            .cornerText("Body", leadingCorner: .init(1), trailingCorner: .init(2)),
            context: .init()
        )
        XCTAssertEqual(cell.textLabel.text, "Body")
        XCTAssertFalse(cell.leadingCornerLabel.isHidden)
        XCTAssertFalse(cell.trailingCornerLabel.isHidden)
    }

    func testIconTextCellBindsStyleAndText() {
        let cell = Excel.IconTextCell(frame: .init(0, 0, 120, 44))
        cell.appearance = .init(configuration: .init(), row: .cell(0))
        cell.applyAppearance()
        cell.bindContent(.iconText(.clear, "Clear"), context: .init())
        XCTAssertEqual(cell.textLabel.text, "Clear")
        if case .clear = cell.style {
            // ok
        } else {
            XCTFail("expected clear style")
        }
    }

    func testTextFieldCellBindsText() {
        let cell = Excel.DefaultTextFieldCell(frame: .init(0, 0, 120, 44))
        cell.appearance = .init(configuration: .init(), row: .cell(0))
        cell.applyAppearance()
        cell.bindContent(.textField("typed"), context: .init())
        XCTAssertEqual(cell.textField.text, "typed")
    }
}
