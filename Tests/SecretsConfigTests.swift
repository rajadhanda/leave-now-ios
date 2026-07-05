import XCTest

@testable import LeaveNow

/// Secrets are only "configured" when genuinely present: empty and
/// whitespace-only values must read as absent so a placeholder never
/// activates a provider.
final class SecretsConfigTests: XCTestCase {
    func testEmptySecretsMeansNoProviders() {
        let secrets = SecretsStore(dict: [:])
        XCTAssertEqual(secrets.tflAppKey, "")
        XCTAssertNil(secrets.realtimeTrainsToken)
        XCTAssertNil(secrets.hereApiKey)
        XCTAssertNil(secrets.googleApiKey)
        XCTAssertEqual(AppConfig.railProvider(secrets: secrets), .none)
        XCTAssertEqual(AppConfig.trafficProvider(secrets: secrets), .none)
    }

    func testBlankAndWhitespaceValuesReadAsAbsent() {
        let secrets = SecretsStore(dict: [
            Config.rttBaseURLKey: "https://data.rtt.io",
            Config.rttTokenKey: "",
            Config.hereApiKeyKey: "   ",
            Config.tflAppKeyKey: "\n"
        ])
        XCTAssertEqual(secrets.tflAppKey, "")
        XCTAssertNil(secrets.realtimeTrainsToken)
        XCTAssertNil(secrets.hereApiKey)
        // Base URL alone must not activate the rail provider.
        XCTAssertEqual(AppConfig.railProvider(secrets: secrets), .none)
    }

    func testFilledSecretsReportProviders() {
        let secrets = SecretsStore(dict: [
            Config.tflAppKeyKey: "tfl-key",
            Config.rttBaseURLKey: "https://data.rtt.io",
            Config.rttTokenKey: "token-123",
            Config.hereApiKeyKey: "here-key"
        ])
        XCTAssertEqual(secrets.tflAppKey, "tfl-key")
        XCTAssertEqual(secrets.realtimeTrainsBaseURL?.absoluteString, "https://data.rtt.io")
        XCTAssertEqual(secrets.realtimeTrainsToken, "token-123")
        XCTAssertEqual(AppConfig.railProvider(secrets: secrets), .realtimeTrains)
        XCTAssertEqual(AppConfig.trafficProvider(secrets: secrets), .here)
    }

    func testGoogleIsFallbackTrafficProvider() {
        let secrets = SecretsStore(dict: [Config.googleMapsApiKeyKey: "g-key"])
        XCTAssertEqual(AppConfig.trafficProvider(secrets: secrets), .google)
    }
}
