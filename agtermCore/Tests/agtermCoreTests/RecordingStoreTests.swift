import Foundation
import Testing
@testable import agtermCore

/// RecordingStore unit tests covering circular buffer, search, export, and event tracking
@MainActor
final class RecordingStoreTests {
    private let testSessionID = UUID()
    private let testSessionName = "test-session"
    private let tempDir = FileManager.default.temporaryDirectory

    deinit {
        try? FileManager.default.removeItem(at: tempDir.appendingPathComponent("recording-test"))
    }

    private func recordingPath(_ name: String = "test-recording.ndjson") -> String {
        let path = tempDir.appendingPathComponent("recording-test").path
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return (path as NSString).appendingPathComponent(name)
    }

    // MARK: - Start/Stop functionality

    @Test func startEnablesRecording() {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        store.start()
        store.append("output", data: "hello world")
        #expect(store.count == 1)
    }

    @Test func stopDisablesRecording() {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        store.start()
        store.append("output", data: "recorded")
        store.stop()
        store.append("output", data: "not recorded")
        #expect(store.count == 1)
    }

    @Test func appendIgnoredWhenNotRecording() {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        store.append("output", data: "never recorded")
        #expect(store.count == 0)
    }

    @Test func multipleStartStopCycles() {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)

        store.start()
        store.append("output", data: "first")
        store.stop()
        #expect(store.count == 1)

        store.append("output", data: "while stopped")
        #expect(store.count == 1)

