import SwiftUI
import CoreLocation


struct LeaveNowView: View {
    @StateObject private var vm = RecommendationViewModel()
    

    var body: some View {
        NavigationStack {
            ScrollView {
                RecommendationCard(vm: vm)
                    .padding()
            }
            .navigationTitle("Leave Now?")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refresh() }
                    } label: { Image(systemName: "arrow.clockwise") }
                }
            }
            .task { await refresh() }
        }
       
    }

    private func refresh() async {
        do {
            // 1) Resolve coordinates quickly (prefer DemoConfig fast map; fallback to geocoder)
            let originCoord: CLLocationCoordinate2D
            let destCoord: CLLocationCoordinate2D
            if let o = DemoConfig.coords(for: DemoConfig.originPostcode), let d = DemoConfig.coords(for: DemoConfig.destinationPostcode) {
                originCoord = .init(latitude: o.lat, longitude: o.lon)
                destCoord = .init(latitude: d.lat, longitude: d.lon)
            } else {
                let geocoder = GeocodingHelper()
                async let oCoord = geocoder.geocode(postcode: DemoConfig.originPostcode)
                async let dCoord = geocoder.geocode(postcode: DemoConfig.destinationPostcode)
                let (o, d) = try await (oCoord, dCoord)
                originCoord = o
                destCoord = d
            }

            // 2) Fetch journey plans from TfL
            let tfl = TflTransitService()
            let plans = try await tfl.journeyPlans(from: originCoord, to: destCoord, departure: Date())
            guard !plans.isEmpty else {
                vm.bind(Self.mockRecommendation())
                return
            }

            // 3) Weather at origin
            let weatherSvc = OpenWeatherService()
            let rain = try await weatherSvc.currentRainIntensity(at: originCoord.latitude, lon: originCoord.longitude)
            let rainEnd: Date? = try? await weatherSvc.rainEndTime(at: originCoord.latitude, lon: originCoord.longitude, horizonHours: 12)
            let weather: Weather? = rain.map { Weather(precipitationMmPerHr: $0) }

            // 4) Realtime Trains (optional): Euston (EUS) → Milton Keynes Central (MKC)
            var railMeta: RailLegMeta? = nil
            if let rtt = RealtimeTrainsService() {
                if let first = try? await rtt.nextServices(from: "EUS", to: "MKC", around: Date(), limit: 1).first {
                    railMeta = first
                }
            }

            // 5) Fetch traffic data for car legs (if any)
            let originGeo = GeoPoint(lat: originCoord.latitude, lon: originCoord.longitude)
            let destGeo = GeoPoint(lat: destCoord.latitude, lon: destCoord.longitude)
            let trafficAggregation = TrafficAggregation()
            let trafficInfoByPlan = await trafficAggregation.fetchTrafficForPlans(plans, origin: originGeo, destination: destGeo, departureTime: Date())
            
            // 6) Score and select best/fallback
            let recV2 = RecommenderV2(kRain: UserPrefs.shared.rainSensitivity, alpha: 0.7, beta: 2.0, gamma: 0.3, delta: 1.0)
            let disruptions: [Disruption] = []
            guard let result = recV2.recommend(plans: plans, weather: weather, disruptions: disruptions, trafficInfoByPlan: trafficInfoByPlan) else {
                vm.bind(Self.mockRecommendation())
                return
            }

            // 7) Build UI Recommendation from engine result
            let now = Date()
            let best = result.best
            let fb = result.fallback
            // Compute minutes to first national rail leg (if present)
            let minutesToRail: Int? = {
                var acc = 0
                for leg in best.plan.legs {
                    if leg.mode == .nationalRail { return acc }
                    acc += leg.durationMinutes
                }
                return nil
            }()
            let routeLabel: String = {
                let lines = best.plan.legs.compactMap { $0.lineId }.filter { !$0.isEmpty }
                return lines.isEmpty ? "Suggested route" : lines.joined(separator: " → ")
            }()
            // Enrichment strings for stations/platforms
            let firstTransitLeg = best.plan.legs.first(where: { $0.mode != .walk })
            let startStationText: String? = firstTransitLeg.flatMap { leg in
                let name = (leg.fromStation?.isEmpty == false) ? leg.fromStation : nil
                let toward = (leg.toStation?.isEmpty == false) ? leg.toStation : nil
                let line = (leg.lineId?.isEmpty == false) ? leg.lineId : nil
                let modeLabel: String = {
                    switch leg.mode {
                    case .tube: return "Tube"
                    case .bus: return "Bus"
                    case .overground: return "Overground"
                    case .dlr: return "DLR"
                    case .nationalRail: return "National Rail"
                    case .car: return "Car"
                    case .walk: return "Walk"
                    }
                }()
                if let name { return "\(modeLabel) from: \(name)" }
                if let line, let toward { return "\(modeLabel): take \(line) towards \(toward)" }
                if let line { return "\(modeLabel): take \(line)" }
                return nil
            }
            let hasRailLeg = best.plan.legs.contains(where: { $0.mode == .nationalRail })
            let railPlatformInfo: String? = railMeta.flatMap { meta in
                let timeFmt: DateFormatter = {
                    let df = DateFormatter()
                    df.dateFormat = "HH:mm"
                    return df
                }()
                let timeStr = meta.departure.estimatedTime.map(timeFmt.string) ?? timeFmt.string(from: meta.departure.plannedTime)
                let plat = meta.departure.platform.map { "Platform \($0)" } ?? "Platform TBC"
                return "National Rail: Euston → Milton Keynes Central, depart \(timeStr), \(plat)"
            } ?? (hasRailLeg ? "National Rail: Euston → Milton Keynes Central, live platform unavailable" : nil)
            let platformHintCombined: String? = {
                var parts: [String] = []
                if let s = startStationText { parts.append(s) }
                if let rail = railPlatformInfo { parts.append(rail) }
                return parts.isEmpty ? nil : parts.joined(separator: " • ")
            }()
            let routeSummary: [RouteLegSummary] = best.plan.legs.map { leg in
                RouteLegSummary(type: mapMode(leg.mode), lineOrService: leg.lineId, approxMinutes: leg.durationMinutes)
            }
            let fallbackSummary: ([RouteLegSummary], String, Int, Int)? = fb.map { f in
                let lbl: String = f.plan.legs.compactMap { $0.lineId }.joined(separator: " → ")
                let legs = f.plan.legs.map { RouteLegSummary(type: mapMode($0.mode), lineOrService: $0.lineId, approxMinutes: $0.durationMinutes) }
                return (legs, lbl, f.plan.changes, f.plan.walkMinutes)
            }

            // Optimize departure to reduce wait at Euston when railMeta is known
            var decision: LeaveDecision = .leaveNow
            var recommendedDeparture: Date? = now
            if let railMeta, let m2r = minutesToRail {
                let arrivalAtEuston = Calendar.current.date(byAdding: .minute, value: m2r, to: now) ?? now
                let trainDep = railMeta.departure.estimatedTime ?? railMeta.departure.plannedTime
                let waitSeconds = trainDep.timeIntervalSince(arrivalAtEuston)
                let bufferSeconds: TimeInterval = 5 * 60
                if waitSeconds > (8 * 60) {
                    let depTime = trainDep.addingTimeInterval(-bufferSeconds).addingTimeInterval(Double(-m2r * 60))
                    if depTime > now {
                        decision = .leaveInMinutes
                        recommendedDeparture = depTime
                    }
                }
            }

            let rec = Recommendation(
                id: .init(),
                generatedAt: now,
                context: .init(
                    origin: .init(label: DemoConfig.originPostcode, geo: nil, transitStopID: nil),
                    destination: .init(label: DemoConfig.destinationPostcode, geo: nil, transitStopID: nil),
                    habitualCommute: true,
                    window: .init(recommendedDeparture: recommendedDeparture, mode: decision == .leaveNow ? .now : .inMinutes)
                ),
                decision: decision,
                route: .init(
                    label: routeLabel,
                    fingerprint: .init(lineSequence: best.plan.legs.compactMap { $0.lineId }, stopIds: nil),
                    legs: routeSummary,
                    changes: best.plan.changes,
                    walkingMinutes: best.plan.walkMinutes,
                    platformHint: platformHintCombined,
                    comfort: .minimalWalking
                ),
                fallback: fallbackSummary.map { fs in
                    .init(
                        label: fs.1,
                        fingerprint: .init(lineSequence: fb?.plan.legs.compactMap { $0.lineId } ?? [], stopIds: nil),
                        legs: fs.0,
                        changes: fs.2,
                        walkingMinutes: fs.3,
                        platformHint: nil,
                        comfort: .fewerChanges
                    )
                },
                variance: .init(etaP50Minutes: best.p50Minutes, etaP90Minutes: best.p90Minutes),
                confidence: .init(score: best.confidence, level: best.confidence > 0.75 ? .high : (best.confidence > 0.5 ? .medium : .low), limitingFactors: (rain ?? 0) > 0.1 ? [.weatherImpact] : []),
                rationale: .init(oneLine: best.rationale, highlights: []),
                inputs: .init(
                    dataFreshness: .init(transitUpdatedAt: now, disruptionsUpdatedAt: now, weatherUpdatedAt: now),
                    weather: .init(raining: (rain ?? 0) > 0.1, rainIntensity: rain, walkingPenaltyMinutes: Int(round((rain ?? 0) * 5.0)), rainEndsAt: rainEnd),
                    disruptions: [] as [DisruptionImpact],
                    priorsVersion: "priors-v0.3.2",
                    weights: .init(alphaVariance: 0.7, betaChanges: 2.0, gammaWalking: 0.3, deltaComfort: 1.0)
                ),
                ttlSeconds: 300
            )
            vm.bind(rec)
        } catch {
            vm.bind(Self.mockRecommendation())
        }
    }
}

