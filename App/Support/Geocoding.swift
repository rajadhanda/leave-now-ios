import Foundation
import CoreLocation

enum GeocodingError: Error { case notFound }

final class GeocodingHelper {
    private let geocoder = CLGeocoder()

    func geocode(postcode: String) async throws -> CLLocationCoordinate2D {
        let placemarks = try await geocoder.geocodeAddressString(postcode)
        if let coord = placemarks.first?.location?.coordinate { return coord }
        throw GeocodingError.notFound
    }
}


