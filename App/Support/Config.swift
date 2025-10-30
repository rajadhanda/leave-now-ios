import Foundation

enum RailProvider {
    case realtimeTrains
    case none
}

enum AppConfig {
    static var railProvider: RailProvider {
        if RTTSecrets.realtimeTrainsApiKey != nil { return .realtimeTrains }
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

import Foundation

struct Config {
    static let tflAppIdKey = "TFL_APP_ID"
    static let tflAppKeyKey = "TFL_APP_KEY"
    static let openWeatherKey = "OPENWEATHER_API_KEY"
    static let rttUsernameKey = "REALTIMETRAINS_USERNAME"
    static let rttPasswordKey = "REALTIMETRAINS_PASSWORD"
}
