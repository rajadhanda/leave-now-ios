import Foundation

enum RailProvider {
    case realtimeTrains
    case none
}

enum TrafficProvider {
    case here
    case google
    case none
}

enum AppConfig {
    static var railProvider: RailProvider { railProvider(secrets: .main) }

    /// RealtimeTrains needs both a base URL and a Bearer token to be usable.
    static func railProvider(secrets: SecretsStore) -> RailProvider {
        if secrets.realtimeTrainsBaseURL != nil, secrets.realtimeTrainsToken != nil {
            return .realtimeTrains
        }
        return .none
    }

    static var trafficProvider: TrafficProvider { trafficProvider(secrets: .main) }

    static func trafficProvider(secrets: SecretsStore) -> TrafficProvider {
        if secrets.hereApiKey != nil { return .here }
        if secrets.googleApiKey != nil { return .google }
        return .none
    }
}

/// Key names in `Secrets.plist`.
enum Config {
    static let tflAppKeyKey = "TFL_APP_KEY"
    static let openWeatherKeyKey = "OPENWEATHER_API_KEY"
    static let rttBaseURLKey = "REALTIMETRAINS_BASE_URL"
    static let rttTokenKey = "REALTIMETRAINS_TOKEN"
    static let hereApiKeyKey = "HERE_API_KEY"
    static let googleMapsApiKeyKey = "GOOGLE_MAPS_API_KEY"
}
