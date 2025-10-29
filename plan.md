# Plan

## Assumptions
- London-only v1; TfL as transit source.
- Deterministic engine v1, Monte Carlo v2; no LLMs.

## Trade-offs
- Simplicity over full coverage; accurate-enough priors.

## Next Steps
- Implement services and DTOs.
- Deterministic engine with unit tests.
- Add uncertainty model and scoring.

## Progress
- Milestones 1-5 implemented with mocked demo path.
- Persistence is JSON-backed for V1 simplicity.
- Next: Wire real services and Core Data swap if needed.