extension LeaveNowView {
    static func mockRecommendation() -> Recommendation {
        let now = Date()
        return Recommendation(
            id: .init(),
            generatedAt: now,
            context: .init(
                origin: .init(label: "Home", geo: nil, transitStopID: nil),
                destination: .init(label: "Office", geo: nil, transitStopID: nil),
                habitualCommute: true,
                window: .init(recommendedDeparture: Calendar.current.date(byAdding: .minute, value: 4, to: now), mode: .inMinutes)
            ),
            decision: .leaveInMinutes,
            route: .init(
                label: "Northern → Jubilee",
                fingerprint: .init(lineSequence: ["northern","jubilee"], stopIds: nil),
                legs: [
                    .init(type: .walk, lineOrService: nil, approxMinutes: 6),
                    .init(type: .tube, lineOrService: "Northern", approxMinutes: 12),
                    .init(type: .tube, lineOrService: "Jubilee", approxMinutes: 10),
                    .init(type: .walk, lineOrService: nil, approxMinutes: 4)
                ],
                changes: 1, walkingMinutes: 10, platformHint: nil, comfort: .minimalWalking
            ),
            fallback: .init(
                label: "Bus 24 → District",
                fingerprint: .init(lineSequence: ["bus24","district"], stopIds: nil),
                legs: [ .init(type: .bus, lineOrService: "Bus 24", approxMinutes: 18) ],
                changes: 2, walkingMinutes: 7, platformHint: nil, comfort: .fewerChanges
            ),
            variance: .init(etaP50Minutes: 32, etaP90Minutes: 39),
            confidence: .init(score: 0.82, level: .high, limitingFactors: [.weatherImpact]),
            rationale: .init(oneLine: "Light rain adds +2m walking; no delays on your segment.", highlights: []),
            inputs: .init(
                dataFreshness: .init(transitUpdatedAt: now, disruptionsUpdatedAt: now, weatherUpdatedAt: now),
                weather: .init(raining: true, rainIntensity: 0.3, walkingPenaltyMinutes: 2, rainEndsAt: nil),
                disruptions: [],
                priorsVersion: "priors-v0.3.2",
                weights: .init(alphaVariance: 0.7, betaChanges: 2.0, gammaWalking: 0.3, deltaComfort: 1.0)
            ),
            ttlSeconds: 300
        )
    }
}

private func mapMode(_ mode: LegMode) -> LegType {
    switch mode {
    case .walk: return .walk
    case .tube: return .tube
    case .bus: return .bus
    case .overground: return .overground
    case .dlr: return .dlr
    case .nationalRail: return .rail
    case .car: return .car
    }
}

 
