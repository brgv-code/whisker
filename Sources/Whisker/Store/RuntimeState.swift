import WhiskerCore
import os

/// The only state shared between the UI and the input thread, behind one lock.
final class RuntimeState: Sendable {
    struct Snapshot: Sendable {
        var settings = Settings()
        var frontmostApp: String?
        var isDetecting = false
    }

    private let lock = OSAllocatedUnfairLock(initialState: Snapshot())

    func snapshot() -> Snapshot {
        lock.withLock { $0 }
    }

    func update(_ change: @Sendable (inout Snapshot) -> Void) {
        lock.withLock { change(&$0) }
    }
}
