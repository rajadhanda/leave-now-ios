import Foundation

final class UserPrefs {
    static let shared = UserPrefs()
    private init() {}

    private let defaults = UserDefaults.standard

    var rainSensitivity: Double {
        get { defaults.double(forKey: "rainSensitivity") == 0 ? 0.08 : defaults.double(forKey: "rainSensitivity") }
        set { defaults.set(newValue, forKey: "rainSensitivity") }
    }
}
