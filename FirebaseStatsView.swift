//
//  FirebaseStatsView.swift
//  CreoleTranslator
//
//  Firebase analytics stats dashboard showing session counts, geographic
//  breakdown, and a map view of where users are logging in from.
//

import SwiftUI
import MapKit

struct FirebaseStatsView: View {
    @EnvironmentObject private var service: UserSessionService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if service.isLoading {
                        ProgressView("Loading stats…")
                            .padding(.top, 60)
                    } else if let error = service.errorMessage {
                        errorStateView(message: error)
                    } else {
                        statsContent
                    }
                }
                .padding()
                .padding(.bottom, 20)
            }
            .navigationTitle("App Stats")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { service.fetchSessions() }
        }
    }

    // MARK: - Main Stats Content

    private var statsContent: some View {
        VStack(spacing: 20) {
            // Summary stat cards
            HStack(spacing: 16) {
                StatSummaryCard(
                    value: "\(service.sessions.count)",
                    label: "Total Sessions",
                    icon: "person.3.fill",
                    color: .blue
                )
                StatSummaryCard(
                    value: "\(uniqueCountries.count)",
                    label: "Countries",
                    icon: "globe",
                    color: .green
                )
            }

            HStack(spacing: 16) {
                StatSummaryCard(
                    value: "\(uniqueCities.count)",
                    label: "Cities",
                    icon: "building.2.fill",
                    color: .orange
                )
                StatSummaryCard(
                    value: latestSessionLabel,
                    label: "Last Session",
                    icon: "clock.fill",
                    color: .purple
                )
            }

            // Map view
            VStack(alignment: .leading, spacing: 10) {
                Label("User Locations", systemImage: "map.fill")
                    .font(.headline)
                    .foregroundColor(.primary)

                UserLocationMapView(sessions: service.sessions)
                    .frame(height: 280)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            }

            // Country breakdown
            if !countryBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Sessions by Country", systemImage: "chart.bar.fill")
                        .font(.headline)
                        .foregroundColor(.primary)

                    VStack(spacing: 10) {
                        ForEach(countryBreakdown.prefix(10), id: \.key) { item in
                            CountryBarRow(
                                country: item.key,
                                count: item.value,
                                total: service.sessions.count
                            )
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }

            // Recent sessions list
            if !service.sessions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Recent Sessions", systemImage: "clock.arrow.circlepath")
                        .font(.headline)
                        .foregroundColor(.primary)

                    VStack(spacing: 0) {
                        ForEach(Array(service.sessions.prefix(10).enumerated()), id: \.element.id) { index, session in
                            if index > 0 { Divider().padding(.leading, 44) }
                            SessionRow(session: session)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }

            if service.sessions.isEmpty {
                emptyStateView
            }
        }
    }

    // MARK: - Empty & Error States

    private func errorStateView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundColor(.orange)
            Text("Could not load stats")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") { service.fetchSessions() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.top, 60)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text("No sessions yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Sessions will appear here once users open the app.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    // MARK: - Computed Properties

    private var uniqueCountries: Set<String> {
        Set(service.sessions.map(\.country).filter { $0 != "Unknown" })
    }

    private var uniqueCities: Set<String> {
        Set(service.sessions.map(\.city).filter { $0 != "Unknown" })
    }

    private var countryBreakdown: [(key: String, value: Int)] {
        Dictionary(grouping: service.sessions, by: \.country)
            .mapValues(\.count)
            .sorted { $0.value > $1.value }
    }

    private var latestSessionLabel: String {
        guard let latest = service.sessions.first else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: latest.timestamp, relativeTo: Date())
    }
}

// MARK: - Supporting Views

struct StatSummaryCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Spacer()
            }
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

struct CountryBarRow: View {
    let country: String
    let count: Int
    let total: Int

    private var percentage: Double {
        total > 0 ? Double(count) / Double(total) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(country)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(count)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(UIColor.tertiarySystemBackground))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * CGFloat(percentage), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

struct SessionRow: View {
    let session: AppSession

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(.accentColor)
                .font(.title3)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(locationLabel)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text(session.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var locationLabel: String {
        if session.city != "Unknown" {
            return "\(session.city), \(session.country)"
        }
        return session.country != "Unknown" ? session.country : "Unknown location"
    }
}

#Preview {
    FirebaseStatsView()
        .environmentObject(UserSessionService())
}
