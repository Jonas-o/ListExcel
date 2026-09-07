//
//  Extensions.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit
import ObjectiveC

// MARK: - Layout / Geometry

extension CGFloat {
    /// 一像素对应的逻辑点数
    static var pixelOne: CGFloat { 1.0 / UIScreen.main.scale }
    /// 屏幕宽度
    static var screenWidth: CGFloat { UIScreen.main.bounds.width }
}

extension CGPoint {
    init(_ x: CGFloat, _ y: CGFloat) {
        self.init(x: x, y: y)
    }
}

extension CGSize {
    init(_ width: CGFloat, _ height: CGFloat) {
        self.init(width: width, height: height)
    }

    static func square(_ length: CGFloat) -> CGSize {
        .init(length, length)
    }
}

extension CGRect {
    /// 原点为零的矩形
    init(_ width: CGFloat, _ height: CGFloat) {
        self.init(0, 0, width, height)
    }

    init(_ size: CGSize) {
        self.init(size.width, size.height)
    }

    /// 构造时对原点向下取整、尺寸向上取整，避免半像素模糊
    init(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) {
        self.init(
            x: x.rounded(.down),
            y: y.rounded(.down),
            width: width.rounded(.up),
            height: height.rounded(.up)
        )
    }

    init(_ x: CGFloat, _ y: CGFloat, _ size: CGSize) {
        self.init(x, y, size.width, size.height)
    }

    var isValidated: Bool {
        !isNull && !isInfinite && width >= 0 && height >= 0
    }
}

extension UIEdgeInsets {
    init(_ top: CGFloat, _ left: CGFloat, _ bottom: CGFloat, _ right: CGFloat) {
        self.init(top: top, left: left, bottom: bottom, right: right)
    }

    /// 上下相等、左右相等
    init(_ topBottom: CGFloat, _ leftRight: CGFloat) {
        self.init(topBottom, leftRight, topBottom, leftRight)
    }

    static func all(_ value: CGFloat) -> UIEdgeInsets { .init(value, value, value, value) }
    static func top(_ value: CGFloat) -> UIEdgeInsets { .init(value, 0, 0, 0) }
    static func left(_ value: CGFloat) -> UIEdgeInsets { .init(0, value, 0, 0) }
    static func bottom(_ value: CGFloat) -> UIEdgeInsets { .init(0, 0, value, 0) }
    static func right(_ value: CGFloat) -> UIEdgeInsets { .init(0, 0, 0, value) }

    var horizontalValue: CGFloat { left + right }
    var verticalValue: CGFloat { top + bottom }

    func withBottom(_ bottom: CGFloat) -> UIEdgeInsets {
        var result = self
        result.bottom = bottom
        return result
    }

    func withRight(_ right: CGFloat) -> UIEdgeInsets {
        var result = self
        result.right = right
        return result
    }
}

// MARK: - View Frame

extension UIView {
    var x: CGFloat {
        get { frame.origin.x }
        set { frame.origin.x = newValue }
    }
    var y: CGFloat {
        get { frame.origin.y }
        set { frame.origin.y = newValue }
    }
    var width: CGFloat {
        get { frame.size.width }
        set { frame.size.width = newValue }
    }
    var height: CGFloat {
        get { frame.size.height }
        set { frame.size.height = newValue }
    }
    var right: CGFloat {
        get { x + width }
        set { x = newValue - width }
    }
    var bottom: CGFloat {
        get { y + height }
        set { y = newValue - height }
    }
    var centerY: CGFloat {
        get { center.y }
        set { center.y = newValue }
    }
    var origin: CGPoint {
        get { frame.origin }
        set { frame.origin = newValue }
    }
}

// MARK: - Color & Font

extension UIColor {
    static func hex(_ hex: String) -> UIColor {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let int = UInt64(value, radix: 16) else {
            return .gray
        }
        return UIColor(
            red: CGFloat((int & 0xFF0000) >> 16) / 255,
            green: CGFloat((int & 0x00FF00) >> 8) / 255,
            blue: CGFloat(int & 0x0000FF) / 255,
            alpha: 1
        )
    }

