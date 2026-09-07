//
//  DemoSupport.swift
//  ListExcelExample
//

import ListExcel
import UIKit

enum DemoNetwork {
    static func fetch<T>(
        delay: TimeInterval = 0.55,
        _ work: @escaping () -> T,
        completion: @escaping (T) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let value = work()
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                completion(value)
            }
        }
    }
}

enum DemoPalette {
    static let zebra = UIColor(white: 0.97, alpha: 1)
    static let warning = UIColor.systemOrange.withAlphaComponent(0.12)
    static let success = UIColor.systemGreen.withAlphaComponent(0.10)
}

extension UIViewController {
    func demoAlert(_ message: String, title: String = "提示") {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }
}

/// 生成纯色占位图（媒体 Demo 用）。
enum DemoImageFactory {
    static func swatch(_ color: UIColor, size: CGSize = CGSize(width: 36, height: 36), corner: CGFloat = 6) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: corner)
            color.setFill()
            path.fill()
            ctx.cgContext.setStrokeColor(UIColor.black.withAlphaComponent(0.15).cgColor)
            ctx.cgContext.setLineWidth(1)
            path.stroke()
        }
    }
}