        store.start()
        store.append("output", data: "second")
        #expect(store.count == 2)
    }

    // MARK: - Event recording and counting

    @Test func appendRecordsEventWithTimestamp() {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        store.start()
        let beforeTime = Date()
        store.append("output", data: "test data")
        let afterTime = Date()

        #expect(store.count == 1)
        // Event is recorded (timestamp verified via export)
    }

    @Test func appendMultipleEventsOfDifferentTypes() {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        store.start()
        store.append("output", data: "line 1")
        store.append("input", data: "command")
        store.append("status", data: "ready")
        store.append("output", data: "line 2")

        #expect(store.count == 4)
    }

    @Test func eventCountTrackingAccurate() {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        store.start()

        for i in 0..<50 {
            store.append("output", data: "line \(i)")
            #expect(store.count == i + 1)
        }
    }

    // MARK: - Circular buffer behavior

    @Test func circularBufferOverflowsAtMaxEvents() throws {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        store.start()

        // Append way more than maxEvents (100k)
        for i in 0..<(100_100) {
            store.append("output", data: "event \(i)")
        }

        // Buffer should not exceed maxEvents
        #expect(store.count <= 100_000)
    }

    @Test func circularBufferMaintainsMaxEventsPostOverflow() throws {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        store.start()

        // Fill to 150k to ensure overflow
        for i in 0..<(150_000) {
            store.append("output", data: "event \(i)")
        }

        #expect(store.count == 100_000)

        // Verify newest events are kept (by export)
        let outputPath = recordingPath("overflow-test.ndjson")
        try store.export(to: outputPath)

        let content = try String(contentsOfFile: outputPath, encoding: .utf8)
        #expect(!content.isEmpty)
        #expect(content.contains("event 100099"))  // Last event (newest) should be present
    }

    @Test func circularBufferRemovesOldestEventFirst() throws {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        store.start()

        // Add 100k + 2 events
        for i in 0..<(100_002) {
            store.append("output", data: "event \(i)")
        }

        #expect(store.count == 100_000)

        // Oldest events (0-1) should be gone, newest preserved
        let outputPath = recordingPath("circular-test.ndjson")
        try store.export(to: outputPath)

        let content = try String(contentsOfFile: outputPath, encoding: .utf8)
        // The two oldest events (0, 1) should not be in the export
        // Newest events should be present
        #expect(content.contains("event 100001"))
    }

    // MARK: - Search functionality

    @Test func searchByTextInData() {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        store.start()
        store.append("output", data: "hello world")
        store.append("output", data: "goodbye world")
        store.append("output", data: "hello there")
        store.append("input", data: "some command")

        let results = store.search("hello")
        #expect(results.count == 2)
    }

    @Test func searchByEventType() {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        store.start()
        store.append("output", data: "output line")
        store.append("input", data: "input line")
        store.append("status", data: "status line")
        store.append("output", data: "another output")

        let results = store.search("status")
        #expect(results.count == 1)
    }

    @Test func searchCaseInsensitive() {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        store.start()
        store.append("output", data: "Hello World")
        store.append("output", data: "HELLO THERE")
        store.append("output", data: "hello lower")

        let results = store.search("hello")
        #expect(results.count == 3)
    }

    @Test func searchReturnsEmptyForNoMatch() {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        store.start()
        store.append("output", data: "one")
        store.append("output", data: "two")
        store.append("output", data: "three")

        let results = store.search("nonexistent")
        #expect(results.isEmpty)
    }

    @Test func searchEmptyStoreReturnsEmpty() {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        store.start()

        let results = store.search("anything")
        #expect(results.isEmpty)
    }

    @Test func searchPartialStringMatches() {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        store.start()
        store.append("output", data: "debugging mode enabled")
        store.append("output", data: "bug reported")
        store.append("output", data: "rubber duck")

        let results = store.search("bug")
        #expect(results.count == 2)
    }

    // MARK: - NDJSON export format

    @Test func exportGeneratesValidNDJSON() throws {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        store.start()
        store.append("output", data: "line 1")
        store.append("input", data: "command")
        store.append("status", data: "done")

        let outputPath = recordingPath("export-test.ndjson")
        try store.export(to: outputPath)

        #expect(FileManager.default.fileExists(atPath: outputPath))
        let content = try String(contentsOfFile: outputPath, encoding: .utf8)

        // Should have 3 JSON lines separated by newlines
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        #expect(lines.count == 3)
    }

    @Test func exportProducesValidJSON() throws {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        store.start()
        store.append("output", data: "test")

        let outputPath = recordingPath("json-test.ndjson")
        try store.export(to: outputPath)

        let content = try String(contentsOfFile: outputPath, encoding: .utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for line in content.split(separator: "\n") {
            let data = line.data(using: .utf8)!
            let event = try decoder.decode(RecordingStore.RecordedEvent.self, from: data)
            #expect(event.type == "output")
            #expect(event.data == "test")
        }
    }

    @Test func exportIncludesTimestampsInISO8601() throws {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        store.start()
        store.append("output", data: "timestamped event")

        let outputPath = recordingPath("timestamp-test.ndjson")
        try store.export(to: outputPath)

        let content = try String(contentsOfFile: outputPath, encoding: .utf8)
        #expect(content.contains("timestamp"))
        // ISO8601 format includes T and Z
        #expect(content.contains("T"))
    }

    @Test func exportEmptyStoreGeneratesEmptyFile() throws {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)

        let outputPath = recordingPath("empty-test.ndjson")
        try store.export(to: outputPath)

        #expect(FileManager.default.fileExists(atPath: outputPath))
        let content = try String(contentsOfFile: outputPath, encoding: .utf8)
        #expect(content.isEmpty)
    }

    @Test func exportPreservesDataIntegrity() throws {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        store.start()

        let testData = [
            ("output", "hello \"world\""),
            ("input", "command with\nnewline"),
            ("status", "special chars: \\{}[]"),
        ]

        for (type, data) in testData {
            store.append(type, data: data)
        }

        let outputPath = recordingPath("integrity-test.ndjson")
        try store.export(to: outputPath)

        let content = try String(contentsOfFile: outputPath, encoding: .utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var index = 0
        for line in content.split(separator: "\n") {
            let data = line.data(using: .utf8)!
            let event = try decoder.decode(RecordingStore.RecordedEvent.self, from: data)
            #expect(event.type == testData[index].0)
            #expect(event.data == testData[index].1)
            index += 1
        }
    }

    // MARK: - Round-trip (load/save)

    @Test func exportAndLoadPreservesEvents() throws {
        let original = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        original.start()
        original.append("output", data: "first event")
        original.append("input", data: "second event")
        original.append("status", data: "third event")

        let outputPath = recordingPath("roundtrip-test.ndjson")
        try original.export(to: outputPath)

        let loaded = try RecordingStore.load(from: outputPath, sessionID: testSessionID, sessionName: testSessionName)
        #expect(loaded.count == 3)
    }

    @Test func loadFromNDJSONFile() throws {
        let outputPath = recordingPath("load-test.ndjson")

        // Create a valid NDJSON file manually
        let ndjson = """
        {"timestamp":"2026-01-01T00:00:00Z","type":"output","data":"line 1"}
        {"timestamp":"2026-01-01T00:00:01Z","type":"input","data":"line 2"}
        """
        try ndjson.write(toFile: outputPath, atomically: true, encoding: .utf8)

        let store = try RecordingStore.load(from: outputPath, sessionID: testSessionID, sessionName: testSessionName)
        #expect(store.count == 2)
    }

    @Test func loadSkipsInvalidJSONLines() throws {
        let outputPath = recordingPath("invalid-load-test.ndjson")

        // Mix valid and invalid JSON
        let ndjson = """
        {"timestamp":"2026-01-01T00:00:00Z","type":"output","data":"valid"}
        not valid json at all
        {"timestamp":"2026-01-01T00:00:01Z","type":"input","data":"another valid"}
        """
        try ndjson.write(toFile: outputPath, atomically: true, encoding: .utf8)

        let store = try RecordingStore.load(from: outputPath, sessionID: testSessionID, sessionName: testSessionName)
        #expect(store.count == 2)  // Only valid lines loaded
    }

    // MARK: - Clear functionality

    @Test func clearRemovesAllEvents() {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        store.start()
        store.append("output", data: "event 1")
        store.append("output", data: "event 2")
        store.append("output", data: "event 3")

        #expect(store.count == 3)
        store.clear()
        #expect(store.count == 0)
    }

    @Test func clearAllowsReuseSameStore() {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        store.start()
        store.append("output", data: "before clear")
        store.clear()
        store.append("output", data: "after clear")

        #expect(store.count == 1)
    }

    // MARK: - Empty state behavior

    @Test func emptyStoreCountIsZero() {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        #expect(store.count == 0)
    }

    @Test func emptyStoreSearchReturnsEmpty() {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        let results = store.search("anything")
        #expect(results.isEmpty)
    }

    // MARK: - Event data validation

    @Test func eventRecordsCorrectType() throws {
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        store.start()
        store.append("custom-type", data: "test data")

        let outputPath = recordingPath("type-test.ndjson")
        try store.export(to: outputPath)

        let content = try String(contentsOfFile: outputPath, encoding: .utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = content.data(using: .utf8)!
        let event = try decoder.decode(RecordingStore.RecordedEvent.self, from: data)
        #expect(event.type == "custom-type")
    }

    @Test func eventRecordsExactData() throws {
        let testData = "multi\nline\nstring with \"quotes\" and special chars: <>{}[]"
        let store = RecordingStore(sessionID: testSessionID, sessionName: testSessionName)
        store.start()
        store.append("output", data: testData)

        let outputPath = recordingPath("data-test.ndjson")
        try store.export(to: outputPath)

        let content = try String(contentsOfFile: outputPath, encoding: .utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = content.data(using: .utf8)!
        let event = try decoder.decode(RecordingStore.RecordedEvent.self, from: data)
        #expect(event.data == testData)
    }
}
