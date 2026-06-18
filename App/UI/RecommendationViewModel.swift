import Foundation
import CoreLocation

/// Where the currently-displayed recommendation came from.
enum DataSource { case live, sample }

/// Owns the recommendation pipeline (services -> engine -> decision -> UI model)
/// and the strings the card renders. Kept on the main actor so `@Published`
/// mutations are always delivered on the main thread.
@MainActor
final class RecommendationViewModel: ObservableObject {

    @Published private(set) var rec: Recommendation?
    @Published private(set) var isLoading = false
    @Published private(set) var source: DataSource = .live
    @Published private(set) var statusMessage: String?

    private let prefs = UserPrefs.shared

    init(rec: Recommendation? = nil) { self.rec = rec }

    func bind(_ r: Recommendation) { self.rec = r }

    // MARK: - Orchestration

    func refresh() async {
        isLoading = true
        statusMessage = nil
        defer { isLoading = false }
        do {
            rec = try await buildLiveRecommendation()
            source = .live
        } catch {
            // Show clearly-labelled sample data rather than silently presenting
            // mock output as if it were live.
            rec = Self.mockRecommendation()
            source = .sample
            statusMessage = "Showing sample data — couldn't reach live services."
        }
    }

    private func buildLiveRecommendation() async throws -> Recommendation {
        let origin = prefs.originPostcode
        let destination = prefs.destinationPostcode

        // 1) Coordinates: fast demo map, else geocode.
        let (originCoord, destCoord) = try await resolveCoordinates(origin: origin, destination: destination)

        let departureTime = Date()

        // 2) Public-transport journey plans from TfL. Non-fatal: TfL only covers
        //    London, so for a general commute it may return nothing — we still
        //    want to offer a driving option, so we don't throw here.
        let tfl = TflTransitService()
        var plans = (try? await tfl.journeyPlans(from: originCoord, to: destCoord, departure: departureTime)) ?? []

        // 2b) Enrich National Rail legs with RealtimeTrains (no-op if not configured).
        let rtt = RealtimeTrainsService()
        plans = await NationalRailLegUpdater.updateNationalRailLegs(plans: plans, railService: rtt, departureTime: departureTime)

        // 2c) Always add a driving candidate so a car route can be recommended
        //     when it's the better option (or the only one available).
        if let driving = DrivingRouteService().drivingPlan(from: originCoord, to: destCoord) {
            plans.append(driving)
        }

        guard !plans.isEmpty else { throw AppError.unavailable("journey plans") }

        // 3) Weather at origin (non-fatal if unavailable).
        let weatherSvc = OpenWeatherService()
        let rain: Double? = (try? await weatherSvc.currentRainIntensity(at: originCoord.latitude, lon: originCoord.longitude)) ?? nil
        let rainEnd: Date? = (try? await weatherSvc.rainEndTime(at: originCoord.latitude, lon: originCoord.longitude, horizonHours: 12)) ?? nil
        let weather: Weather? = rain.map { Weather(precipitationMmPerHr: $0) }

        // 4) Live disruptions (non-fatal if unavailable).
        let disruptions: [Disruption] = (try? await tfl.disruptions()) ?? []

        // 5) Traffic for any car legs (no-op without a provider / car legs).
        let originGeo = GeoPoint(lat: originCoord.latitude, lon: originCoord.longitude)
        let destGeo = GeoPoint(lat: destCoord.latitude, lon: destCoord.longitude)
        let trafficInfoByPlan = await TrafficAggregation().fetchTrafficForPlans(plans, origin: originGeo, destination: destGeo, departureTime: Date())

        // 6) Score and select best/fallback using the user's weights.
        let recV2 = RecommenderV2(kRain: prefs.rainSensitivity,
                                  alpha: prefs.alphaVariance,
                                  beta: prefs.betaChanges,
                                  gamma: prefs.gammaWalking,
                                  delta: prefs.deltaComfort)
        guard let result = recV2.recommend(plans: plans, weather: weather, disruptions: disruptions, trafficInfoByPlan: trafficInfoByPlan) else {
            throw AppError.unavailable("recommendation")
        }

        // 7) Decide when to leave.
        let now = Date()
        let best = result.best
        let fb = result.fallback
        let preferFallback = best.severeDisruption && fb != nil
        let arriveBy = prefs.arriveByEnabled ? prefs.arriveBy : nil
        let decisionResult = DepartureDecider().decide(now: now,
                                                        arriveBy: arriveBy,
                                                        p90Minutes: best.p90Minutes,
                                                        preferFallback: preferFallback)

        // 8) Map engine output into the UI recommendation model.
        return makeRecommendation(best: best,
                                  fallback: fb,
                                  decision: decisionResult,
                                  origin: origin,
                                  destination: destination,
                                  rain: rain,
                                  rainEnd: rainEnd,
                                  disruptions: disruptions,
                                  now: now)
    }

