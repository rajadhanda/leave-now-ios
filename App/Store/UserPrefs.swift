import Foundation

/// User-editable settings, persisted in `UserDefaults`. Defaults fall back to the
/// demo trip so a fresh install still produces a recommendation.
final class UserPrefs {
    static let shared = UserPrefs()
    private init() {}

    private let defaults = UserDefaults.standard

    // MARK: - Trip

    var originPostcode: String {
        get { defaults.string(forKey: Keys.origin) ?? DemoConfig.originPostcode }
        set { defaults.set(newValue, forKey: Keys.origin) }
    }

    var destinationPostcode: String {
        get { defaults.string(forKey: Keys.destination) ?? DemoConfig.destinationPostcode }
        set { defaults.set(newValue, forKey: Keys.destination) }
    }

    /// Whether the user has a target arrival time. When false the app defaults to
    /// "leave now"; when true it computes leave-now / leave-in-N / wait.
    var arriveByEnabled: Bool {
        get { defaults.bool(forKey: Keys.arriveByEnabled) }
        set { defaults.set(newValue, forKey: Keys.arriveByEnabled) }
    }

    /// Target arrival time. Defaults to 09:00 today when unset.
    var arriveBy: Date {
        get {
            let t = defaults.double(forKey: Keys.arriveBy)
            return t == 0 ? Self.defaultArriveBy() : Date(timeIntervalSinceReferenceDate: t)
        }
        set { defaults.set(newValue.timeIntervalSinceReferenceDate, forKey: Keys.arriveBy) }
    }

    // MARK: - Sensitivity & scoring weights

    /// Rain sensitivity `k` in the walking penalty (see
    /// `DefaultETAEstimator.applyWeatherPenalty`). 0.5 hits the calibration
    /// target of ~+2m light / ~+4m heavy rain on a 10-minute walk.
    var rainSensitivity: Double {
        get { read(Keys.rainSensitivity, default: 0.5) }
        set { defaults.set(newValue, forKey: Keys.rainSensitivity) }
    }

    var alphaVariance: Double {
        get { read(Keys.alpha, default: 0.7) }
        set { defaults.set(newValue, forKey: Keys.alpha) }
    }

    var betaChanges: Double {
        get { read(Keys.beta, default: 2.0) }
        set { defaults.set(newValue, forKey: Keys.beta) }
    }

    var gammaWalking: Double {
        get { read(Keys.gamma, default: 0.3) }
        set { defaults.set(newValue, forKey: Keys.gamma) }
    }

    var deltaComfort: Double {
        get { read(Keys.delta, default: 1.0) }
        set { defaults.set(newValue, forKey: Keys.delta) }
    }

    // MARK: - Helpers

    /// Reads a Double, returning `default` when the key has never been set
    /// (so a legitimately-stored 0 is preserved).
    private func read(_ key: String, default def: Double) -> Double {
        defaults.object(forKey: key) == nil ? def : defaults.double(forKey: key)
    }

    private static func defaultArriveBy() -> Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private enum Keys {
        static let origin = "originPostcode"
        static let destination = "destinationPostcode"
        static let arriveByEnabled = "arriveByEnabled"
        static let arriveBy = "arriveBy"
        static let rainSensitivity = "rainSensitivity"
        static let alpha = "alphaVariance"
        static let beta = "betaChanges"
        static let gamma = "gammaWalking"
        static let delta = "deltaComfort"
    }
}
