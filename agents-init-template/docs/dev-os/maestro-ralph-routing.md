# Maestro And Ralph Routing

Maestro and Ralph are execution aids. The main agent remains the orchestrator.

| Route | Use When | Do Not Use When | Required Output |
| --- | --- | --- | --- |
| Direct | Small clear task, low ambiguity | Product/UI/sample uncertainty | Verification note |
| Grill | Requirement fuzzy, user unsure | Task already has acceptance | Clarified task card |
| Brainstorm | Need PM/FDE/UX/Data/Test perspectives | Pure mechanical edit | Synthesis and open threads |
| Worker | Independent bounded task | Shared product direction decision | Worker receipt |
| Maestro | Clear repeatable workflow command | Human gate unresolved | Workflow result summarized |
| Ralph | Clear lifecycle with gates | Fuzzy UI/sample/generated image quality | Stage receipt and pause points |

## Failure Return

If Maestro/Ralph fails or drifts:

1. Stop the chain.
2. Record failure in `verification.yaml`.
3. Add unresolved decision to `open_threads.yaml`.
4. Return to main agent for routing.

## Human Gate Rule

Ralph cannot auto-accept UI, samples, generated images, export readiness, seller-ready claims, or external writes.