    // MARK: - Notifications

    /// Requests authorization and schedules a reminder at the recommended
    /// departure time. Returns false if permission was denied or there's no rec.
    func scheduleLeaveReminder() async -> Bool {
        guard let r = rec else { return false }
        let service = NotificationService()
        guard await service.requestAuthorization() else { return false }
        let fireDate = r.context.window.recommendedDeparture ?? Date()
        await service.scheduleLeaveReminder(
            at: fireDate,
            title: leaveNotificationTitle(for: r),
            body: "\(r.route.label) • ETA \(r.variance.etaP50Minutes) min (P50)"
        )
        return true
    }

    /// Used by background refresh: only nudge when the user should leave now/soon.
    func notifyIfDepartureImminent() async {
        guard let r = rec else { return }
        switch r.decision {
        case .leaveNow, .leaveInMinutes, .takeFallback:
            _ = await scheduleLeaveReminder()
        case .wait:
            break
        }
    }

    private func leaveNotificationTitle(for r: Recommendation) -> String {
        switch r.decision {
        case .leaveNow: return "Leave now"
        case .leaveInMinutes: return "Leave soon"
        case .wait: return "You can wait"
        case .takeFallback: return "Switch to your fallback route"
        }
    }

    // MARK: - Mapping engine -> UI model

    private func makeRecommendation(best: EngineRecommendation,
                                    fallback: EngineRecommendation?,
                                    decision: DepartureDecision,
                                    origin: String,
                                    destination: String,
                                    rain: Double?,
                                    rainEnd: Date?,
                                    disruptions: [Disruption],
                                    now: Date) -> Recommendation {
        let confidenceLevel: ConfidenceLevel = best.confidence > 0.75 ? .high : (best.confidence > 0.5 ? .medium : .low)
        var limiting: [LimitingFactor] = []
        if (rain ?? 0) > 0.1 { limiting.append(.weatherImpact) }
        if best.severeDisruption { limiting.append(.severeDisruptionNearby) }

        let windowMode: DepartureMode = {
            switch decision.decision {
            case .leaveNow, .takeFallback: return .now
            case .leaveInMinutes: return .inMinutes
            case .wait: return .waitMinutes
            }
        }()

        return Recommendation(
            id: .init(),
            generatedAt: now,
            context: .init(
                origin: .init(label: origin, geo: nil, transitStopID: nil),
                destination: .init(label: destination, geo: nil, transitStopID: nil),
                habitualCommute: true,
                window: .init(recommendedDeparture: decision.recommendedDeparture, mode: windowMode)
            ),
            decision: decision.decision,
            route: routeAdvice(from: best, isFallback: false),
            fallback: fallback.map { routeAdvice(from: $0, isFallback: true) },
            variance: .init(etaP50Minutes: best.p50Minutes, etaP90Minutes: best.p90Minutes),
            confidence: .init(score: best.confidence, level: confidenceLevel, limitingFactors: limiting),
            rationale: .init(oneLine: best.rationale, highlights: []),
            inputs: .init(
                dataFreshness: .init(transitUpdatedAt: now, disruptionsUpdatedAt: now, weatherUpdatedAt: now),
                weather: .init(raining: (rain ?? 0) > 0.1,
                               rainIntensity: rain,
                               walkingPenaltyMinutes: best.rainDeltaMinutes,
                               rainEndsAt: rainEnd),
                disruptions: disruptionImpacts(disruptions, bestPlan: best.plan),
                priorsVersion: "priors-v0.4.0",
                weights: .init(alphaVariance: prefs.alphaVariance,
                               betaChanges: prefs.betaChanges,
                               gammaWalking: prefs.gammaWalking,
                               deltaComfort: prefs.deltaComfort)
            ),
            ttlSeconds: 300
        )
    }

