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

    /// Close a pane and remove it from the tree
    public func close(_ sessionID: UUID) {
        guard var currentRoot = root else { return }
        if let updated = closeNode(sessionID, in: currentRoot) {
            root = updated
        } else {
            // Session was the root pane itself
            root = nil
        }
    }

    private func closeNode(_ sessionID: UUID, in node: PaneNode) -> PaneNode? {
        // If this node is the target, return nil to remove it
        if node.sessionID == sessionID {
            return nil
        }

        // Recursively close in children
        guard var children = node.children else { return node }

        var updatedChildren: [PaneNode] = []
        for child in children {
            if let updated = closeNode(sessionID, in: child) {
                updatedChildren.append(updated)
            }
        }

        // If no children remain after closing, remove this parent too
        guard !updatedChildren.isEmpty else { return nil }

        // If only one child remains, collapse the hierarchy
        if updatedChildren.count == 1 {
            return updatedChildren[0]
        }

        // Multiple children remain, update and return
        var updated = node
        updated.children = updatedChildren
        return updated
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
