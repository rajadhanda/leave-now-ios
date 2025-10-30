import Foundation

public protocol MapsService {
    func walkingMinutes(from: GeoPoint, to: GeoPoint) async throws -> Int
}
