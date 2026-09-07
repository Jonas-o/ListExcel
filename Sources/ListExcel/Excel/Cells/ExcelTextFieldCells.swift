//
//  ExcelTextFieldCells.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

extension Excel {
    public class TextFieldCell<Field: ExcelTextInput>: Cell, ExcelTextFieldHosting {
        public typealias EditingAction = (TextFieldCell<Field>, Field, UIControl.Event) -> Void
        public var editingAction: EditingAction?

        public var inputTextField: UITextField { textField }

        @objc private func editingDidBegin(_ sender: UITextField) {
            guard let field = sender as? Field else { return }
            editingAction?(self, field, .editingDidBegin)
            textField.layer.borderWidth = 1
        }

        @objc private func editingChanged(_ sender: UITextField) {
            guard let field = sender as? Field else { return }
            editingAction?(self, field, .editingChanged)
            textField.layer.borderWidth = 1
        }

        @objc private func editingDidEnd(_ sender: UITextField) {
            guard let field = sender as? Field else { return }
            editingAction?(self, field, .editingDidEnd)
            textField.layer.borderWidth = 0
        }

        @objc private func editingDidEndOnExit(_ sender: UITextField) {
            guard let field = sender as? Field else { return }
            editingAction?(self, field, .editingDidEndOnExit)
            textField.layer.borderWidth = 0
        }

