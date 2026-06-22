# Pain Point Rules

Use this reference when the user's request is fuzzy, long, UI-heavy, sample-heavy, image-generation-heavy, or involves old project/worktree adoption.

## Core Pain Points

| ID | Pain | Control |
| --- | --- | --- |
| P1 | User does not want to remember commands | Natural language router plus command fallback |
| P2 | Requirements are fuzzy | Restate goal, disclose decision consequences, list uncertainty, ask at most 1-3 questions |
| P3 | Long tasks drift | Split into 3-7 recoverable gates |
| P4 | Context compression loses the mainline | `.workflow` plus memory points and evidence chains are the source of recovery |
| P5 | UI/image/sample quality cannot be proven by backend tests | Visible evidence plus human gate |
| P6 | Old project rules and failed branches can be heavy but valuable | Salvage into rule/plan/contract/evidence/receipt/knowhow |
| P7 | Multi-agent work becomes chaotic | Main agent owns direction; workers return receipts |
| P8 | Main session can change | Register active/historical main thread state |
| P9 | Model strengths differ | Route by role and proof requirement |
| P10 | User wants to learn without heavy process | Direct mode for clear small tasks, gates for risky tasks |
| P11 | Surface complaints hide product-system mismatch | Product-System Fit Gate before UI/workflow/product-shape implementation |

## Default Response To Fuzzy Input

Do this before implementation.

If the user's fuzzy input references previous work, current pages, old audits, samples, screenshots, ports, or repeated corrections, retrieve context first. Do not ask clarification questions from a blank slate.

1. Recover `.workflow`.
2. Retrieve prior-task anchors when the prompt points to history.
3. State what the anchors prove and do not prove.
4. State the root diagnosis: prior intended mainline, current observed artifact, and the contradiction.
5. Restate the goal in one paragraph.
6. If the next decision changes visible product shape, route, page, workflow axis, integration mode, or user acceptance surface, disclose the consequence in plain language before asking.
7. List the main uncertainties.
8. Ask at most 1-3 confirmation questions, starting with the upstream contradiction.
9. Create or update `.workflow/open_threads.yaml` and memory points when needed.
10. Only then create the task card or blueprint.

## Product-System Fit Gate

Use this gate when a request involves UI, product shape, workflow placement, a new capability, old-project insertion, or a user repeatedly mentions a surface symptom such as a standalone page, a menu, a panel, an entry point, "feels disconnected", "not smooth", "does not fit", "too narrow", "not integrated", or "only moved the surface".

These words are a surface symptom, not the decision. They are weak signals that the main agent must inspect product structure, workflow ownership, interaction grammar, data/object boundaries, and user task flow. Do not keyword-route them into a fixed solution.

For old projects or second development:

- audit the existing information architecture, page responsibilities, menu/panel/tool areas, object model, data flow, and interaction grammar before proposing where a new capability belongs;
- identify whether the new capability should be a workflow, object detail, command, panel, node type, template, import/export path, settings surface, or temporary workbench;
- separate temporary preview/workbench routes from the formal product path;
- explain how the new capability cooperates with existing capabilities rather than only where it is placed.

For new projects:

- establish the product's information architecture, primary task flow, core objects, page/panel/tool division, and interaction grammar before building isolated features;
- decide whether a requested feature belongs in the main workflow, assistant surface, object detail, batch tool, asset manager, review queue, settings, or experiment area;
- avoid treating cards, dashboards, or standalone pages as a substitute for product structure.

Do not reduce "not a standalone page" to "move it into a panel". The real question may be product structure, workflow ownership, interaction grammar, object boundaries, or whether the proposed feature is a sidecar rather than a native part of the system.

Do not confuse placement with integration. A feature is integrated only when its object ownership, workflow ownership, reused capabilities, data/state lifecycle, interaction grammar, and acceptance surface are native to the product. A button in global navigation, a topbar action, a right panel, or a route can still be a sidecar if it bypasses those contracts.

The output of this gate should include:

- `surface_symptoms`: what the user complained about, marked as weak-signal-only;
- `deeper_product_system_issue`: the likely structural problem behind the surface complaint;
- `system_role_hypotheses`: 2-3 possible roles for the capability in the product system;
- `existing_or_planned_system_anchors`: evidence from current project files, UI, docs, or plans;
- `temporary_vs_formal_path`: what is only a workbench/preview and what is the product path;
- `integration_fit`: which surface level is claimed, which tempting levels are rejected, what owns the object/workflow/data, what existing capability is reused, and what proves this is not merely moved placement;
- `first_confirmation`: one upstream question about product-system fit before downstream UI details.

