import Foundation

/// Reads API credentials from a plist-shaped dictionary. This is the single
/// source of truth for secrets: nothing reads credentials from `Info.plist`.
/// Blank or whitespace-only values are treated as absent, so a placeholder or
/// empty string never makes a provider look configured.
struct SecretsStore {
    private let dict: [String: Any]

    init(dict: [String: Any]) { self.dict = dict }

    /// The app's bundled `Secrets.plist` (git-ignored; copy from
    /// `Secrets.plist.example`). Missing file just means no credentials.
    static let main = SecretsStore(dict: loadMainDict())

    private static func loadMainDict() -> [String: Any] {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let d = obj as? [String: Any] else { return [:] }
        return d
    }

    private func string(_ key: String) -> String? {
        guard let raw = dict[key] as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var tflAppKey: String { string(Config.tflAppKeyKey) ?? "" }
    var openWeatherKey: String { string(Config.openWeatherKeyKey) ?? "" }
    var realtimeTrainsBaseURL: URL? { string(Config.rttBaseURLKey).flatMap { URL(string: $0) } }
    var realtimeTrainsToken: String? { string(Config.rttTokenKey) }
    var hereApiKey: String? { string(Config.hereApiKeyKey) }
    var googleApiKey: String? { string(Config.googleMapsApiKeyKey) }
}

/// Convenience facade over the bundled `Secrets.plist` for call sites.
enum Secrets {
    static var tflAppKey: String { SecretsStore.main.tflAppKey }
    static var openWeatherKey: String { SecretsStore.main.openWeatherKey }
    static var realtimeTrainsBaseURL: URL? { SecretsStore.main.realtimeTrainsBaseURL }
    static var realtimeTrainsToken: String? { SecretsStore.main.realtimeTrainsToken }
    static var hereApiKey: String? { SecretsStore.main.hereApiKey }
    static var googleApiKey: String? { SecretsStore.main.googleApiKey }
}
