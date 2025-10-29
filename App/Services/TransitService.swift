import Foundation

// MARK: - DTOs
struct TfLJourneyResponse: Decodable { let journeys: [TfLJourney] }
struct TfLJourney: Decodable { let legs: [TfLLeg] }
struct TfLLeg: Decodable {
    let mode: TfLMode
    let duration: Int
    let lineId: String?
    let departurePoint: TfLPoint?
    let arrivalPoint: TfLPoint?
}
struct TfLPoint: Decodable { let commonName: String }
struct TfLDisruption: Decodable { let lineId: String; let description: String; let isSevere: Bool }

enum TfLMode: String, Decodable { case walking = "walking", tube = "tube", bus = "bus", dlr = "dlr", overground = "overground", nationalRail = "national-rail" }

// MARK: - Service
protocol TransitServiceProtocol {
    func fetchJourneyPlans(origin: String, destination: String, departure: Date) async throws -> [JourneyPlan]
    func fetchDisruptions() async throws -> [Disruption]
}

final class TransitService: TransitServiceProtocol {
    private let session: URLSession = .shared
    private let base = URL(string: "https://api.tfl.gov.uk")!
    private let appId: String
    private let appKey: String

    init(appId: String, appKey: String) {
        self.appId = appId
        self.appKey = appKey
    }

    func fetchJourneyPlans(origin: String, destination: String, departure: Date) async throws -> [JourneyPlan] {
        var comps = URLComponents(url: base.appendingPathComponent("/Journey/JourneyResults/\(origin)/to/\(destination)"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "date", value: ISO8601DateFormatter().string(from: departure)),
            .init(name: "app_id", value: appId),
            .init(name: "app_key", value: appKey)
        ]
        let (data, _) = try await session.data(from: comps.url!)
        let decoded = try JSONDecoder().decode(TfLJourneyResponse.self, from: data)
        return decoded.journeys.map { j in
            let legs: [RouteLeg] = j.legs.map { l in
                let mode: LegMode = {
                    switch l.mode {
                    case .walking: return .walk
                    case .tube: return .tube
                    case .bus: return .bus
                    case .dlr: return .dlr
                    case .overground: return .overground
                    case .nationalRail: return .nationalRail
                    }
                }()
                return RouteLeg(
                    mode: mode,
                    lineId: l.lineId,
                    fromStation: l.departurePoint?.commonName,
                    toStation: l.arrivalPoint?.commonName,
                    durationMinutes: l.duration
                )
            }
            return JourneyPlan(legs: legs)
        }
    }

    func fetchDisruptions() async throws -> [Disruption] {
        var comps = URLComponents(url: base.appendingPathComponent("/Line/Mode/tube,dlr,overground,elizabeth-line/Status"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "app_id", value: appId),
            .init(name: "app_key", value: appKey)
        ]
        let (data, _) = try await session.data(from: comps.url!)
        // Simplified; real DTO mapping would inspect lineStatuses
        let raw = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        var disruptions: [Disruption] = []
        for item in raw {
            guard let lineId = item["id"] as? String else { continue }
            // naive: if line has disruptions, mark moderate
            let hasDisruption = (item["lineStatuses"] as? [[String: Any]] ?? []).contains { ($0["statusSeverity"] as? Int ?? 10) != 10 }
            if hasDisruption {
                disruptions.append(Disruption(lineId: lineId, affectedStations: [], severity: .moderate))
            }
        }
        return disruptions
    }
}