    static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor {
        UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: 1)
    }

    static var softRed: UIColor { .hex("#E46666") }
    static var softGreen: UIColor { .hex("#40B188") }
    static var softYellow: UIColor { .hex("#FFE7BA") }
    static var tintBlue: UIColor { .hex("#4A90E2") }
    static var textBlack: UIColor { .hex("#333333") }
    static var textGray: UIColor { .hex("#666666") }
    static var textLight: UIColor { .hex("#999999") }
    static var backgroundGray: UIColor { .hex("#F7F7F7") }
}

extension UIFont {
    /// Excel 默认字号
    static var `default`: UIFont { .systemFont(ofSize: 14) }
    /// Excel 默认加粗字号（表头等）
    static var defaultBold: UIFont { .systemFont(ofSize: 14, weight: .semibold) }
}

// MARK: - Image

extension UIImage {
    /// 从 ListExcel 资源包加载图片；找不到时回退到主 Bundle
    static func lex(_ name: String) -> UIImage {
        if let image = UIImage(named: name, in: .module, compatibleWith: nil) {
            return image
        }
        if let image = UIImage(named: name) {
            return image
        }
        return UIImage()
    }

    /// 纯色图
    static func lex_image(with color: UIColor, size: CGSize, cornerRadius: CGFloat = 0) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: cornerRadius)
            color.setFill()
            path.fill()
        }
    }
    
    /// 把 orientation 烘焙进像素，得到 .up 的图（capInsets 才按「看见的」方向生效）
    func lex_baked(orientation: Orientation) -> UIImage? {
        guard let oriented = lex_image(with: orientation) else { return nil }
        let size = oriented.size
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = oriented.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            oriented.draw(in: .init(origin: .zero, size: size))
        }
    }

    func lex_image(with orientation: UIImage.Orientation) -> UIImage? {
        guard let cgImage else { return self }
        return UIImage(cgImage: cgImage, scale: scale, orientation: orientation)
    }

    func lex_imageResized(inLimitedSize size: CGSize) -> UIImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Border

struct LEXBorderPosition: OptionSet {
    let rawValue: UInt
    static let top = LEXBorderPosition(rawValue: 1 << 0)
    static let left = LEXBorderPosition(rawValue: 1 << 1)
    static let bottom = LEXBorderPosition(rawValue: 1 << 2)
    static let right = LEXBorderPosition(rawValue: 1 << 3)
}

private var lexBorderPositionKey: UInt8 = 0
private var lexBorderLayersKey: UInt8 = 0

