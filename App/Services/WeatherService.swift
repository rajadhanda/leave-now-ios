import Foundation

public protocol WeatherService {
    func currentRainIntensity(at lat: Double, lon: Double) async throws -> Double? // 0–1
    func rainEndTime(at lat: Double, lon: Double, horizonHours: Int) async throws -> Date?
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

    public func rainEndTime(at lat: Double, lon: Double, horizonHours: Int) async throws -> Date? {
        let key = Secrets.openWeatherKey
        guard !key.isEmpty else { return nil }
        var comps = URLComponents(string: "https://api.openweathermap.org/data/3.0/onecall")!
        comps.queryItems = [
            .init(name: "lat", value: String(lat)),
            .init(name: "lon", value: String(lon)),
            .init(name: "exclude", value: "minutely,daily,alerts"),
            .init(name: "units", value: "metric"),
            .init(name: "appid", value: key)
        ]
        let (data, resp) = try await session.data(from: comps.url!)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        struct OneCall: Decodable { struct Hour: Decodable { let dt: TimeInterval; let pop: Double?; let rain: [String: Double]? }; let hourly: [Hour]? }
        let oc = try JSONDecoder().decode(OneCall.self, from: data)
        let hours = oc.hourly ?? []
        let limit = max(1, min(horizonHours, hours.count))
        // Find first future hour where rain is effectively zero and probability low
        for i in 0..<limit {
            let h = hours[i]
            let mm = h.rain?["1h"] ?? 0.0
            let pop = h.pop ?? 0.0
            if mm <= 0.01 && pop < 0.2 {
                return Date(timeIntervalSince1970: h.dt)
            }
        }
        // If not found, assume rain persists within horizon
        return nil
    }
}
