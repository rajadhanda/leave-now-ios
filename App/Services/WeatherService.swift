import Foundation
import CoreLocation

protocol WeatherServiceProtocol {
    func currentWeather(at coordinate: CLLocationCoordinate2D) async throws -> Weather
}

final class WeatherService: WeatherServiceProtocol {
    private let session: URLSession = .shared
    private let apiKey: String

    init(apiKey: String) { self.apiKey = apiKey }

    func currentWeather(at coordinate: CLLocationCoordinate2D) async throws -> Weather {
        var comps = URLComponents(string: "https://api.openweathermap.org/data/3.0/onecall")!
        comps.queryItems = [
            .init(name: "lat", value: String(coordinate.latitude)),
            .init(name: "lon", value: String(coordinate.longitude)),
            .init(name: "exclude", value: "minutely,hourly,daily,alerts"),
            .init(name: "appid", value: apiKey),
            .init(name: "units", value: "metric")
        ]
        let (data, _) = try await session.data(from: comps.url!)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let current = json?["current"] as? [String: Any]
        let rain = (current?["rain"] as? [String: Any])?["1h"] as? Double ?? 0.0
        return Weather(precipitationMmPerHr: rain)
    }
}
