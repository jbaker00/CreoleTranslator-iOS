//
//  UserSessionService.swift
//  CreoleTranslator
//
//  Logs app sessions with location data to Firebase Firestore and
//  fetches historical sessions for display in the stats dashboard.
//

import Foundation
import CoreLocation
import FirebaseFirestore

/// A single app session record with location data.
struct AppSession: Identifiable {
    let id: String
    let timestamp: Date
    let country: String
    let city: String
    let latitude: Double
    let longitude: Double
}

/// Manages session logging to Firestore and fetches sessions for the stats view.
@MainActor
class UserSessionService: NSObject, ObservableObject {
    @Published var sessions: [AppSession] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private let locationManager = CLLocationManager()
    private let collectionName = "app_sessions"

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // MARK: - Session Logging

    /// Called on app launch to record this session in Firestore.
    func logSessionStart() {
        let status = locationManager.authorizationStatus
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            writeSession(latitude: 0, longitude: 0, city: "Unknown", country: "Unknown")
        }
    }

    private func writeSession(latitude: Double, longitude: Double, city: String, country: String) {
        let doc: [String: Any] = [
            "timestamp": Timestamp(date: Date()),
            "latitude": latitude,
            "longitude": longitude,
            "city": city,
            "country": country,
            "platform": "iOS"
        ]
        db.collection(collectionName).addDocument(data: doc) { error in
            if let error {
                print("UserSessionService: failed to log session — \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Fetch Sessions

    func fetchSessions() {
        isLoading = true
        errorMessage = nil
        db.collection(collectionName)
            .order(by: "timestamp", descending: true)
            .limit(to: 500)
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.errorMessage = "Failed to load sessions: \(error.localizedDescription)"
                    return
                }
                self.sessions = (snapshot?.documents ?? []).compactMap { doc in
                    let data = doc.data()
                    guard let ts = data["timestamp"] as? Timestamp,
                          let lat = data["latitude"] as? Double,
                          let lon = data["longitude"] as? Double else { return nil }
                    return AppSession(
                        id: doc.documentID,
                        timestamp: ts.dateValue(),
                        country: data["country"] as? String ?? "Unknown",
                        city: data["city"] as? String ?? "Unknown",
                        latitude: lat,
                        longitude: lon
                    )
                }
            }
    }
}

// MARK: - CLLocationManagerDelegate

extension UserSessionService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(loc) { placemarks, geocodeError in
            if let geocodeError {
                print("UserSessionService: reverse geocoding failed — \(geocodeError.localizedDescription)")
            }
            let placemark = placemarks?.first
            let city = placemark?.locality ?? placemark?.administrativeArea ?? "Unknown"
            let country = placemark?.country ?? "Unknown"
            Task { @MainActor [weak self] in
                self?.writeSession(
                    latitude: loc.coordinate.latitude,
                    longitude: loc.coordinate.longitude,
                    city: city,
                    country: country
                )
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.writeSession(latitude: 0, longitude: 0, city: "Unknown", country: "Unknown")
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            Task { @MainActor [weak self] in
                self?.writeSession(latitude: 0, longitude: 0, city: "Unknown", country: "Unknown")
            }
        default:
            break
        }
    }
}
