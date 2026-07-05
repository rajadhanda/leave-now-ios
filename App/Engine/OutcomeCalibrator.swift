import Foundation

/// The seam where stored outcomes will feed back into the engine.
///
/// Intended inputs: recent `TripRecord`s — predicted P50/P90 vs
/// `actualDurationMinutes`, route compliance (`followedRoute`,
/// `deviationIntent`), arrival judgements, and departure deltas.
///
/// Intended outputs: adjusted walking/transfer `DelayPrior`s and per-line
/// reliability weights for `RecommenderV2` (surfaced through a priors store
/// the recommender reads, bumping `priorsVersion` when they change).
///
/// Deliberately a no-op in v1: the capture loop ships and accumulates data
/// without the calibration/ML layer. Called after every recorded outcome.
enum OutcomeCalibrator {
    static func recalibrate(from records: [TripRecord]) {
        // Intentionally empty — v1 only records.
    }
}
