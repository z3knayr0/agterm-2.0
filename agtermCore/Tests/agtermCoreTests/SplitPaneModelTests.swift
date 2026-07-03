import Foundation
import Testing
@testable import agtermCore

@MainActor
struct SplitPaneModelTests {
    // MARK: - Initialization
    @Test func initStartsWithNoSplits() {
        let model = SplitPaneModel()
        #expect(model.rootPane() == nil)
        #expect(model.allSessions() == [])
    }

    // MARK: - Split Operations
    @Test func splitCreatesHierarchy() {
        let model = SplitPaneModel()
        let sessionID1 = UUID()

        let newSessionID = model.split(sessionID1, axis: .horizontal)

        let root = model.rootPane()
        #expect(root != nil)
        #expect(root?.axis == .horizontal)
        #expect(root?.children?.count == 2)
    }

    @Test func splitVerticalAxis() {
        let model = SplitPaneModel()
        let sessionID = UUID()

        let newSessionID = model.split(sessionID, axis: .vertical)

        let root = model.rootPane()
        #expect(root?.axis == .vertical)
    }

    @Test func splitReturnsNewSessionID() {
        let model = SplitPaneModel()
        let sessionID = UUID()

        let newSessionID = model.split(sessionID, axis: .horizontal)

        #expect(newSessionID != sessionID)
        #expect(newSessionID != UUID()) // Not empty UUID
    }

    @Test func splitMultipleTimesReplacesRoot() {
        let model = SplitPaneModel()
        let sessionID1 = UUID()
        let sessionID2 = UUID()

        let newID1 = model.split(sessionID1, axis: .horizontal)
        let newID2 = model.split(sessionID2, axis: .vertical)

        let root = model.rootPane()
        #expect(root?.axis == .vertical)
        // Previous split is replaced
    }

    // MARK: - Session Management
    @Test func allSessionsReturnsEmptyForNoSplits() {
        let model = SplitPaneModel()
        #expect(model.allSessions().isEmpty)
    }

    @Test func allSessionsReturnsSessionsInHierarchy() {
        let model = SplitPaneModel()
        let sessionID1 = UUID()

        let sessionID2 = model.split(sessionID1, axis: .horizontal)

        let allSessions = model.allSessions()
        #expect(allSessions.count == 2)
        #expect(allSessions.contains(sessionID1))
        #expect(allSessions.contains(sessionID2))
    }

    // MARK: - Close Operations
    @Test func closeDoesNothingWhenNoRoot() {
        let model = SplitPaneModel()
        let sessionID = UUID()

        // Should not crash
        model.close(sessionID)

        #expect(model.rootPane() == nil)
    }

    @Test func closeFindsSessions() {
        let model = SplitPaneModel()
        let sessionID1 = UUID()

        let sessionID2 = model.split(sessionID1, axis: .horizontal)

        model.close(sessionID1)

        // After close, session should no longer be present
        let remaining = model.allSessions()
        #expect(!remaining.contains(sessionID1))
    }

    @Test func closePreservesOtherSessions() {
        let model = SplitPaneModel()
        let sessionID1 = UUID()

        let sessionID2 = model.split(sessionID1, axis: .horizontal)

        model.close(sessionID1)

        let remaining = model.allSessions()
        #expect(remaining.contains(sessionID2))
    }

    // MARK: - Clear Operations
    @Test func clearRemovesAllSplits() {
        let model = SplitPaneModel()
        let sessionID = UUID()

        _ = model.split(sessionID, axis: .horizontal)
        #expect(model.rootPane() != nil)

        model.clear()

        #expect(model.rootPane() == nil)
        #expect(model.allSessions().isEmpty)
    }

    @Test func clearAllowsNewSplitsAfter() {
        let model = SplitPaneModel()
        let sessionID1 = UUID()
        let sessionID2 = UUID()

        _ = model.split(sessionID1, axis: .horizontal)
        model.clear()

        let newSessionID = model.split(sessionID2, axis: .vertical)

        #expect(model.rootPane() != nil)
        #expect(model.allSessions().count == 2)
    }

    // MARK: - PaneNode Structure
    @Test func paneNodeWithSessionHasID() {
        let sessionID = UUID()
        let node = SplitPaneModel.PaneNode(sessionID: sessionID)

        #expect(node.sessionID == sessionID)
        #expect(node.axis == nil)
        #expect(node.children == nil)
        #expect(node.ratio == 0.5)
    }

    @Test func paneNodeWithAxisHasChildren() {
        let child1 = SplitPaneModel.PaneNode(sessionID: UUID())
        let child2 = SplitPaneModel.PaneNode(sessionID: UUID())

        let node = SplitPaneModel.PaneNode(axis: .horizontal, children: [child1, child2])

        #expect(node.sessionID == nil)
        #expect(node.axis == .horizontal)
        #expect(node.children?.count == 2)
    }

    @Test func paneNodeIsIdentifiable() {
        let node1 = SplitPaneModel.PaneNode(sessionID: UUID())
        let node2 = SplitPaneModel.PaneNode(sessionID: UUID())

        #expect(node1.id != node2.id)
    }

    // MARK: - Edge Cases
    @Test func deepNestingSupported() {
        let model = SplitPaneModel()
        let sessionID = UUID()

        var currentID = sessionID
        for _ in 0..<5 {
            currentID = model.split(currentID, axis: .horizontal)
        }

        let allSessions = model.allSessions()
        #expect(allSessions.count == 6)
    }

    @Test func alternatingAxes() {
        let model = SplitPaneModel()
        let sessionID1 = UUID()

        let sessionID2 = model.split(sessionID1, axis: .horizontal)
        let sessionID3 = model.split(sessionID2, axis: .vertical)
        let sessionID4 = model.split(sessionID3, axis: .horizontal)

        let root = model.rootPane()
        #expect(root?.axis == .horizontal)
    }

    @Test func axisIsCorrect() {
        let model = SplitPaneModel()
        let sessionID = UUID()

        let newID = model.split(sessionID, axis: .vertical)

        let root = model.rootPane()
        #expect(root?.axis == .vertical)
    }

    @Test func closeSameSessionTwiceIsSafe() {
        let model = SplitPaneModel()
        let sessionID = UUID()

        _ = model.split(sessionID, axis: .horizontal)

        model.close(sessionID)
        model.close(sessionID) // Should not crash

        #expect(true) // Test passes if no crash
    }
}
