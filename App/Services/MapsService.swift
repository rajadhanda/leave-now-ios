import Foundation
import MapKit

protocol MapsServiceProtocol {
    func walkingETA(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> Int
}

final class MapsService: MapsServiceProtocol {
    func walkingETA(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> Int {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .walking
        let directions = MKDirections(request: request)
        let response = try await directions.calculate()
        let seconds = response.routes.first?.expectedTravelTime ?? 0
        return Int(ceil(seconds / 60.0))
    }
}
