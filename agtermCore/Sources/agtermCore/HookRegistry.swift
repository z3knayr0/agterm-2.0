import Foundation

/// Event hooks: register callbacks for session events
@MainActor
public final class HookRegistry: Sendable {
    public enum EventType: String, Codable, Sendable {
        case sessionCreated = "session.created"
        case sessionClosed = "session.closed"
        case sessionActive = "session.active"
        case sessionInactive = "session.inactive"
        case inputReceived = "input.received"
        case outputReceived = "output.received"
    }

    public struct Hook: Identifiable, Sendable {
        public let id: UUID
        public let event: EventType
        public let command: String
        public var isEnabled: Bool

        public init(event: EventType, command: String, isEnabled: Bool = true) {
            self.id = UUID()
            self.event = event
            self.command = command
            self.isEnabled = isEnabled
        }
    }

    private var hooks: [Hook] = []

    /// Register a hook
    public func register(event: EventType, command: String) -> UUID {
        let hook = Hook(event: event, command: command)
        hooks.append(hook)
        return hook.id
    }

    /// Unregister a hook
    public func unregister(id: UUID) {
        hooks.removeAll { $0.id == id }
    }

    /// Enable/disable a hook
    public func setEnabled(_ id: UUID, _ enabled: Bool) {
        if let index = hooks.firstIndex(where: { $0.id == id }) {
            hooks[index].isEnabled = enabled
        }
    }

    /// Get all hooks
    public func all() -> [Hook] {
        hooks
    }

    /// Get hooks for an event
    public func hooksFor(_ event: EventType) -> [Hook] {
        hooks.filter { $0.event == event && $0.isEnabled }
    }

    /// Fire a hook
    public func fire(_ event: EventType, context: [String: String] = [:]) {
        for hook in hooksFor(event) {
            DispatchQueue.global().async {
                // Execute hook command with context as environment
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/sh")
                process.arguments = ["-c", hook.command]
                try? process.run()
            }
        }
    }

    /// Clear all hooks
    public func clear() {
        hooks.removeAll()
    }
}
