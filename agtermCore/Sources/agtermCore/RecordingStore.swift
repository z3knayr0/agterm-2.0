import Foundation

/// Circular buffer recording of session events for search, replay, and export
@MainActor
public final class RecordingStore: Sendable {
    /// Max events in buffer (100k events = ~50MB typical)
    private static let maxEvents = 100_000

    /// Recorded event: session output line or metadata
    public struct RecordedEvent: Codable, Sendable {
        let timestamp: Date
        let type: String // "output", "input", "status"
        let data: String
    }

    private var events: [RecordedEvent] = []
    private var isRecording = false
    private let sessionID: UUID
    private let sessionName: String

    public init(sessionID: UUID, sessionName: String) {
        self.sessionID = sessionID
        self.sessionName = sessionName
    }

    /// Start recording events
    public func start() {
        isRecording = true
    }

    /// Stop recording
    public func stop() {
        isRecording = false
    }

    /// Append an event if recording
    public func append(_ type: String, data: String) {
        guard isRecording else { return }
        let event = RecordedEvent(timestamp: Date(), type: type, data: data)
        events.append(event)

        // Circular buffer: drop oldest when full
        if events.count > Self.maxEvents {
            events.removeFirst()
        }
    }

    /// Search events by text predicate
    public func search(_ query: String) -> [RecordedEvent] {
        events.filter { event in
            event.data.localizedCaseInsensitiveContains(query) ||
            event.type.localizedCaseInsensitiveContains(query)
        }
    }

    /// Export recording to NDJSON file
    public func export(to outputPath: String) throws {
        let fileURL = URL(fileURLWithPath: outputPath)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970

        var lines: [String] = []
        for event in events {
            let data = try encoder.encode(event)
            if let line = String(data: data, encoding: .utf8) {
                lines.append(line)
            }
        }

        let ndjson = lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n")
        try ndjson.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// Load recording from NDJSON file
    public static func load(from inputPath: String, sessionID: UUID, sessionName: String) throws -> RecordingStore {
        let fileURL = URL(fileURLWithPath: inputPath)
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let store = RecordingStore(sessionID: sessionID, sessionName: sessionName)
        for line in content.split(separator: "\n") {
            guard let data = line.data(using: .utf8) else { continue }
            if let event = try? decoder.decode(RecordedEvent.self, from: data) {
                store.events.append(event)
            }
        }
        return store
    }

    /// Clear all recorded events
    public func clear() {
        events.removeAll()
    }

    /// Get event count
    public var count: Int { events.count }
}
