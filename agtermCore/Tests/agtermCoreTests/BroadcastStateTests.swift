import Foundation
import Testing
@testable import agtermCore

@MainActor
struct BroadcastStateTests {
    // MARK: - Initialization
    @Test func initStartsDisabled() {
        let state = BroadcastState()
        #expect(state.enabled == false)
        #expect(state.targetCount == 0)
    }

    // MARK: - Enable/Disable Operations
    @Test func enableSetsEnabledFlag() {
        let state = BroadcastState()
        let sessionID = UUID()

        state.enable(for: [sessionID])

        #expect(state.enabled == true)
    }

    @Test func enableSetsSessions() {
        let state = BroadcastState()
        let sessionID1 = UUID()
        let sessionID2 = UUID()

        state.enable(for: [sessionID1, sessionID2])

        #expect(state.targetCount == 2)
        #expect(state.isTarget(sessionID1))
        #expect(state.isTarget(sessionID2))
    }

    @Test func disableClearsState() {
        let state = BroadcastState()
        let sessionID = UUID()

        state.enable(for: [sessionID])
        state.disable()

        #expect(state.enabled == false)
        #expect(state.targetCount == 0)
    }

    @Test func toggleFlipsEnabledState() {
        let state = BroadcastState()

        #expect(state.enabled == false)
        state.toggle()
        #expect(state.enabled == true)
        state.toggle()
        #expect(state.enabled == false)
    }

    // MARK: - Target Session Management
    @Test func addSessionEnablesBroadcast() {
        let state = BroadcastState()
        let sessionID = UUID()

        #expect(state.enabled == false)

        state.add(sessionID)

        #expect(state.enabled == true)
        #expect(state.isTarget(sessionID))
    }

    @Test func addMultipleSessions() {
        let state = BroadcastState()
        let sessionID1 = UUID()
        let sessionID2 = UUID()
        let sessionID3 = UUID()

        state.add(sessionID1)
        state.add(sessionID2)
        state.add(sessionID3)

        #expect(state.targetCount == 3)
        #expect(state.isTarget(sessionID1))
        #expect(state.isTarget(sessionID2))
        #expect(state.isTarget(sessionID3))
    }

    @Test func addDuplicateSessionNoDouble() {
        let state = BroadcastState()
        let sessionID = UUID()

        state.add(sessionID)
        state.add(sessionID)

        #expect(state.targetCount == 1)
    }

    @Test func removeSessionFromTargets() {
        let state = BroadcastState()
        let sessionID1 = UUID()
        let sessionID2 = UUID()

        state.add(sessionID1)
        state.add(sessionID2)

        state.remove(sessionID1)

        #expect(state.targetCount == 1)
        #expect(!state.isTarget(sessionID1))
        #expect(state.isTarget(sessionID2))
    }

    @Test func removeLastSessionDisablesBroadcast() {
        let state = BroadcastState()
        let sessionID = UUID()

        state.add(sessionID)
        #expect(state.enabled == true)

        state.remove(sessionID)

        #expect(state.enabled == false)
        #expect(state.targetCount == 0)
    }

    @Test func removeNonTargetSessionNoChange() {
        let state = BroadcastState()
        let sessionID1 = UUID()
        let sessionID2 = UUID()

        state.add(sessionID1)
        state.remove(sessionID2)

        #expect(state.targetCount == 1)
        #expect(state.isTarget(sessionID1))
    }

    // MARK: - Target Query
    @Test func targetsReturnsEmptyWhenNone() {
        let state = BroadcastState()

        let targets = state.targets()

        #expect(targets.isEmpty)
    }

    @Test func targetsReturnsAllTargets() {
        let state = BroadcastState()
        let sessionID1 = UUID()
        let sessionID2 = UUID()

        state.add(sessionID1)
        state.add(sessionID2)

        let targets = state.targets()

        #expect(targets.count == 2)
        #expect(targets.contains(sessionID1))
        #expect(targets.contains(sessionID2))
    }

    @Test func isTargetCorrectlyIdentifies() {
        let state = BroadcastState()
        let sessionID1 = UUID()
        let sessionID2 = UUID()

        state.add(sessionID1)

        #expect(state.isTarget(sessionID1) == true)
        #expect(state.isTarget(sessionID2) == false)
    }

    // MARK: - Broadcast Input
    @Test func broadcastInputReturnsResultsForAllTargets() {
        let state = BroadcastState()
        let sessionID1 = UUID()
        let sessionID2 = UUID()

        state.add(sessionID1)
        state.add(sessionID2)

        let results = state.broadcast("test input")

        #expect(results.count == 2)
    }

    @Test func broadcastInputReturnsSuccessTrueForEachTarget() {
        let state = BroadcastState()
        let sessionID = UUID()

        state.add(sessionID)

        let results = state.broadcast("test input")

        #expect(results.count == 1)
        #expect(results[0].sessionID == sessionID)
        #expect(results[0].success == true)
    }

    @Test func broadcastEmptyTargetReturnsEmpty() {
        let state = BroadcastState()

        let results = state.broadcast("test input")

        #expect(results.isEmpty)
    }

    @Test func broadcastValidatesInputNoEmptyString() {
        let state = BroadcastState()
        let sessionID = UUID()

        state.add(sessionID)

        let results = state.broadcast("")

        // Input validation passes through (validation at caller level)
        #expect(results.count == 1)
    }

    // MARK: - State Persistence
    @Test func enabledStatePersistedAcrossOperations() {
        let state = BroadcastState()
        let sessionID1 = UUID()
        let sessionID2 = UUID()

        state.enable(for: [sessionID1])
        #expect(state.enabled == true)

        state.add(sessionID2)
        #expect(state.enabled == true)

        state.remove(sessionID2)
        #expect(state.enabled == true)
    }

    @Test func targetSetPersistedAcrossOperations() {
        let state = BroadcastState()
        let sessionID1 = UUID()
        let sessionID2 = UUID()

        state.enable(for: [sessionID1])
        let targets1 = state.targets()

        state.add(sessionID2)
        let targets2 = state.targets()

        #expect(targets1.count == 1)
        #expect(targets2.count == 2)
        #expect(targets2.contains(sessionID1))
    }

    @Test func stateConsistentAfterEnableDisableSequence() {
        let state = BroadcastState()
        let sessionID = UUID()

        state.enable(for: [sessionID])
        state.disable()
        state.enable(for: [])

        #expect(state.enabled == true)
        #expect(state.targetCount == 0)
    }

    // MARK: - Edge Cases
    @Test func enableWithEmptyList() {
        let state = BroadcastState()

        state.enable(for: [])

        #expect(state.enabled == true)
        #expect(state.targetCount == 0)
    }

    @Test func multipleEnableCallsReplacesPrevious() {
        let state = BroadcastState()
        let sessionID1 = UUID()
        let sessionID2 = UUID()

        state.enable(for: [sessionID1])
        state.enable(for: [sessionID2])

        #expect(state.targetCount == 1)
        #expect(state.isTarget(sessionID2))
        #expect(!state.isTarget(sessionID1))
    }

    @Test func broadcastLargeTargetCount() {
        let state = BroadcastState()
        var sessionIDs: [UUID] = []

        for _ in 0..<100 {
            let id = UUID()
            sessionIDs.append(id)
            state.add(id)
        }

        let results = state.broadcast("test")

        #expect(results.count == 100)
        #expect(state.targetCount == 100)
    }
}
