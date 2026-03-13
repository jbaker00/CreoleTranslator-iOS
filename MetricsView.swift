//
//  MetricsView.swift
//  CreoleTranslator
//
//  Displays app usage metrics with charts and statistics
//

import SwiftUI

struct MetricsView: View {
    @ObservedObject var metricsManager: MetricsManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("📊")
                        .font(.system(size: 50))
                    Text("App Metrics")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("Usage statistics and analytics")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                // Period summaries
                VStack(spacing: 16) {
                    MetricsPeriodCard(
                        title: "Today",
                        icon: "calendar",
                        metrics: metricsManager.getMetrics(for: "today")
                    )

                    MetricsPeriodCard(
                        title: "Yesterday",
                        icon: "calendar.badge.clock",
                        metrics: metricsManager.getMetrics(for: "yesterday")
                    )

                    MetricsPeriodCard(
                        title: "Last 30 Days",
                        icon: "calendar.badge.plus",
                        metrics: metricsManager.getMetrics(for: "30days")
                    )
                }
                .padding(.horizontal, 20)

                // 7-day chart
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.accentColor)
                        Text("Last 7 Days")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 20)

                    SevenDayChartView(dailyMetrics: metricsManager.getDailyMetrics(days: 7))
                        .frame(height: 280)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 8)

                // Version breakdown
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "app.badge")
                            .foregroundColor(.accentColor)
                        Text("Version Breakdown (30 Days)")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 20)

                    VStack(spacing: 8) {
                        let versionData = metricsManager.getVersionBreakdown(for: "30days")
                        if versionData.isEmpty {
                            Text("No data available")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(versionData, id: \.version) { item in
                                VersionMetricRow(
                                    version: item.version,
                                    sessions: item.sessions,
                                    events: item.events
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 8)

                Spacer(minLength: 40)
            }
        }
        .background(
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(UIColor.systemGray6), Color(UIColor.systemBackground)]
                    : [Color(red: 0.4, green: 0.2, blue: 0.8), Color(red: 0.8, green: 0.3, blue: 0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}

struct MetricsPeriodCard: View {
    let title: String
    let icon: String
    let metrics: MetricsSummary

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }

            HStack(spacing: 30) {
                MetricBadge(label: "Sessions", value: metrics.sessions, color: .blue)
                MetricBadge(label: "Events", value: metrics.events, color: .green)
                Spacer()
            }
        }
        .padding(20)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

struct MetricBadge: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct SevenDayChartView: View {
    let dailyMetrics: [DailyMetric]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Chart for Sessions
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                    Text("Sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                BarChartView(
                    data: dailyMetrics.map { ($0.dayOfWeek, $0.sessions) },
                    color: .blue
                )
                .frame(height: 100)
            }
            .padding(16)
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(12)

            // Chart for Events
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Events")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                BarChartView(
                    data: dailyMetrics.map { ($0.dayOfWeek, $0.events) },
                    color: .green
                )
                .frame(height: 100)
            }
            .padding(16)
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(12)
        }
    }
}

struct BarChartView: View {
    let data: [(label: String, value: Int)]
    let color: Color

    private var maxValue: Int {
        data.map { $0.value }.max() ?? 1
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<data.count, id: \.self) { index in
                    VStack(spacing: 4) {
                        // Value label
                        Text("\(data[index].value)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(height: 14)
                            .opacity(data[index].value > 0 ? 1 : 0)

                        // Bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(
                                width: (geometry.size.width - CGFloat(data.count - 1) * 8) / CGFloat(data.count),
                                height: maxValue > 0 ? max(4, (CGFloat(data[index].value) / CGFloat(maxValue)) * (geometry.size.height - 30)) : 4
                            )

                        // Day label
                        Text(data[index].label)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(height: 12)
                    }
                }
            }
        }
    }
}

struct VersionMetricRow: View {
    let version: String
    let sessions: Int
    let events: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Version \(version)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }

            Spacer()

            HStack(spacing: 16) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(sessions)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Text("sessions")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(events)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    Text("events")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    MetricsView(metricsManager: MetricsManager())
}