    private func routeAdvice(from rec: EngineRecommendation, isFallback: Bool) -> RouteAdvice {
        let lines = rec.plan.legs.compactMap { $0.lineId }.filter { !$0.isEmpty }
        // Prefer named lines (e.g. "Northern → Jubilee"); otherwise describe the
        // route by its modes so car/walk-only journeys read sensibly ("Drive").
        let label: String
        if !lines.isEmpty {
            label = lines.joined(separator: " → ")
        } else {
            label = modeBasedLabel(for: rec.plan)
        }
        return RouteAdvice(
            label: label,
            fingerprint: .init(lineSequence: rec.plan.legs.compactMap { $0.lineId }, stopIds: nil),
            legs: legSummaries(rec.plan),
            changes: rec.plan.changes,
            walkingMinutes: rec.plan.walkMinutes,
            platformHint: isFallback ? nil : startStationText(rec.plan),
            comfort: isFallback ? .fewerChanges : .minimalWalking
        )
    }

    /// A route label built from the journey's transport modes, used when no
    /// named transit lines are present (e.g. a driving or walking route). Walking
    /// legs are dropped if any non-walk mode exists, so "Walk → Car" reads "Drive".
    private func modeBasedLabel(for plan: JourneyPlan) -> String {
        let nonWalk = plan.legs.filter { $0.mode != .walk }
        let legs = nonWalk.isEmpty ? plan.legs : nonWalk
        let labels = legs.map { modeLabel($0.mode) == "Car" ? "Drive" : modeLabel($0.mode) }
        // Collapse consecutive duplicates (e.g. ["Bus","Bus"] -> "Bus").
        var deduped: [String] = []
        for l in labels where deduped.last != l { deduped.append(l) }
        return deduped.isEmpty ? "Suggested route" : deduped.joined(separator: " → ")
    }

    private func legSummaries(_ plan: JourneyPlan) -> [RouteLegSummary] {
        plan.legs.map { RouteLegSummary(type: mapMode($0.mode), lineOrService: $0.lineId, approxMinutes: $0.durationMinutes) }
    }

    /// Human-readable "where to start" hint from the first transit leg.
    private func startStationText(_ plan: JourneyPlan) -> String? {
        guard let leg = plan.legs.first(where: { $0.mode != .walk }) else { return nil }
        let name = (leg.fromStation?.isEmpty == false) ? leg.fromStation : nil
        let toward = (leg.toStation?.isEmpty == false) ? leg.toStation : nil
        let line = (leg.lineId?.isEmpty == false) ? leg.lineId : nil
        let mode = modeLabel(leg.mode)
        if let name { return "\(mode) from: \(name)" }
        if let line, let toward { return "\(mode): take \(line) towards \(toward)" }
        if let line { return "\(mode): take \(line)" }
        return nil
    }

    private func disruptionImpacts(_ disruptions: [Disruption], bestPlan: JourneyPlan) -> [DisruptionImpact] {
        let bestLines = bestPlan.legs.compactMap { $0.lineId?.lowercased() }
        return disruptions.map { d in
            let modeled = modeledDelay(for: d.severity)
            let id = d.lineId.lowercased()
            let affects = bestLines.contains { $0 == id || $0.contains(id) || id.contains($0) }
            return DisruptionImpact(line: d.lineId,
                                    severity: d.severity,
                                    affectsPrimarySegment: affects,
                                    modeledDelayMeanMin: modeled.mean,
                                    modeledDelayStdMin: modeled.std)
        }
    }

    private func modeledDelay(for severity: DisruptionSeverity) -> (mean: Double, std: Double) {
        switch severity {
        case .minor: return (2, 1)
        case .moderate: return (5, 2)
        case .severe: return (10, 5)
        }
    }

