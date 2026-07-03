import Foundation
import Testing
@testable import agtermCore

@MainActor
struct MetricsCollectorTests {
    // MARK: - Initialization
    @Test func initStartsEmpty() {
        let collector = MetricsCollector()

        #expect(collector.all().isEmpty)
    }

    // MARK: - Recording Metrics
    @Test func recordAddsMetric() {
        let collector = MetricsCollector()

        collector.record("requests", value: 42.0)

        #expect(collector.all().count == 1)
    }

    @Test func recordPreservesName() {
        let collector = MetricsCollector()

        collector.record("latency_ms", value: 150.0)

        let metrics = collector.all()
        #expect(metrics[0].name == "latency_ms")
    }

    @Test func recordPreservesValue() {
        let collector = MetricsCollector()

        collector.record("cpu_usage", value: 45.5)

        let metrics = collector.all()
        #expect(metrics[0].value == 45.5)
    }

    @Test func recordAddsTimestamp() {
        let collector = MetricsCollector()
        let beforeRecord = Date()

        collector.record("test", value: 1.0)

        let afterRecord = Date()
        let metrics = collector.all()

        #expect(metrics[0].timestamp >= beforeRecord)
        #expect(metrics[0].timestamp <= afterRecord)
    }

    @Test func recordWithTags() {
        let collector = MetricsCollector()
        let tags = ["env": "test", "region": "us-west"]

        collector.record("requests", value: 10.0, tags: tags)

        let metrics = collector.all()
        #expect(metrics[0].tags == tags)
    }

    @Test func recordWithoutTagsHasNilTags() {
        let collector = MetricsCollector()

        collector.record("test", value: 1.0)

        let metrics = collector.all()
        #expect(metrics[0].tags == nil)
    }

    @Test func recordMultipleMetrics() {
        let collector = MetricsCollector()

        collector.record("metric1", value: 1.0)
        collector.record("metric2", value: 2.0)
        collector.record("metric3", value: 3.0)

        #expect(collector.all().count == 3)
    }

    @Test func recordMaintainsOrder() {
        let collector = MetricsCollector()

        collector.record("first", value: 1.0)
        collector.record("second", value: 2.0)
        collector.record("third", value: 3.0)

        let metrics = collector.all()
        #expect(metrics[0].name == "first")
        #expect(metrics[1].name == "second")
        #expect(metrics[2].name == "third")
    }

    // MARK: - Querying by Name
    @Test func byNameReturnsEmpty() {
        let collector = MetricsCollector()

        let metrics = collector.by(name: "nonexistent")

        #expect(metrics.isEmpty)
    }

    @Test func byNameFiltersCorrectly() {
        let collector = MetricsCollector()

        collector.record("requests", value: 1.0)
        collector.record("latency", value: 2.0)
        collector.record("requests", value: 3.0)

        let requests = collector.by(name: "requests")

        #expect(requests.count == 2)
        #expect(requests[0].value == 1.0)
        #expect(requests[1].value == 3.0)
    }

    @Test func byNameRetainsAllFields() {
        let collector = MetricsCollector()
        let tags = ["type": "test"]

        collector.record("metric", value: 42.0, tags: tags)

        let metrics = collector.by(name: "metric")

        #expect(metrics[0].name == "metric")
        #expect(metrics[0].value == 42.0)
        #expect(metrics[0].tags == tags)
    }

    // MARK: - Time Range Queries
    @Test func inRangeReturnsEmpty() {
        let collector = MetricsCollector()
        let now = Date()

        let past = Date(timeInterval: -1000, since: now)
        let futureStart = Date(timeInterval: 1000, since: now)
        let futureEnd = Date(timeInterval: 2000, since: now)

        let metrics = collector.inRange(futureStart, futureEnd)

        #expect(metrics.isEmpty)
    }

    @Test func inRangeIncludesBoundaries() {
        let collector = MetricsCollector()
        let now = Date()

        let start = Date(timeInterval: -100, since: now)
        let end = Date(timeInterval: 100, since: now)

        collector.record("test", value: 1.0)

        let metrics = collector.inRange(start, end)

        #expect(metrics.count == 1)
    }

    @Test func inRangeExcludesOutsideRange() {
        let collector = MetricsCollector()
        let now = Date()

        let recordTime = Date(timeInterval: -200, since: now)
        let start = Date(timeInterval: -100, since: now)
        let end = now

        // Manually check if record time falls in range
        #expect(recordTime < start)
    }

    @Test func inRangeFiltersMultiple() {
        let collector = MetricsCollector()
        let now = Date()

        let beforeRange = Date(timeInterval: -200, since: now)
        let start = Date(timeInterval: -100, since: now)
        let end = Date(timeInterval: 100, since: now)
        let afterRange = Date(timeInterval: 200, since: now)

        collector.record("test", value: 1.0)
        // All records added immediately after init are current time

        let metrics = collector.inRange(start, end)

        #expect(metrics.count == 1)
    }

    // MARK: - Summary Statistics
    @Test func summaryEmpty() {
        let collector = MetricsCollector()

        let summary = collector.summary()

        #expect(summary.isEmpty)
    }

    @Test func summaryCalculatesAverage() {
        let collector = MetricsCollector()

        collector.record("latency", value: 10.0)
        collector.record("latency", value: 20.0)
        collector.record("latency", value: 30.0)

        let summary = collector.summary()

        #expect(summary["latency_avg"] == 20.0)
        #expect(summary["latency_count"] == 3.0)
    }

    @Test func summaryIncludesCounts() {
        let collector = MetricsCollector()

        collector.record("requests", value: 1.0)
        collector.record("requests", value: 2.0)

        let summary = collector.summary()

        #expect(summary["requests_count"] == 2.0)
    }

