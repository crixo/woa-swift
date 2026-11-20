import Foundation
import Network

/// Quick "is there a network connection right now?" check, used to avoid waiting for long
/// request timeouts when the machine is offline.
enum NetworkMonitor {

    static func isOnline(timeout: TimeInterval = 2) async -> Bool {
        let probe = Probe()
        return await withCheckedContinuation { continuation in
            probe.start(timeout: timeout, continuation: continuation)
        }
    }

    /// Owns the monitor and resumes the continuation exactly once.
    /// All mutable state is guarded by `lock`, hence `@unchecked Sendable`.
    private final class Probe: @unchecked Sendable {
        private let lock = NSLock()
        private let monitor = NWPathMonitor()
        private let queue = DispatchQueue(label: "NetworkMonitor.isOnline")
        private var continuation: CheckedContinuation<Bool, Never>?

        func start(timeout: TimeInterval, continuation: CheckedContinuation<Bool, Never>) {
            lock.lock()
            self.continuation = continuation
            lock.unlock()

            monitor.pathUpdateHandler = { [self] path in
                finish(path.status == .satisfied)
            }
            monitor.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) { [self] in
                finish(false)
            }
        }

        private func finish(_ online: Bool) {
            lock.lock()
            let pending = continuation
            continuation = nil
            lock.unlock()

            guard let pending else { return }
            monitor.pathUpdateHandler = nil   // breaks the monitor → handler → probe reference cycle
            monitor.cancel()
            pending.resume(returning: online)
        }
    }
}
