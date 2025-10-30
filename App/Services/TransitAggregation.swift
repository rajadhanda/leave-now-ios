import Foundation

struct TransitAggregation {
    let railService: NationalRailService?

    init() {
        switch AppConfig.railProvider {
        case .realtimeTrains:
            self.railService = RealtimeTrainsService()
        case .none:
            self.railService = nil
        }
    }

    func enrichWithRail(_ cand: JourneyCandidate, originCRS: String?, destCRS: String?, at when: Date) async -> JourneyCandidate {
        guard let railService, let o = originCRS, let d = destCRS else { return cand }
        do {
            let services = try await railService.nextServices(from: o, to: d, around: when, limit: 3)
            if let meta = services.first {
                return JourneyCandidate(
                    label: cand.label,
                    lineSequence: cand.lineSequence,
                    legsMinutes: cand.legsMinutes,
                    changes: cand.changes,
                    walkingMinutes: cand.walkingMinutes,
                    platformHint: meta.departure.platform ?? cand.platformHint,
                    rail: .init(meta: meta)
                )
            }
        } catch {
            // Graceful failure: keep original candidate
        }
        return cand
    }
}


