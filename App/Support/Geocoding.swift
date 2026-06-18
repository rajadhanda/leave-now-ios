import Foundation
import CoreLocation

enum GeocodingError: Error { case notFound }

/// Process-wide cache of resolved postcodes so repeated refreshes for the same
/// trip are instant and we never re-hit a rate-limited geocoder. Stored as plain
/// doubles to keep the value trivially `Sendable` across the actor boundary.
actor GeocodeCache {
    static let shared = GeocodeCache()
    private var store: [String: (lat: Double, lon: Double)] = [:]

    func coordinate(for key: String) -> (lat: Double, lon: Double)? { store[key] }
    func store(_ value: (lat: Double, lon: Double), for key: String) { store[key] = value }
}

/// Resolves a postcode (or free-form address) to coordinates.
///
/// Primary path is postcodes.io — a free, key-less UK postcode service that is
/// fast and reliable, unlike `CLGeocoder`, which throttles aggressively and does
/// not support concurrent requests. `CLGeocoder` is kept as a fallback for inputs
/// postcodes.io can't resolve (partial postcodes, place names).
final class GeocodingHelper {
    private let geocoder = CLGeocoder()
    private let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    func geocode(postcode: String) async throws -> CLLocationCoordinate2D {
        let key = postcode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !key.isEmpty else { throw GeocodingError.notFound }

        if let cached = await GeocodeCache.shared.coordinate(for: key) {
            return CLLocationCoordinate2D(latitude: cached.lat, longitude: cached.lon)
        }

        // 1) postcodes.io (UK, free, no API key, fast).
        if let coord = try? await postcodesIO(key) {
            await GeocodeCache.shared.store((coord.latitude, coord.longitude), for: key)
            return coord
        }

        // 2) CLGeocoder fallback for anything postcodes.io can't resolve.
        let placemarks = try await geocoder.geocodeAddressString(postcode)
        if let coord = placemarks.first?.location?.coordinate {
            await GeocodeCache.shared.store((coord.latitude, coord.longitude), for: key)
            return coord
        }
        throw GeocodingError.notFound
    }

    private func postcodesIO(_ postcode: String) async throws -> CLLocationCoordinate2D {
        let compact = postcode.replacingOccurrences(of: " ", with: "")
        guard let encoded = compact.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.postcodes.io/postcodes/\(encoded)") else {
            throw GeocodingError.notFound
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 10
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GeocodingError.notFound
        }
        let dto = try JSONDecoder().decode(PostcodesIOResponse.self, from: data)
        guard let r = dto.result else { throw GeocodingError.notFound }
        return CLLocationCoordinate2D(latitude: r.latitude, longitude: r.longitude)
    }

    private struct PostcodesIOResponse: Decodable {
        let result: Result?
        struct Result: Decodable { let latitude: Double; let longitude: Double }
    }
}