        public private(set) lazy var textField: Field = {
            let field = Field(frame: .zero)
            field.returnKeyType = .done
            field.textAlignment = .center
            field.addTarget(self, action: #selector(editingDidBegin(_:)), for: .editingDidBegin)
            field.addTarget(self, action: #selector(editingChanged(_:)), for: .editingChanged)
            field.addTarget(self, action: #selector(editingDidEnd(_:)), for: .editingDidEnd)
            field.addTarget(self, action: #selector(editingDidEndOnExit(_:)), for: .editingDidEndOnExit)
            return field
        }()

        public override func initSubviews() {
            super.initSubviews()
            editingAction = nil

            textField.resetAppearance()
            textField.backgroundColor = .white
            textField.clipsToBounds = true
            textField.layer.borderWidth = 0
            textField.layer.cornerRadius = 3
            textField.addTarget(self, action: #selector(editingDidBegin(_:)), for: .editingDidBegin)
            textField.addTarget(self, action: #selector(editingChanged(_:)), for: .editingChanged)
            textField.addTarget(self, action: #selector(editingDidEnd(_:)), for: .editingDidEnd)
            textField.addTarget(self, action: #selector(editingDidEndOnExit(_:)), for: .editingDidEndOnExit)
            contentView.addSubview(textField)
        }

        public override func applyAppearance() {
            super.applyAppearance()
            textField.font = appearance.font
            textField.textColor = appearance.accentColor
            textField.layer.borderColor = appearance.accentColor.cgColor
        }

        public override func bindContent(_ content: Content?, context: ContentBindContext = .init()) {
            guard case let .textField(text) = content else { return }
            textField.text = text
            if let alignment = context.textAlignment {
                textField.textAlignment = alignment
            }
        }

        public override func layoutSubviews() {
            super.layoutSubviews()
            textField.frame = contentView.bounds.inset(by: .all(.pixelOne))
        }
    }

    public typealias DefaultTextFieldCell = TextFieldCell<ExcelTextField>

    public class CornerTextFieldCell<Field: ExcelTextInput>: Cell, ExcelCornerTextFieldHosting {
        public typealias EditingAction = (CornerTextFieldCell<Field>, Field, UIControl.Event) -> Void
        public var editingAction: EditingAction?

        public var inputTextField: UITextField { textField }

        @objc private func editingDidBegin(_ sender: UITextField) {
            guard let field = sender as? Field else { return }
            editingAction?(self, field, .editingDidBegin)
            textField.layer.borderWidth = 1
        }

        @objc private func editingChanged(_ sender: UITextField) {
            guard let field = sender as? Field else { return }
            editingAction?(self, field, .editingChanged)
            textField.layer.borderWidth = 1
        }

        @objc private func editingDidEnd(_ sender: UITextField) {
            guard let field = sender as? Field else { return }
            editingAction?(self, field, .editingDidEnd)
            textField.layer.borderWidth = 0
        }

        @objc private func editingDidEndOnExit(_ sender: UITextField) {
            guard let field = sender as? Field else { return }
            editingAction?(self, field, .editingDidEndOnExit)
            textField.layer.borderWidth = 0
        }

        public private(set) lazy var textField: Field = {
            let field = Field(frame: .zero)
            field.returnKeyType = .done
            field.textAlignment = .center
            field.addTarget(self, action: #selector(editingDidBegin(_:)), for: .editingDidBegin)
            field.addTarget(self, action: #selector(editingChanged(_:)), for: .editingChanged)
            field.addTarget(self, action: #selector(editingDidEnd(_:)), for: .editingDidEnd)
            field.addTarget(self, action: #selector(editingDidEndOnExit(_:)), for: .editingDidEndOnExit)
            return field
        }()

        public static var cornerFont: UIFont { UIFont.systemFont(ofSize: 12) }
        public let leadingCornerLabel = DecimalLabel()
        public let trailingCornerLabel = DecimalLabel()

        public override func initSubviews() {
            super.initSubviews()
            editingAction = nil

            textField.resetAppearance()
            textField.backgroundColor = .white
            textField.clipsToBounds = true
            textField.layer.borderWidth = 0
            textField.layer.cornerRadius = 3
            textField.addTarget(self, action: #selector(editingDidBegin(_:)), for: .editingDidBegin)
            textField.addTarget(self, action: #selector(editingChanged(_:)), for: .editingChanged)
            textField.addTarget(self, action: #selector(editingDidEnd(_:)), for: .editingDidEnd)
            textField.addTarget(self, action: #selector(editingDidEndOnExit(_:)), for: .editingDidEndOnExit)
            contentView.addSubview(textField)

            [leadingCornerLabel, trailingCornerLabel].forEach {
                $0.resetAppearance()
                $0.setDecimal([])
                $0.warnStyle = .all
                $0.font = Self.cornerFont
                $0.isHidden = true
                contentView.addSubview($0)
            }
            trailingCornerLabel.textAlignment = .right
        }

        public override func applyAppearance() {
            super.applyAppearance()
            textField.font = appearance.font
            textField.textColor = appearance.accentColor
            textField.layer.borderColor = appearance.accentColor.cgColor
            leadingCornerLabel.textColor = appearance.accentColor
            leadingCornerLabel.warnTextColor = appearance.warnTextColor
            trailingCornerLabel.textColor = appearance.accentColor
            trailingCornerLabel.warnTextColor = appearance.warnTextColor
        }

        public override func bindContent(_ content: Content?, context: ContentBindContext = .init()) {
            guard case let .cornerTextField(text, leadingCorner, trailingCorner) = content else { return }
            textField.text = text
            leadingCornerLabel.isHidden = true
            trailingCornerLabel.isHidden = true
            if let leadingCorner {
                leadingCornerLabel.isHidden = false
                leadingCornerLabel.setDecimal([leadingCorner], locale: appearance.locale)
            }
            if let trailingCorner {
                trailingCornerLabel.isHidden = false
                trailingCornerLabel.setDecimal([trailingCorner], locale: appearance.locale)
            }
            if let alignment = context.textAlignment {
                textField.textAlignment = alignment
            }
        }

        public override func layoutSubviews() {
            super.layoutSubviews()
            var cornerLabelWidth = contentView.width - 10
            if !leadingCornerLabel.isHidden, !trailingCornerLabel.isHidden {
                cornerLabelWidth = (cornerLabelWidth - 5) / 2
            }
            if !leadingCornerLabel.isHidden {
                leadingCornerLabel.sizeToFit()
                leadingCornerLabel.width = cornerLabelWidth
                leadingCornerLabel.origin = .init(5, 1)
            }
            if !trailingCornerLabel.isHidden {
                trailingCornerLabel.sizeToFit()
                trailingCornerLabel.width = cornerLabelWidth
                trailingCornerLabel.y = 1
                trailingCornerLabel.right = contentView.width - 5
            }

            textField.frame = contentView.bounds.inset(by: .all(.pixelOne))
        }
    }

    public typealias DefaultCornerTextFieldCell = CornerTextFieldCell<ExcelTextField>
}