    private func modeLabel(_ mode: LegMode) -> String {
        switch mode {
        case .tube: return "Tube"
        case .bus: return "Bus"
        case .overground: return "Overground"
        case .dlr: return "DLR"
        case .nationalRail: return "National Rail"
        case .car: return "Car"
        case .walk: return "Walk"
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

    private func resolveCoordinates(origin: String, destination: String) async throws -> (CLLocationCoordinate2D, CLLocationCoordinate2D) {
        let geocoder = GeocodingHelper()
        // Resolve each endpoint independently and sequentially. CLGeocoder (the
        // fallback path) does not support concurrent requests and throttles hard;
        // resolving them one at a time — and caching results — is what makes a
        // postcode change actually refresh instead of silently failing to mock.
        let o = try await resolveOne(origin, using: geocoder)
        let d = try await resolveOne(destination, using: geocoder)
        return (o, d)
    }

    private func resolveOne(_ postcode: String, using geocoder: GeocodingHelper) async throws -> CLLocationCoordinate2D {
        if let c = DemoConfig.coords(for: postcode) {
            return CLLocationCoordinate2D(latitude: c.lat, longitude: c.lon)
        }
        return try await geocoder.geocode(postcode: postcode)
    }

    // MARK: - UI strings

    var title: String {
        guard let r = rec else { return "LEAVE NOW?" }
        switch r.decision {
        case .leaveNow: return "✅ Leave now"
        case .leaveInMinutes:
            if let mins = leaveInMinutes { return "✅ Leave in ~\(mins) min" }
            return "✅ Leave soon"
        case .wait:
            if let mins = waitMinutes { return "⏳ Wait ~\(mins) min" }
            return "⏳ Wait a bit"
        case .takeFallback:
            return "⚠️ Switch to fallback"
        }
    }

    var subtitle: String {
        guard let r = rec else { return "Checking conditions…" }
        return r.context.habitualCommute ? "Your usual route is stable today." : "Familiar route suggested."
    }

    var p50Text: String {
        guard let r = rec else { return "--" }
        let base = "ETA: \(r.variance.etaP50Minutes) min (P50)"
        let rainPenalty = r.inputs.weather.walkingPenaltyMinutes
        guard rainPenalty > 0 else { return base }
        if let end = r.inputs.weather.rainEndsAt {
            return base + " (+\(rainPenalty)m due to rain, until \(Self.timeFormatter.string(from: end)))"
        }
        return base + " (+\(rainPenalty)m due to rain)"
    }

    var p90Text: String { rec.map { "Worst case: \($0.variance.etaP90Minutes) min (P90)" } ?? "--" }

    var confidenceText: String {
        guard let r = rec else { return "--" }
        let pct = Int(r.confidence.score * 100.0)
        return "Confidence: \(pct)% • \(r.confidence.level.rawValue.capitalized) risk"
    }

    var routeLabel: String { rec?.route.label ?? "" }
    var rationale: String { rec?.rationale.oneLine ?? "" }

    var hasFallback: Bool { rec?.fallback != nil }
    var fallbackLabel: String {
        guard let fb = rec?.fallback else { return "" }
        return "Fallback: \(fb.label) (slower, more stable)"
    }

    private var leaveInMinutes: Int? {
        guard let r = rec, r.decision == .leaveInMinutes, let ts = r.context.window.recommendedDeparture else { return nil }
        return max(Int(round(ts.timeIntervalSinceNow / 60.0)), 0)
    }

    private var waitMinutes: Int? {
        guard let r = rec, r.decision == .wait, let ts = r.context.window.recommendedDeparture else { return nil }
        return max(Int(round(ts.timeIntervalSinceNow / 60.0)), 0)
    }

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df
    }()

    // MARK: - Sample fallback

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
                fingerprint: .init(lineSequence: ["northern", "jubilee"], stopIds: nil),
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
                fingerprint: .init(lineSequence: ["bus24", "district"], stopIds: nil),
                legs: [.init(type: .bus, lineOrService: "Bus 24", approxMinutes: 18)],
                changes: 2, walkingMinutes: 7, platformHint: nil, comfort: .fewerChanges
            ),
            variance: .init(etaP50Minutes: 32, etaP90Minutes: 39),
            confidence: .init(score: 0.82, level: .high, limitingFactors: [.weatherImpact]),
            rationale: .init(oneLine: "Light rain adds +2m walking; no delays on your segment.", highlights: []),
            inputs: .init(
                dataFreshness: .init(transitUpdatedAt: now, disruptionsUpdatedAt: now, weatherUpdatedAt: now),
                weather: .init(raining: true, rainIntensity: 0.3, walkingPenaltyMinutes: 2, rainEndsAt: nil),
                disruptions: [],
                priorsVersion: "priors-v0.4.0",
                weights: .init(alphaVariance: 0.7, betaChanges: 2.0, gammaWalking: 0.3, deltaComfort: 1.0)
            ),
            ttlSeconds: 300
        )
    }
}
