import Foundation

public final class AutosaveScheduler {
    private let interval: TimeInterval
    private let queue: DispatchQueue
    private let lock = NSLock()

    private var pendingAction: (() -> Void)?
    private var pendingWorkItem: DispatchWorkItem?

    public init(
        interval: TimeInterval,
        queue: DispatchQueue = DispatchQueue(label: "Sketchy.AutosaveScheduler")
    ) {
        self.interval = interval
        self.queue = queue
    }

    public func schedule(_ action: @escaping () -> Void) {
        lock.lock()
        pendingWorkItem?.cancel()
        pendingAction = action

        let workItem = DispatchWorkItem { [weak self] in
            self?.runPendingAction()
        }
        pendingWorkItem = workItem
        lock.unlock()

        queue.asyncAfter(deadline: .now() + interval, execute: workItem)
    }

    public func flush() {
        lock.lock()
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        let action = pendingAction
        pendingAction = nil
        lock.unlock()

        action?()
    }

    public func cancel() {
        lock.lock()
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        pendingAction = nil
        lock.unlock()
    }

    private func runPendingAction() {
        lock.lock()
        let action = pendingAction
        pendingAction = nil
        pendingWorkItem = nil
        lock.unlock()

        action?()
    }
}
