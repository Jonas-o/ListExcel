//
//  UIKitShims.swift
//  ListExcel
//
//  Copyright © 2026 ListExcel. All rights reserved.
//

import UIKit

// MARK: - Base Cell

class BaseTableViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        initSubviews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initSubviews()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        initSubviews()
    }

    @objc func initSubviews() {}
}

// MARK: - Button

typealias ActionBlock = (_ sender: NormalButton) -> Void

struct ActionButton {
    let button: NormalButton
    let action: ActionBlock
}

class NormalButton: UIButton {
    enum TintColorStyle {
        case green, red, blue, black, gray, light
        var textColor: UIColor {
            switch self {
            case .green: return .lightGreen
            case .red: return .softRed
            case .blue: return .tintBlue
            case .black: return .textBlack
            case .gray: return .textGray
            case .light: return .textLight
            }
        }
    }

    var style: TintColorStyle = .green {
        didSet { setTitleColor(style.textColor, for: .normal) }
    }

    convenience init(title: String? = nil, image: UIImage? = nil, style: TintColorStyle = .green) {
        self.init(type: .system)
        setTitle(title, for: .normal)
        setImage(image, for: .normal)
        self.style = style
        titleLabel?.font = .default
        setTitleColor(style.textColor, for: .normal)
        sizeToFit()
    }
}

// MARK: - Debouncer

/// 防抖 / 节流工具（默认在主队列执行，间隔 0.25 秒）。
///
/// - ``perform(immediate:execute:)`` / 防抖：尾缘触发，连续调用会重置计时，安静满 `interval` 后才执行。
/// - ``throttle(execute:)`` / 节流：首缘触发，立刻执行；执行结束起算 `interval` 内的后续调用丢弃。
/// - `immediate: true`：立刻执行，并取消尚未触发的防抖 / 节流冷却。
///
/// 同一实例上防抖与节流互斥：`perform` 会清掉节流状态，`throttle` 会取消未触发的防抖任务。
class Debouncer {
    private let label: String
    private let interval: DispatchTimeInterval
    private let queue: DispatchQueue
    private let executeQueue: DispatchQueue
    private let semaphore: DispatchSemaphoreWrapper
    private var workItem: DispatchWorkItem?
    /// 节流窗口是否生效（含「正在执行」与「执行后的冷却」）
    private var isThrottling = false
    /// 用于识别「当前这一代」任务，避免 WorkItem 闭包强引用自身造成环
    private var generation: UInt64 = 0

    init(label: String = "common", interval: Float = 0.25, executeQueue: DispatchQueue = .main) {
        self.label = label
        self.interval = .milliseconds(Int(interval * 1000))
        queue = DispatchQueue(label: "com.listexcel.debouncer.internalqueue.\(label)", qos: .userInteractive)
        self.executeQueue = executeQueue
        semaphore = DispatchSemaphoreWrapper(with: 1)
    }

    /// 尾缘防抖。`immediate == true` 时立刻执行并取消挂起任务。
    func perform(immediate: Bool = false, execute: @escaping () -> Void) {
        if immediate {
            cancel()
            execute()
            return
        }
        semaphore.sync {
            resetLocked()
            generation &+= 1
            let gen = generation
            let item = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.executeQueue.async {
                    execute()
                    self.semaphore.sync {
                        if self.generation == gen {
                            self.workItem = nil
                        }
                    }
                }
            }
            workItem = item
            queue.asyncAfter(deadline: .now() + interval, execute: item)
        }
    }

    /// 首缘节流：首次立刻执行；执行完成后再进入 `interval` 冷却，窗口内后续调用丢弃。
    func throttle(execute: @escaping () -> Void) {
        semaphore.sync {
            guard !isThrottling else { return }
            workItem?.cancel()
            workItem = nil
            isThrottling = true
            generation &+= 1
            let gen = generation
            let cooldown = DispatchWorkItem { [weak self] in
                self?.semaphore.sync {
                    guard let self, self.generation == gen else { return }
                    self.isThrottling = false
                    self.workItem = nil
                }
            }
            workItem = cooldown
            executeQueue.async { [weak self] in
                execute()
                guard let self else { return }
                self.semaphore.sync {
                    guard self.generation == gen, self.workItem === cooldown, !cooldown.isCancelled else { return }
                    self.queue.asyncAfter(deadline: .now() + self.interval, execute: cooldown)
                }
            }
        }
    }

    /// 取消尚未执行的防抖任务，并结束节流冷却窗口。
    func cancel() {
        semaphore.sync {
            resetLocked()
        }
    }

    /// 调用方须已持有 `semaphore`。
    private func resetLocked() {
        workItem?.cancel()
        workItem = nil
        isThrottling = false
        generation &+= 1
    }
}

struct DispatchSemaphoreWrapper {
    private let semaphore: DispatchSemaphore

    init(with value: Int) {
        semaphore = DispatchSemaphore(value: value)
    }

    func sync<T>(execute: () throws -> T) rethrows -> T {
        defer { semaphore.signal() }
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        return try execute()
    }
}
