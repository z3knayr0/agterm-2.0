import Foundation

/// Split pane management
@MainActor
public final class SplitPaneModel: Sendable {
    public enum Axis: String, Codable, Sendable {
        case horizontal
        case vertical
    }

    public struct PaneNode: Identifiable, Sendable {
        public let id: UUID
        public let sessionID: UUID?
        public var axis: Axis?
        public var children: [PaneNode]?
        public var ratio: Double = 0.5

        public init(sessionID: UUID) {
            self.id = UUID()
            self.sessionID = sessionID
        }

        public init(axis: Axis, children: [PaneNode]) {
            self.id = UUID()
            self.sessionID = nil
            self.axis = axis
            self.children = children
        }
    }

    private var root: PaneNode?

    public init() {
        // Start with no splits
    }

    /// Split a pane along an axis
    public func split(_ sessionID: UUID, axis: Axis) -> UUID {
        let newPane = PaneNode(sessionID: UUID())
        let oldPane = PaneNode(sessionID: sessionID)

        let parentNode = PaneNode(axis: axis, children: [oldPane, newPane])
        root = parentNode

        return newPane.sessionID ?? UUID()
    }

    /// Close a pane
    public func close(_ sessionID: UUID) {
        guard let root = root else { return }
        close(sessionID, in: root)
    }

    private func close(_ sessionID: UUID, in node: PaneNode) -> Bool {
        if let children = node.children {
            for child in children where child.sessionID == sessionID {
                return true
            }
            for child in children {
                if close(sessionID, in: child) {
                    return true
                }
            }
        }
        return false
    }

    /// Get root pane
    public func rootPane() -> PaneNode? {
        root
    }

    /// Get all session IDs in split
    public func allSessions() -> [UUID] {
        guard let root = root else { return [] }
        return allSessions(in: root).compactMap { $0 }
    }

    private func allSessions(in node: PaneNode) -> [UUID?] {
        if let sessionID = node.sessionID {
            return [sessionID]
        }
        guard let children = node.children else { return [] }
        return children.flatMap { allSessions(in: $0) }
    }

    /// Clear splits
    public func clear() {
        root = nil
    }
}
