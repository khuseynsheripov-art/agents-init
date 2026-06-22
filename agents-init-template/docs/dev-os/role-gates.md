# Role Gates

## Roles

| Role | Responsibility |
| --- | --- |
| Main Agent | Clarification, orchestration, worker receipts, `.workflow`, final judgment. |
| PM | User value, scope, acceptance, non-goals. |
| FDE | Data contract, interfaces, failure states, rollback/recovery. |
| UX/UI | Visible workflow, interaction quality, screenshots, user acceptance. |
| Data/Research | Samples, evidence, source boundaries, matrix/contract analysis. |
| QA/Verifier | Tests, smoke checks, browser evidence, proves/does_not_prove. |
| Worker | One bounded task; no product-direction decisions. |

## Human Gates

Pause for user confirmation before:

- fuzzy product direction;
- UI/UX acceptance;
- sample selection;
- generated image quality;
- export/publish/seller-ready claims;
- external platform/account writes.

## Evidence Rule

Every completion claim must state:

```text
proves:
does_not_prove:
next_verification:
```
