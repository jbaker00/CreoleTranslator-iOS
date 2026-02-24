//
//  UserLocationMapView.swift
//  CreoleTranslator
//
//  MapKit view displaying a pin for each recorded user session location.
//

import SwiftUI
import MapKit

struct UserLocationMapView: UIViewRepresentable {
    let sessions: [AppSession]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .standard
        mapView.showsUserLocation = false
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations)

        // Filter out sentinel (0, 0) values that represent sessions logged without
        // location data. Using || keeps valid single-zero coordinates (e.g. Prime Meridian).
        let validSessions = sessions.filter { $0.latitude != 0 || $0.longitude != 0 }
        let annotations: [MKPointAnnotation] = validSessions.map { session in
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(
                latitude: session.latitude,
                longitude: session.longitude
            )
            annotation.title = session.city != "Unknown" ? session.city : session.country
            annotation.subtitle = session.timestamp.formatted(date: .abbreviated, time: .shortened)
            return annotation
        }

        mapView.addAnnotations(annotations)

        if annotations.isEmpty {
            // Default world overview when there are no pins yet
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 180)
            )
            mapView.setRegion(region, animated: false)
        } else {
            mapView.showAnnotations(annotations, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let identifier = "SessionPin"
            let pinView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            pinView.annotation = annotation
            pinView.markerTintColor = .systemBlue
            pinView.glyphImage = UIImage(systemName: "person.fill")
            pinView.canShowCallout = true
            return pinView
        }
    }
}

#Preview {
    UserLocationMapView(sessions: [])
        .frame(height: 300)
        .ignoresSafeArea()
}
