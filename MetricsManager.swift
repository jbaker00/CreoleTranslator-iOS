//
//  MetricsManager.swift
//  CreoleTranslator
//
//  Tracks sessions and events per version with local persistence
//

import Foundation
import FirebaseAnalytics

// Data model for a metric event
struct MetricEvent: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let eventType: EventType
    let appVersion: String

    enum EventType: String, Codable {
        case sessionStart = "session_start"
        case sessionEnd = "session_end"
        case translation = "translation"
        case recordingStarted = "recording_started"
        case recordingStopped = "recording_stopped"
        case ttsPlayed = "tts_played"
        case error = "error"
    }

    init(id: UUID = UUID(), timestamp: Date = Date(), eventType: EventType, appVersion: String) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.appVersion = appVersion
    }
}

// Data model for aggregated metrics
struct MetricsSummary {
    let sessions: Int
    let events: Int
    let period: String // "today", "yesterday", "30days"
}

// Data model for daily metrics (for charts)
struct DailyMetric: Identifiable {
    let id = UUID()
    let date: Date
    let sessions: Int
    let events: Int

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

@MainActor
class MetricsManager: ObservableObject {
    @Published private(set) var events: [MetricEvent] = []
    @Published private(set) var currentSessionId: UUID?

    private let storageKey = "metricsEvents"
    private let maxEvents = 1000 // Limit storage to last 1000 events
    private let currentVersion: String

    init() {
        // Get app version from Info.plist
        self.currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        loadEvents()
    }

    // MARK: - Session Tracking

    func startSession() {
        let sessionId = UUID()
        currentSessionId = sessionId

        let event = MetricEvent(eventType: .sessionStart, appVersion: currentVersion)
        addEvent(event)

        // Log to Firebase Analytics
        Analytics.logEvent("session_start", parameters: [
            "app_version": currentVersion,
            "session_id": sessionId.uuidString
        ])
    }

    func endSession() {
        guard let sessionId = currentSessionId else { return }

        let event = MetricEvent(eventType: .sessionEnd, appVersion: currentVersion)
        addEvent(event)

        // Log to Firebase Analytics
        Analytics.logEvent("session_end", parameters: [
            "app_version": currentVersion,
            "session_id": sessionId.uuidString
        ])

        currentSessionId = nil
    }

    // MARK: - Event Tracking

    func trackEvent(_ eventType: MetricEvent.EventType) {
        let event = MetricEvent(eventType: eventType, appVersion: currentVersion)
        addEvent(event)

        // Log to Firebase Analytics
        Analytics.logEvent(eventType.rawValue, parameters: [
            "app_version": currentVersion
        ])
    }

    private func addEvent(_ event: MetricEvent) {
        events.insert(event, at: 0) // Most recent first

        // Limit storage
        if events.count > maxEvents {
            events = Array(events.prefix(maxEvents))
        }

        saveEvents()
    }

    // MARK: - Metrics Calculations

    func getMetrics(for period: String, version: String? = nil) -> MetricsSummary {
        let filteredEvents = filterEvents(for: period, version: version)

        let sessions = countSessions(in: filteredEvents)
        let totalEvents = filteredEvents.count

        return MetricsSummary(sessions: sessions, events: totalEvents, period: period)
    }

    func getDailyMetrics(days: Int = 7) -> [DailyMetric] {
        let calendar = Calendar.current
        let now = Date()

        var dailyMetrics: [DailyMetric] = []

        for dayOffset in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now),
                  let startOfDay = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: date),
                  let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) else {
                continue
            }

            let dayEvents = events.filter { event in
                event.timestamp >= startOfDay && event.timestamp <= endOfDay
            }

            let sessions = countSessions(in: dayEvents)
            let totalEvents = dayEvents.count

            dailyMetrics.append(DailyMetric(
                date: startOfDay,
                sessions: sessions,
                events: totalEvents
            ))
        }

        return dailyMetrics
    }

    func getVersionBreakdown(for period: String) -> [(version: String, sessions: Int, events: Int)] {
        let filteredEvents = filterEvents(for: period, version: nil)

        // Group by version
        let grouped = Dictionary(grouping: filteredEvents) { $0.appVersion }

        return grouped.map { version, events in
            let sessions = countSessions(in: events)
            return (version: version, sessions: sessions, events: events.count)
        }.sorted { $0.version > $1.version }
    }

    // MARK: - Helper Functions

    private func filterEvents(for period: String, version: String?) -> [MetricEvent] {
        let calendar = Calendar.current
        let now = Date()

        let startDate: Date
        switch period {
        case "today":
            startDate = calendar.startOfDay(for: now)
        case "yesterday":
            guard let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) else {
                return []
            }
            let yesterdayEnd = calendar.startOfDay(for: now)
            return events.filter { event in
                event.timestamp >= yesterdayStart && event.timestamp < yesterdayEnd &&
                (version == nil || event.appVersion == version)
            }
        case "30days":
            guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) else {
                return []
            }
            startDate = thirtyDaysAgo
        default:
            return []
        }

        return events.filter { event in
            event.timestamp >= startDate &&
            (version == nil || event.appVersion == version)
        }
    }

    private func countSessions(in events: [MetricEvent]) -> Int {
        return events.filter { $0.eventType == .sessionStart }.count
    }

    // MARK: - Persistence

    private func saveEvents() {
        if let encoded = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func loadEvents() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([MetricEvent].self, from: data) else {
            return
        }
        events = decoded
    }

    // MARK: - Debug/Admin Functions

    func clearAllMetrics() {
        events = []
        saveEvents()
    }
}
