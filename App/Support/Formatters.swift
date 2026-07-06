import Foundation

extension DateFormatter {
    /// A fixed-format formatter for machine-facing or 24h strings:
    /// en_US_POSIX so user locale/12h settings can't corrupt the format, with
    /// an explicit timezone (default: device-local wall clock). Build these
    /// once and cache — never construct a formatter per parse or per render.
    static func fixed(format: String, timeZone: TimeZone = .current) -> DateFormatter {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = timeZone
        df.dateFormat = format
        return df
    }
}
