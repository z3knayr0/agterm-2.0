import Foundation

/// Analytics metrics collection
@MainActor
public final class MetricsCollector: Sendable {
    public struct Metric: Codable, Sendable {
        public let name: String
        public let value: Double
        public let timestamp: Date
        public let tags: [String: String]?
    }

    private var metrics: [Metric] = []
    private let maxMetrics = 10_000

    /// Record a metric
    public func record(_ name: String, value: Double, tags: [String: String]? = nil) {
        let metric = Metric(name: name, value: value, timestamp: Date(), tags: tags)
        metrics.append(metric)

        // Circular buffer
        if metrics.count > maxMetrics {
            metrics.removeFirst()
        }
    }

    /// Get all metrics
    public func all() -> [Metric] {
        metrics
    }

    /// Get metrics by name
    public func by(name: String) -> [Metric] {
        metrics.filter { $0.name == name }
    }

    /// Get metrics in time range
    public func inRange(_ start: Date, _ end: Date) -> [Metric] {
        metrics.filter { $0.timestamp >= start && $0.timestamp <= end }
    }

    /// Get summary statistics using Welford's algorithm to prevent overflow
    public func summary() -> [String: Double] {
        var summary: [String: Double] = [:]

        for metric in metrics {
            let key = "\(metric.name)_avg"
            let countKey = "\(metric.name)_count"

            if summary[countKey] == nil {
                summary[countKey] = 0
                summary[key] = 0
            }

            summary[countKey]! += 1
            let prevAvg = summary[key]!
            // Welford's algorithm: avoids overflow on large values
            summary[key]! = prevAvg + (metric.value - prevAvg) / summary[countKey]!
        }

        return summary
    }

    /// Reset metrics
    public func reset() {
        metrics.removeAll()
    }

    /// Export metrics to JSON file
    public func export(to outputPath: String) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(metrics)
        try data.write(to: URL(fileURLWithPath: outputPath))
    }
}
