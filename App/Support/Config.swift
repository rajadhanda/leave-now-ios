import Foundation

enum RailProvider {
    case realtimeTrains
    case none
}

enum AppConfig {
    static var railProvider: RailProvider {
        if Secrets.realtimeTrainsApiKey != nil { return .realtimeTrains }
        return .none
    }
}

struct Config {
    static let tflAppIdKey = "TFL_APP_ID"
    static let tflAppKeyKey = "TFL_APP_KEY"
    static let openWeatherKey = "OPENWEATHER_API_KEY"
}
