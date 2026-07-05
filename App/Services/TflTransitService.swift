import Foundation
import CoreLocation

struct TflTransitService {
    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func journeyPlans(from origin: CLLocationCoordinate2D, to dest: CLLocationCoordinate2D, departure: Date) async throws -> [JourneyPlan] {
        var comps = URLComponents(string: "https://api.tfl.gov.uk/journey/journeyresults")!
        // TfL API form: /journey/journeyresults/{from}/to/{to}
        // We'll construct the full URL manually to include path params and query items
        let fromStr = String(format: "%.6f,%.6f", origin.latitude, origin.longitude)
        let toStr = String(format: "%.6f,%.6f", dest.latitude, dest.longitude)
        comps.path = "/journey/journeyresults/\(fromStr)/to/\(toStr)"
        var items: [URLQueryItem] = []
        // TfL deprecated app_id; app_key alone authenticates. Keyless requests
        // still work but are rate-limited, so a missing key is not fatal.
        let appKey = Secrets.tflAppKey
        if !appKey.isEmpty { items.append(.init(name: "app_key", value: appKey)) }
        // Use departure time to the nearest minute
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmm"
        items.append(.init(name: "date", value: dateFormatter.string(from: departure)))
        items.append(.init(name: "time", value: timeFormatter.string(from: departure)))
        comps.queryItems = items

        guard let url = comps.url else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let dto = try JSONDecoder.tfl.decode(JourneyResultsDTO.self, from: data)
        return dto.toPlans()
    }

    /// Current line-status disruptions, keyed by lowercased line id (e.g. "northern").
    /// Lines with a good service are omitted. Defaults to the rail-like modes that
    /// our journey plans use.
    func disruptions(modes: String = "tube,dlr,overground,elizabeth-line") async throws -> [Disruption] {
        var comps = URLComponents(string: "https://api.tfl.gov.uk/Line/Mode/\(modes)/Status")!
        var items: [URLQueryItem] = []
        let appKey = Secrets.tflAppKey
        if !appKey.isEmpty { items.append(.init(name: "app_key", value: appKey)) }
        if !items.isEmpty { comps.queryItems = items }

        guard let url = comps.url else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let lines = try JSONDecoder().decode([LineStatusDTO].self, from: data)
        return lines.compactMap { line -> Disruption? in
            guard let id = line.id else { return nil }
            let severities = (line.lineStatuses ?? []).compactMap {
                mapTfLSeverity($0.statusSeverity ?? 10, $0.statusSeverityDescription ?? "")
            }
            guard let worst = severities.max(by: { tflSeverityRank($0) < tflSeverityRank($1) }) else { return nil }
            return Disruption(lineId: id.lowercased(), affectedStations: [], severity: worst)
        }
    }
}

// MARK: - Line status decoding

private struct LineStatusDTO: Decodable {
    let id: String?
    let name: String?
    let lineStatuses: [Status]?
    struct Status: Decodable {
        let statusSeverity: Int?
        let statusSeverityDescription: String?
    }
}

/// Maps a TfL status (severity number + description) to our coarse severity, or
/// nil when there is effectively no disruption. The textual description is more
/// reliable than the numeric scale, which is non-monotonic.
private func mapTfLSeverity(_ severity: Int, _ description: String) -> DisruptionSeverity? {
    let desc = description.lowercased()
    if desc.contains("good service") || desc.contains("no issues") { return nil }
    if desc.contains("minor") { return .minor }
    if desc.contains("severe") || desc.contains("suspended") || desc.contains("closure")
        || desc.contains("closed") || desc.contains("not running") || desc.contains("no service") {
        return .severe
    }
    return .moderate
}

private func tflSeverityRank(_ severity: DisruptionSeverity) -> Int {
    switch severity {
    case .minor: return 1
    case .moderate: return 2
    case .severe: return 3
    }
}

// MARK: - Decoding (tolerant, minimal fields)
private struct JourneyResultsDTO: Decodable {
    let journeys: [JourneyDTO]?

    struct JourneyDTO: Decodable {
        let legs: [LegDTO]?
    }

    struct LegDTO: Decodable {
        let mode: ModeDTO?
        let duration: Int?
        let path: PathDTO?
        let departurePoint: StopPointDTO?
        let arrivalPoint: StopPointDTO?
        let routeOptions: [RouteOptionDTO]?
    }

    struct ModeDTO: Decodable { let id: String? }
    struct PathDTO: Decodable { let stopPoints: [StopPointDTO]? }
    struct StopPointDTO: Decodable { let name: String? }
    struct RouteOptionDTO: Decodable { let name: String? }
}

private extension JourneyResultsDTO {
    func toPlans() -> [JourneyPlan] {
        guard let journeys else { return [] }
        return journeys.compactMap { j in
            let legs = (j.legs ?? []).compactMap { l -> RouteLeg? in
                let modeId = l.mode?.id ?? "walk"
                let legMode: LegMode
                switch modeId {
                case "tube": legMode = .tube
                case "bus": legMode = .bus
                case "overground": legMode = .overground
                case "dlr": legMode = .dlr
                case "national-rail": legMode = .nationalRail
                default: legMode = .walk
                }
                let line = l.routeOptions?.first?.name
                let fromName = l.departurePoint?.name
                let toName = l.arrivalPoint?.name
                let minutes = max(1, l.duration ?? 0)
                return RouteLeg(mode: legMode, lineId: line, fromStation: fromName, toStation: toName, durationMinutes: minutes)
            }
            if legs.isEmpty { return nil }
            return JourneyPlan(legs: legs)
        }
    }
}

private extension JSONDecoder {
    static var tfl: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }
}


