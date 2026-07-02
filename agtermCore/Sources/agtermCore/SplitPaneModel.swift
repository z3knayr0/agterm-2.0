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
        let newSessionID = UUID()
        let newPane = PaneNode(sessionID: newSessionID)
        let oldPane = PaneNode(sessionID: sessionID)
        let parentNode = PaneNode(axis: axis, children: [oldPane, newPane])

        if root == nil {
            root = parentNode
        } else {
            var root = root!
            if !split(sessionID, axis: axis, newPane: newPane, in: &root) {
                // If sessionID not found in tree, replace root
                root = parentNode
            }
            self.root = root
        }

        return newSessionID
    }

    private func split(_ sessionID: UUID, axis: Axis, newPane: PaneNode, in node: inout PaneNode) -> Bool {
        // Check if this node is the one to split
        if node.sessionID == sessionID {
            let oldPane = PaneNode(sessionID: sessionID)
            node = PaneNode(axis: axis, children: [oldPane, newPane])
            return true
        }

        // Recursively search children
        if var children = node.children {
            for i in 0..<children.count {
                if split(sessionID, axis: axis, newPane: newPane, in: &children[i]) {
                    node.children = children
                    return true
                }
            }
        }

        return false
    }

    /// Close a pane
    public func close(_ sessionID: UUID) {
        guard var root = root else { return }
        if close(sessionID, in: &root) {
            self.root = root
        }
    }

    private func close(_ sessionID: UUID, in node: inout PaneNode) -> Bool {
        if var children = node.children {
            children.removeAll { $0.sessionID == sessionID }

            // If only one child remains after removal, promote it
            if children.count == 1 {
                node = children[0]
                return true
            }

            node.children = children

            for i in 0..<children.count {
                if close(sessionID, in: &node.children![i]) {
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
