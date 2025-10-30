import Foundation

enum Secrets {
    private static var dict: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let d = obj as? [String: Any] else { return [:] }
        return d
    }()

    static var tflAppId: String { dict[Config.tflAppIdKey] as? String ?? "" }
    static var tflAppKey: String { dict[Config.tflAppKeyKey] as? String ?? "" }
    static var openWeatherKey: String { dict[Config.openWeatherKey] as? String ?? "" }

    // Values sourced from Info.plist (for Realtime Trains integration)
    static var realtimeTrainsBaseURL: URL? {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "REALTIMETRAINS_BASE_URL") as? String,
              let url = URL(string: s) else { return nil }
        return url
    }
    static var realtimeTrainsApiKey: String? {
        Bundle.main.object(forInfoDictionaryKey: "REALTIMETRAINS_API_KEY") as? String
    }
}