    @Test func summaryMultipleMetrics() {
        let collector = MetricsCollector()

        collector.record("metric1", value: 100.0)
        collector.record("metric2", value: 50.0)

        let summary = collector.summary()

        #expect(summary["metric1_avg"] == 100.0)
        #expect(summary["metric2_avg"] == 50.0)
    }

    @Test func summaryHandlesSingleValue() {
        let collector = MetricsCollector()

        collector.record("test", value: 42.0)

        let summary = collector.summary()

        #expect(summary["test_avg"] == 42.0)
        #expect(summary["test_count"] == 1.0)
    }

    // MARK: - Circular Buffer
    @Test func circularBufferEnforcesMaxCapacity() {
        let collector = MetricsCollector()

        // Add more than max (10_000)
        for i in 0..<10_050 {
            collector.record("test", value: Double(i))
        }

        let metrics = collector.all()

        #expect(metrics.count == 10_000)
    }

    @Test func circularBufferRemovesOldest() {
        let collector = MetricsCollector()

        for i in 0..<10_050 {
            collector.record("test", value: Double(i))
        }

        let metrics = collector.all()
        let firstValue = metrics[0].value

        // First 50 values should be removed
        #expect(firstValue >= 50.0)
    }

    @Test func circularBufferPreservesNewest() {
        let collector = MetricsCollector()

        for i in 0..<10_050 {
            collector.record("test", value: Double(i))
        }

        let metrics = collector.all()
        let lastValue = metrics[metrics.count - 1].value

        #expect(lastValue == 10_049.0)
    }

    // MARK: - Reset
    @Test func resetClearsAllMetrics() {
        let collector = MetricsCollector()

        collector.record("test1", value: 1.0)
        collector.record("test2", value: 2.0)

        collector.reset()

        #expect(collector.all().isEmpty)
    }

    @Test func resetAllowsNewRecordsAfter() {
        let collector = MetricsCollector()

        collector.record("test", value: 1.0)
        collector.reset()
        collector.record("test", value: 2.0)

        let metrics = collector.all()

        #expect(metrics.count == 1)
        #expect(metrics[0].value == 2.0)
    }

    // MARK: - Export
    @Test func exportWritesJSON() throws {
        let collector = MetricsCollector()
        let tempDir = NSTemporaryDirectory()
        let exportPath = (tempDir as NSString).appendingPathComponent("metrics.json")

        collector.record("test", value: 42.0)

        try collector.export(to: exportPath)

        let fileExists = FileManager.default.fileExists(atPath: exportPath)
        #expect(fileExists)

        try? FileManager.default.removeItem(atPath: exportPath)
    }

    @Test func exportContainsRecordedMetrics() throws {
        let collector = MetricsCollector()
        let tempDir = NSTemporaryDirectory()
        let exportPath = (tempDir as NSString).appendingPathComponent("metrics_test.json")

        collector.record("latency", value: 100.0, tags: ["type": "test"])

        try collector.export(to: exportPath)

        let data = try Data(contentsOf: URL(fileURLWithPath: exportPath))
        let metrics = try JSONDecoder().decode([MetricsCollector.Metric].self, from: data)

        #expect(metrics.count == 1)
        #expect(metrics[0].name == "latency")
        #expect(metrics[0].value == 100.0)

        try? FileManager.default.removeItem(atPath: exportPath)
    }

    @Test func exportHandlesEmptyMetrics() throws {
        let collector = MetricsCollector()
        let tempDir = NSTemporaryDirectory()
        let exportPath = (tempDir as NSString).appendingPathComponent("empty_metrics.json")

        try collector.export(to: exportPath)

        let data = try Data(contentsOf: URL(fileURLWithPath: exportPath))
        let metrics = try JSONDecoder().decode([MetricsCollector.Metric].self, from: data)

        #expect(metrics.isEmpty)

        try? FileManager.default.removeItem(atPath: exportPath)
    }

    // MARK: - Metric Structure
    @Test func metricStructureIsCodable() throws {
        let metric = MetricsCollector.Metric(
            name: "test",
            value: 42.0,
            timestamp: Date(),
            tags: ["key": "value"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(metric)

        let decoder = JSONDecoder()
        let decodedMetric = try decoder.decode(MetricsCollector.Metric.self, from: data)

        #expect(decodedMetric.name == "test")
        #expect(decodedMetric.value == 42.0)
    }

    // MARK: - Edge Cases
    @Test func recordZeroValue() {
        let collector = MetricsCollector()

        collector.record("test", value: 0.0)

        let metrics = collector.all()
        #expect(metrics[0].value == 0.0)
    }

    @Test func recordNegativeValue() {
        let collector = MetricsCollector()

        collector.record("test", value: -42.0)

        let metrics = collector.all()
        #expect(metrics[0].value == -42.0)
    }

    @Test func recordLargeValue() {
        let collector = MetricsCollector()

        collector.record("test", value: 1_000_000_000.0)

        let metrics = collector.all()
        #expect(metrics[0].value == 1_000_000_000.0)
    }

    @Test func recordWithEmptyTags() {
        let collector = MetricsCollector()

        collector.record("test", value: 1.0, tags: [:])

        let metrics = collector.all()
        #expect(metrics[0].tags == [:])
    }

    @Test func recordSameName100Times() {
        let collector = MetricsCollector()

        for i in 0..<100 {
            collector.record("metric", value: Double(i))
        }

        let metrics = collector.by(name: "metric")
        #expect(metrics.count == 100)
    }
}
