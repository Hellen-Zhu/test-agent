# Full-Stack Delivery Lifecycle

This document defines the recommended flow from requirement discovery to production launch. It prevents user stories, solution design, and test design from collapsing into one artifact.

## Recommended Stages

| Stage | Purpose | Primary Owner | Primary Artifact | Exit Gate |
|-------|---------|---------------|------------------|-----------|
| 1. Requirement discovery | Understand business problem, users, value, scope, constraints, and unknowns. | Product + Engineering + QA | Raw requirement notes | Problem and business outcome are understood. |
| 2. Story contract | Convert the requirement into a business-facing user story and Given/When/Then ACs. | Product + QA + Engineering | Story Contract JSON | Story is confirmed and testable at business level. |
| 3. Solution design | Define how the product, UI, API, data, security, integrations, NFRs, observability, and rollout will satisfy the story. | Engineering + UX + QA | Design-ready Story Contract or linked design spec | Design is reviewed enough for implementation and test design. |
| 4. Story refinement after design | Refine only confirmed gaps found during solution design. | Product + Engineering + QA | Updated Story Contract | Business behavior remains stable; technical constraints are clear. |
| 5. Test strategy and BDD design | Convert approved behavior and design evidence into layered test points and API/UI feature files. | QA + Engineering | Test point plan, feature files, step gaps | Coverage and layering are approved. |
| 6. Implementation planning | Slice work, map files/modules, define local verification, CI, rollout, and rollback needs. | Engineering | Delivery Design Report | Plan is executable and reviewable. |
| 7. Build and local verification | Implement code, snippets, tests, config, and documentation. | Engineering | Code changes and local evidence | Local required checks pass or gaps are explicit. |
| 8. CI and integration verification | Build, test, scan, package, and produce deployable artifacts. | Engineering + Platform | CI evidence and artifact version | Required gates pass. |
| 9. Environment acceptance | Deploy to non-production and run acceptance, smoke, and regression checks. | QA + Engineering + Product | Acceptance evidence | Defects are accepted or resolved. |
| 10. Release readiness | Confirm rollout, rollback, monitoring, ownership, support, and risk. | Engineering + Product + Ops | Go/No-Go report | Explicit launch approval. |
| 11. Production launch | Deploy or enable the feature with monitored rollout. | Engineering + Ops | Deployment record and smoke evidence | Production health is acceptable. |
| 12. Post-launch closure | Capture production evidence, incidents, metrics, and update the work item. | Engineering + Product | Closure report | Story is closed with evidence. |

## Artifact Boundaries

| Artifact | What It Should Contain | What It Should Not Contain |
|----------|------------------------|-----------------------------|
| User Story / Story Contract | Business outcome, actor, scope, GWT ACs, observable evidence, assumptions, open questions. | Detailed endpoint specs, CSS selectors, component internals, database schema, test cases, TC IDs. |
| Solution Design | Test-relevant API contracts, UI states, data and integration evidence, permissions, NFRs, observability, rollout risks, test data, automation constraints, and links to detailed design artifacts. | New business scope, unapproved behavior changes, BDD scenario inventory, full implementation internals. |
| BDD Test Design | Validation targets, layer decisions, test points, feature files, reusable step decisions. | Product decisions, API invention, UI design invention, implementation slices. |
| Delivery Design | Implementation slices, repository touch points, verification commands, CI/CD gates, rollout and rollback execution plan. | Rewriting ACs or changing business behavior. |

## Senior Engineering Guidance

- Do not put every technical detail into the user story. The story stays business-facing.
- Do not start detailed BDD feature generation from a weak story when API/UI contracts are unknown.
- Do not wait for all code to exist before thinking about tests. Use design evidence to shape test strategy before implementation.
- API and UI design can refine observable evidence, but they should not silently change accepted behavior.
- Story JSON should store design evidence needed for testing, plus references to larger design artifacts. It should not become the full technical specification.
- Simple low-risk stories may skip a formal design enrichment step when the Story Contract already contains enough evidence.
- Complex workflow, API, data, permission, integration, or release-risk stories should go through solution design enrichment before `/bdd-gen`.

## Recommended Command Flow

```text
/writeuserstories
  -> confirmed business Story Contract

/enrichstorydesign
  -> design-ready Story Contract with solutionDesign

/bdd-gen
  -> layered test points and API/UI feature files

/eng-flow
  -> implementation, automation, CI, acceptance, release, and closure
```

`/bdd-gen` may proceed without `solutionDesign` only when the user intentionally skips design enrichment for a simple story and accepts reduced design context.

For the detailed handoff from confirmed Story Contract to API/UI feature files, read `~/.claude/docs/user-story-to-feature-file-flow.md`.
