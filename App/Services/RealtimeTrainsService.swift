import Foundation

/// Client for the next-generation RealtimeTrains API (https://data.rtt.io),
/// spec: https://realtimetrains.github.io/api-specification. The legacy
/// api.rtt.io Basic-auth API shuts down 30 September 2026 and is not used.
///
/// DEV-ONLY: RTT's terms forbid embedding an API token in a distributed
/// end-user app; production use must proxy requests server-side. The service
/// only activates when the git-ignored `Secrets.plist` provides both
/// REALTIMETRAINS_BASE_URL and a REALTIMETRAINS_TOKEN — no shipped build may
/// carry a real token, so release builds get a nil service and rail
/// enrichment is a clean no-op.
struct RealtimeTrainsService: NationalRailService {
    private let session: URLSession
    private let baseURL: URL
    private let token: String

    init?(session: URLSession = .shared,
          baseURL: URL? = Secrets.realtimeTrainsBaseURL,
          token: String? = Secrets.realtimeTrainsToken) {
        guard let baseURL, let token, !token.isEmpty else { return nil }
        self.session = session
        self.baseURL = baseURL
        self.token = token
    }

    /// One `GET /rtt/location` line-up per rail leg. `filterTo` restricts the
    /// line-up to services that subsequently call at the destination.
    ///
    /// RTT rate limits are 30 req/min and 750 req/hr; the updater already
    /// makes at most one call per rail leg and `limit` is capped here, so no
    /// request loop can run unbounded.
    func nextServices(from originCRS: String, to destCRS: String, around when: Date, limit: Int) async throws -> [RailLegMeta] {
        var comps = URLComponents(url: baseURL.appendingPathComponent("/rtt/location"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "code", value: originCRS),
            .init(name: "filterTo", value: destCRS),
            .init(name: "timeFrom", value: Self.queryTimeFormatter.string(from: when))
        ]
        guard let url = comps.url else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try Self.railLegMetas(from: data, originCRS: originCRS, destCRS: destCRS, limit: min(max(limit, 1), 5))
    }

    // MARK: - Decoding

    /// Decodes a `/rtt/location` line-up into `RailLegMeta`s. Internal (not
    /// private) so tests exercise the real decoder against canned fixtures.
    static func railLegMetas(from data: Data, originCRS: String, destCRS: String, limit: Int) throws -> [RailLegMeta] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601 // next-gen times are ISO-8601 with offset
        let lineUp = try decoder.decode(LocationLineUpDTO.self, from: data)
        return (lineUp.services ?? []).prefix(limit).compactMap {
            $0.asRailLegMeta(originCRS: originCRS, destCRS: destCRS)
        }
    }

    /// `timeFrom` is ISO-8601 with offset, matching the response times.
    private static let queryTimeFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}

// MARK: - Next-gen DTOs (tolerant: every realtime field is optional)

/// Response of `GET /rtt/location`: `{ systemStatus, query, services: [...] }`.
/// Internal so `@testable` tests decode with the production types.
struct LocationLineUpDTO: Decodable {
    let services: [ServiceDTO]?

    struct ServiceDTO: Decodable {
        let temporalData: TemporalPairDTO?      // at the queried origin
        let locationMetadata: LocationMetadataDTO?
        let scheduleMetadata: ScheduleMetadataDTO?
        let origin: [LocationPairDTO]?
        let destination: [LocationPairDTO]?     // service's FINAL destination, may differ from filterTo
    }

    struct TemporalPairDTO: Decodable {
        let departure: TemporalDTO?
        let arrival: TemporalDTO?
    }

    struct TemporalDTO: Decodable {
        let scheduleAdvertised: Date?           // GBTT advertised time
        let realtimeForecast: Date?
        let realtimeActual: Date?
        let realtimeAdvertisedLateness: Int?    // minutes
        let realtimeNoReport: Bool?

        var estimated: Date? { realtimeForecast ?? realtimeActual }
        var best: Date? { estimated ?? scheduleAdvertised }
    }

    struct LocationMetadataDTO: Decodable {
        let platform: PlannedActualDTO?
    }

    struct PlannedActualDTO: Decodable {
        let planned: String?
        let forecast: String?
        let actual: String?
    }

    struct ScheduleMetadataDTO: Decodable {
        let uniqueIdentity: String?             // e.g. "gb-nr:L01525:2025-10-26"
        let identity: String?
        let departureDate: String?              // "yyyy-MM-dd"
        let `operator`: OperatorDTO?
        struct OperatorDTO: Decodable { let code: String?; let name: String? }
    }

    struct LocationPairDTO: Decodable {
        let location: LocationDTO?
        let temporalData: TemporalDTO?
        struct LocationDTO: Decodable {
            let description: String?
            let shortCodes: [String]?
            let longCodes: [String]?
        }
    }
}

extension LocationLineUpDTO.ServiceDTO {
    /// Maps one line-up entry to `RailLegMeta`.
    ///
    /// The line-up's `temporalData` describes the queried origin only, and
    /// `destination[]` is the service's final destination — not necessarily
    /// the `filterTo` station. v1 deliberately avoids a second
    /// `/rtt/service?uniqueIdentity=` call: we use `destination[0]` for the
    /// arrival only when its `shortCodes` actually contains the requested CRS,
    /// and otherwise skip the service rather than report a wrong arrival.
    func asRailLegMeta(originCRS: String, destCRS: String) -> RailLegMeta? {
        guard let dep = temporalData?.departure, let depPlanned = dep.scheduleAdvertised ?? dep.best else { return nil }

        guard let finalDest = destination?.first,
              let destCodes = finalDest.location?.shortCodes,
              destCodes.contains(where: { $0.caseInsensitiveCompare(destCRS) == .orderedSame }),
              let arr = finalDest.temporalData,
              let arrPlanned = arr.scheduleAdvertised ?? arr.best else { return nil }

        let platform = locationMetadata?.platform
        return RailLegMeta(
            operatorName: scheduleMetadata?.operator?.name,
            serviceId: scheduleMetadata?.uniqueIdentity,
            headcode: nil, // only the /gb-nr namespace exposes a train reporting identity
            origin: .init(crs: originCRS, name: origin?.first?.location?.description ?? originCRS),
            destination: .init(crs: destCRS, name: finalDest.location?.description ?? destCRS),
            departure: .init(plannedTime: depPlanned,
                             estimatedTime: dep.estimated,
                             platform: platform?.actual ?? platform?.planned),
            arrival: .init(plannedTime: arrPlanned,
                           estimatedTime: arr.estimated,
                           platform: nil)
        )
    }
}
