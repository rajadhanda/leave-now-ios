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
    static var railProvider: RailProvider {
        if RTTSecrets.realtimeTrainsApiKey != nil { return .realtimeTrains }
        return .none
    }
    
    static var trafficProvider: TrafficProvider {
        if TrafficSecrets.hereApiKey != nil { return .here }
        if TrafficSecrets.googleApiKey != nil { return .google }
        return .none
    }
}

enum RTTSecrets {
    static var realtimeTrainsBaseURL: URL? {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "REALTIMETRAINS_BASE_URL") as? String,
              let url = URL(string: s) else { return nil }
        return url
    }
    static var realtimeTrainsApiKey: String? {
        Bundle.main.object(forInfoDictionaryKey: "REALTIMETRAINS_API_KEY") as? String
    }
}

enum TrafficSecrets {
    static var hereApiKey: String? {
        Bundle.main.object(forInfoDictionaryKey: "HERE_API_KEY") as? String
    }
    
    static var googleApiKey: String? {
        Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String
    }
}

import Foundation

struct Config {
    static let tflAppIdKey = "TFL_APP_ID"
    static let tflAppKeyKey = "TFL_APP_KEY"
    static let openWeatherKey = "OPENWEATHER_API_KEY"
    static let rttUsernameKey = "REALTIMETRAINS_USERNAME"
    static let rttPasswordKey = "REALTIMETRAINS_PASSWORD"
    static let hereApiKey = "HERE_API_KEY"
    static let googleMapsApiKey = "GOOGLE_MAPS_API_KEY"
}
