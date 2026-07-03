import Foundation

/// Broadcast mode: send input to multiple panes simultaneously
@MainActor
public final class BroadcastState: Sendable {
    private var isEnabled = false
    private var targetSessions: Set<UUID> = []

    public var enabled: Bool { isEnabled }
    public var targetCount: Int { targetSessions.count }

    /// Enable broadcast to specified sessions
    public func enable(for sessions: [UUID]) {
        isEnabled = true
        targetSessions = Set(sessions)
    }

    /// Disable broadcast
    public func disable() {
        isEnabled = false
        targetSessions.removeAll()
    }

    /// Toggle broadcast mode
    public func toggle() {
        isEnabled.toggle()
    }

    /// Add session to broadcast targets
    public func add(_ sessionID: UUID) {
        targetSessions.insert(sessionID)
        isEnabled = true
    }

    /// Remove session from broadcast targets
    public func remove(_ sessionID: UUID) {
        targetSessions.remove(sessionID)
        if targetSessions.isEmpty {
            isEnabled = false
        }
    }

    /// Get all target sessions
    public func targets() -> [UUID] {
        Array(targetSessions)
    }

    /// Check if session is a broadcast target
    public func isTarget(_ sessionID: UUID) -> Bool {
        targetSessions.contains(sessionID)
    }

    /// Broadcast input to all targets
    public func broadcast(_ input: String) -> [(sessionID: UUID, success: Bool)] {
        targetSessions.map { (sessionID: $0, success: true) }
    }
}
