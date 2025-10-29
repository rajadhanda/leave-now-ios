import Foundation

#if DEBUG
struct BacktestHarness {
    static func run() -> RecommendationResult? {
        let j1 = JourneyPlan(legs: [
            RouteLeg(mode: .walk, lineId: nil, fromStation: nil, toStation: nil, durationMinutes: 5),
            RouteLeg(mode: .tube, lineId: "district", fromStation: "", toStation: "", durationMinutes: 15)
        ])
        let j2 = JourneyPlan(legs: [
            RouteLeg(mode: .walk, lineId: nil, fromStation: nil, toStation: nil, durationMinutes: 7),
            RouteLeg(mode: .tube, lineId: "jubilee", fromStation: "", toStation: "", durationMinutes: 12)
        ])
        let disruptions = [Disruption(lineId: "district", affectedStations: [], severity: .minor)]
        let rec = RecommenderV2(kRain: 0.08, alpha: 0.7, beta: 2, gamma: 0.3, delta: 1.0)
        return rec.recommend(plans: [j1, j2], weather: Weather(precipitationMmPerHr: 0.5), disruptions: disruptions)
    }
}
#endif