Directionally correct summaries are not enough. If the answer only says "use the existing page", "put it in the right panel", "reuse the old workflow", or "do not keep the sidecar", mark the gate incomplete unless it also provides:

- concrete original product anchors from files, routes, screenshots, docs, browser state, or existing plans;
- the native interaction grammar the capability must follow;
- a capability reuse plan that avoids a parallel implementation path;
- candidate insertion points with evidence, fit reason, and risk;
- the first visible slice and what it proves/does not prove;
- a debate or worker receipt when multi-model or worker analysis was invoked.

## Confirmation Must Expose Consequences

The user should not need to read a T4/T5 document to discover what they approved. Before asking for confirmation, say what a "yes" authorizes:

```text
If you confirm this, I will:
- create/change <visible entry, route, page, workflow surface, or integration mode>;
- treat <old path or option> as rejected/deferred;
- keep <human gates> blocked until <visible proof/user acceptance>;
- not claim <seller-ready/export/UI/generation quality/etc.>.
```

For product/UI/workflow decisions, also state what will be visible to the user first. "Confirm Option A" is not enough if Option A implies a new route, a sidecar, a changed workflow axis, or a different acceptance surface.

Good confirmation:

```text
If you say yes, the next gate will add a temporary `<new route/workbench>` rather than modifying `<existing workflow surface>`. It will prove that a visible slice can be inspected, not final integration, export readiness, generated-media quality, or user acceptance. Is that acceptable as a temporary visible slice, or should we return to the existing-surface insertion plan first?
```

Bad confirmation:

```text
Confirm Option A as the T5 default path?
```

## Wrong First Question Failure

"At most 1-3 questions" is not enough if the questions miss the upstream issue. Treat these as failures:

- asking about color/SKU/variant details when the user is challenging whether the work is integrated into the existing product flow;
- asking which new page to build when the user references prior audit, insertion, or "not a new page";
- asking for acceptance of a visible slice when the recovered anchors show the slice may be based on the wrong mainline;
- routing to a worker, Maestro, or Claude before the main agent states the recovered contradiction.
- asking the user to confirm a document option without stating the concrete page/route/workflow consequence.

When this happens, do not add more questions. Re-run context retrieval, write the root diagnosis, and ask one upstream confirmation.

## Memory Points And Direction Changes

Use a memory point when a correction or decision is likely to matter after compression:

```yaml
id:
status: active | superseded | rejected | needs_user_acceptance
source:
claim:
applies_when:
does_not_apply_when:
evidence:
supersedes:
last_seen:
```

Rules:

- Make each memory point atomic.
- Mark old direction as `superseded` when the user changes direction.
- Keep current-task state in `.workflow`; promote stable reusable lessons to Maestro spec/knowhow.
- Never use memory points as keyword triggers. Use them as evidence to interpret the current request.

## Long Task Gate Model

Use this for chaotic or second-development work:

| Gate | Meaning | Exit Criteria |
| --- | --- | --- |
| T0 Intake | Recover context and identify user value | Goal and forbidden claims are known |
| T1 Clarify | Resolve fuzzy direction | Open questions are answered or explicitly parked |
| T2 Blueprint | Map workflow/modules/data/risks | User-visible acceptance and involved areas are known |
| T3 Salvage | Mine old branches/docs without copying rule wall | Reusable assets and rejected paths are recorded |
| T4 Insertion Plan | Decide where to change the system | Interfaces, rollback, and verification are defined |
| T5 Visible Slice | Build/verify smallest visible workflow | Browser/screenshot/sample evidence exists |
| T6 Implementation | Expand implementation | Tests and visible gates pass |
| T7 Acceptance/Learn | User accepts or feedback becomes issues | Knowhow/state updated |

Do not skip T2-T5 for UI, existing-workflow insertion, e-commerce/sample, generated image, or business workflow tasks. Ozon/Canvas is a pressure-test example, not the only case.

## Forbidden Shortcuts

- Do not treat tests as proof of UI acceptance.
- Do not let a worker decide product direction.
- Do not use `maestro -y` or Ralph auto-advance across human gates.
- Do not turn workflow maintenance checks into user-facing intent. Unless the user asks about upgrade/versioning or required workflow files are missing, do not ask whether the project is v1/v2 and do not put protocol version status in the first clarification.
- Do not copy every old project rule into a new project.
- Do not say "configured" without running recover/validate or reading the relevant state files.
- Do not ask clarification questions before retrieving context when the user clearly references prior work.
- Do not ask downstream clarification questions before stating the root contradiction when recovered anchors conflict with the current artifact.
- Do not ask for confirmation of a product/UI/workflow option without disclosing the visible consequence and what the user is authorizing.
- Do not keep stale memory active after the user supersedes it.