extension UIView {
    var lex_borderPosition: LEXBorderPosition {
        get {
            (objc_getAssociatedObject(self, &lexBorderPositionKey) as? NSNumber).flatMap {
                LEXBorderPosition(rawValue: $0.uintValue)
            } ?? []
        }
        set {
            objc_setAssociatedObject(self, &lexBorderPositionKey, NSNumber(value: newValue.rawValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            lex_updateBorderLayers(newValue)
        }
    }

    private func lex_updateBorderLayers(_ position: LEXBorderPosition) {
        (objc_getAssociatedObject(self, &lexBorderLayersKey) as? [CALayer])?.forEach { $0.removeFromSuperlayer() }
        var layers: [CALayer] = []
        guard !position.isEmpty, bounds.width > 0.5, bounds.height > 0.5 else {
            objc_setAssociatedObject(self, &lexBorderLayersKey, layers, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return
        }
        let color = UIColor(white: 0.85, alpha: 1).cgColor
        let line = CGFloat.pixelOne
        func makeLayer(frame: CGRect) {
            let layer = CALayer()
            layer.backgroundColor = color
            layer.frame = frame
            self.layer.addSublayer(layer)
            layers.append(layer)
        }
        if position.contains(.top) {
            makeLayer(frame: CGRect(x: 0, y: 0, width: bounds.width, height: line))
        }
        if position.contains(.bottom) {
            makeLayer(frame: CGRect(x: 0, y: bounds.height - line, width: bounds.width, height: line))
        }
        if position.contains(.left) {
            makeLayer(frame: CGRect(x: 0, y: 0, width: line, height: bounds.height))
        }
        if position.contains(.right) {
            makeLayer(frame: CGRect(x: bounds.width - line, y: 0, width: line, height: bounds.height))
        }
        objc_setAssociatedObject(self, &lexBorderLayersKey, layers, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    /// 在 `layoutSubviews` 中调用，按最新 bounds 重建边线，避免列宽变化后残留旧竖线。
    func lex_refreshBorderLayers() {
        lex_updateBorderLayers(lex_borderPosition)
    }
}

// MARK: - Control / Scroll / Gesture

private var lexTapBlockKey: UInt8 = 0

extension UIControl {
    var lex_tapBlock: ((UIControl) -> Void)? {
        get { objc_getAssociatedObject(self, &lexTapBlockKey) as? (UIControl) -> Void }
        set {
            objc_setAssociatedObject(self, &lexTapBlockKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
            removeTarget(self, action: #selector(lex_handleTap), for: .touchUpInside)
            if newValue != nil {
                addTarget(self, action: #selector(lex_handleTap), for: .touchUpInside)
            }
        }
    }

    @objc private func lex_handleTap() {
        lex_tapBlock?(self)
    }
}

extension UIScrollView {
    func lex_scrollToTop() {
        setContentOffset(CGPoint(x: contentOffset.x, y: -adjustedContentInset.top), animated: true)
    }
}

extension UIGestureRecognizer {
    var lex_targetView: UIView? {
        let location = location(in: view)
        return view?.hitTest(location, with: nil)
    }
}

// MARK: - Decimal

extension Decimal {
    /// 按 `NumberStyle` + locale 格式化为展示字符串。
    public func formatted(_ style: DecimalLabel.NumberStyle, locale: Locale) -> String {
        switch style {
            case .none:
                return formatPlain(locale: locale)
            case let .decimal(fractionDigits):
                return formatDecimal(locale: locale, fractionDigits: fractionDigits ?? ExcelTheme.defaultFractionDigits, grouping: true)
            case let .currency(code):
                return formatCurrency(locale: locale, code: code)
            case let .percent(fractionDigits):
                return formatPercent(locale: locale, fractionDigits: fractionDigits ?? ExcelTheme.defaultFractionDigits)
            case let .custom(make):
                return make(self, locale)
        }
    }

    private func formatPlain(locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumIntegerDigits = 1
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = ExcelTheme.noneMaximumFractionDigits
        return formatter.string(from: self as NSDecimalNumber) ?? "\(self)"
    }

    private func formatDecimal(locale: Locale, fractionDigits: Int, grouping: Bool) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = grouping
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: self as NSDecimalNumber) ?? "\(self)"
    }

    private func formatCurrency(locale: Locale, code: String?) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        if let code {
            formatter.currencyCode = code
        }
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = ExcelTheme.defaultFractionDigits
        return formatter.string(from: self as NSDecimalNumber) ?? "\(self)"
    }

    private func formatPercent(locale: Locale, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: self as NSDecimalNumber) ?? "\(self)"
    }
}

extension Optional where Wrapped == Decimal {
    public func formatted(_ style: DecimalLabel.NumberStyle, locale: Locale) -> String? {
        map { $0.formatted(style, locale: locale) }
    }
}

// MARK: - Appearance Reset

extension UILabel {
    @objc func resetAppearance() {
        text = nil
        attributedText = nil
        font = .default
        textColor = .textBlack
        numberOfLines = 1
        textAlignment = .left
        isHidden = false
        isHighlighted = false
        highlightedTextColor = nil
        isUserInteractionEnabled = false
    }
}

extension UIImageView {
    @objc func resetAppearance() {
        image = nil
        highlightedImage = nil
        isHidden = false
        isHighlighted = false
        contentMode = .scaleToFill
    }
}

// MARK: - String

extension String {
    func width(font: UIFont, height: CGFloat = .greatestFiniteMagnitude) -> CGFloat {
        let size = CGSize(.greatestFiniteMagnitude, height)
        let rect = (self as NSString).boundingRect(
            with: size,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(rect.width)
    }
}
