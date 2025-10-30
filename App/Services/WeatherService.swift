import Foundation

public protocol WeatherService {
    func currentRainIntensity(at lat: Double, lon: Double) async throws -> Double? // 0–1
}

public struct OpenWeatherService: WeatherService {
    private let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    public func currentRainIntensity(at lat: Double, lon: Double) async throws -> Double? {
        let key = Secrets.openWeatherKey
        guard !key.isEmpty else { return nil }
        var comps = URLComponents(string: "https://api.openweathermap.org/data/2.5/weather")!
        comps.queryItems = [
            .init(name: "lat", value: String(lat)),
            .init(name: "lon", value: String(lon)),
            .init(name: "units", value: "metric"),
            .init(name: "appid", value: key)
        ]
        let (data, resp) = try await session.data(from: comps.url!)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let rain = obj?["rain"] as? [String: Any] {
            let mm = (rain["1h"] as? Double) ?? (rain["3h"] as? Double).map { $0 / 3.0 }
            if let mm = mm { return max(0.0, min(mm / 10.0, 1.0)) }
        }
        return nil
    }
}
