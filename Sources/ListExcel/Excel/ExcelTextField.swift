//
//  ExcelTextField.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

/// 可嵌入 `TextFieldCell` / `CornerTextFieldCell` 的输入框约束。
public protocol ExcelTextInput: UITextField {
    init(frame: CGRect)
    /// 清空文案并恢复默认键盘 / 对齐等编辑属性。
    func resetAppearance()
}

public extension ExcelTextInput {
    func resetAppearance() {
        text = nil
        placeholder = nil
        returnKeyType = .done
        keyboardType = .default
        textAlignment = .center
        borderStyle = .none
        removeTarget(nil, action: nil, for: .allEditingEvents)
    }
}

/// 表格默认输入框（对 `UITextField` 的轻量包装）。
public class ExcelTextField: UITextField, ExcelTextInput {
    public required override init(frame: CGRect) {
        super.init(frame: frame)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public func resetAppearance() {
        text = nil
        placeholder = nil
        returnKeyType = .done
        keyboardType = .default
        textAlignment = .center
        font = .default
        textColor = .softGreen
        removeTarget(nil, action: nil, for: .allEditingEvents)
        borderStyle = .none
    }
}

/// 任意 `TextFieldCell` / `CornerTextFieldCell` 的统一访问入口（供绑定文案与编辑回调）。
public protocol ExcelTextFieldHosting: AnyObject {
    var inputTextField: UITextField { get }
}

/// 带左右角标 Label 的输入 Cell。
public protocol ExcelCornerTextFieldHosting: ExcelTextFieldHosting {
    var leadingCornerLabel: DecimalLabel { get }
    var trailingCornerLabel: DecimalLabel { get }
}
