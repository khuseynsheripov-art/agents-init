# Adoption And Salvage

Use this reference when an existing project, old worktree, old rules, TODO files, failed branch, or handoff docs need to be adopted.

## Principle

Do not copy a rule wall into the new project. Classify old material into durable categories and load it only when needed.

## Salvage Categories

| Category | Meaning | Example |
| --- | --- | --- |
| rule | Must-follow constraint | "UI acceptance needs screenshots" |
| plan | Proposed future work | old roadmap, T5/T6/T7 plan |
| contract | Interface/data shape | API schema, prompt contract |
| evidence | Proof or artifact | screenshots, test logs, generated images |
| receipt | Worker/delegate handoff | prior agent result |
| knowhow | Reusable lesson | "backend tests did not prove Canvas UX" |
| rejected_path | Attempt not to repeat | failed branch approach |
| unresolved | Needs user/main decision | sample boundary unclear |

## Adopt Flow

1. Add `.workflow` sidecar files without overwriting existing docs.
2. Inventory old docs/TODO/rules.
3. Classify each important file into the salvage categories.
4. Promote only durable constraints into project `AGENTS.md` or `.workflow/agents-init.yaml`.
5. Store deeper lessons in docs/dev-os or Maestro knowhow/specs.
6. Create `open_threads` for unresolved product decisions.
7. Do not implement until the active gate is known.

## Existing Workflow Insertion Pattern

For failed second-development branches where a new artifact may have drifted away from an existing product/workflow surface, salvage these before new work:

- intended business or creative workflow;
- old capture/import/plugin/data chain;
- sample/reference evidence;
- user dissatisfaction signals;
- failed implementation paths;
- visible acceptance criteria;
- insertion points in the existing application surface.

Then produce:

```text
T2 blueprint
T3 salvage matrix
T4 insertion plan
T5 visible slice
```

Ozon/Canvas is one pressure-test case for this pattern, not a global rule. Keep case-specific SKU, SourcePack, shape-group, `/image`, or `/canvas/ozon-suite` details in that project's `.workflow`, memory points, plans, receipts, or Maestro knowledge entries.
