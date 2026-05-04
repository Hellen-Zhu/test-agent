# Test Design And Layering Methodology

This methodology defines how `qa-test-analysis-agent` turns a confirmed Story Contract into layered test points. It mirrors how an experienced QA engineer designs tests: understand behavior, identify what must be proven, choose the cheapest reliable layer, then make each validation intent explicit for later feature generation.

`test-layering-standards.md` defines exact fields, tag values, output structure, and required checks. This file defines the test design thinking.

## Core Principle

Layering is not based on whether the story mentions API or UI. Layering is based on the primary validation target.

Ask:

```text
What are we proving, and where is the cheapest reliable place to prove it?
```

Use the Story Contract fields:
- Given/When/Then ACs
- `observableEvidence`
- `requirementAnalysis`
- approved `solutionDesign` when available
- `technicalNotes` only as fallback trace context

Do not create test points for behavior that is not represented by the approved Story Contract.

Evidence precedence:
1. Use business story fields and ACs for behavior scope.
2. Use approved `solutionDesign` as the primary design evidence for test design.
3. Use `technicalNotes` only when `solutionDesign` is missing or does not cover that detail.
4. If `technicalNotes` conflicts with approved `solutionDesign`, use `solutionDesign`.

`technicalNotes.testLayer` is never authoritative. It may explain why a layer was suggested, but the final layer must still be selected by validation target.

## Test Design Loop

Use this loop for each AC and its observable evidence:

```text
Behavior under test
  -> Observable evidence
  -> Risk and rule analysis
  -> Cheapest reliable layer
  -> Test point
  -> challenge for gaps or duplication
```

The loop may start from evidence. If evidence is "Create Trade button is visible", infer the validation target is UI availability or permission feedback, not backend creation.

## 1. Identify Test Conditions

A test condition is one thing that must be true for the story to be accepted.

Extract test conditions from:
- `given`: precondition, role, state, data setup
- `when`: business action or event
- `then`: expected business outcome
- `observableEvidence`: concrete signal that proves the outcome
- `requirementAnalysis`: rules, constraints, assumptions, open questions
- `solutionDesign`: confirmed test-relevant design evidence, such as API contracts, UI visible states, permissions, data/audit/event behavior, test data, feature flags, automation hooks, and explicit test design implications
- `technicalNotes`: fallback technical trace only; do not use it as primary evidence when approved `solutionDesign` exists

Common test condition types:

| Type | Examples |
|------|----------|
| Happy path | valid trade can be created |
| Business rule | checker cannot approve own trade |
| Validation | missing maturity date is rejected |
| Boundary | maximum notional amount is accepted or rejected |
| Permission | Create button visible only for maker |
| Workflow | maker submits and checker approves |
| State transition | pending approval becomes live |
| Visibility | status appears in blotter |
| Prompt/confirmation | cancellation dialog appears before submit |
| Persistence/audit | trade state or audit event is stored |

## 2. Choose Layer By Validation Target

Use this matrix first.

| Validation target | Default layer | Reason |
|-------------------|---------------|--------|
| Input validation, field rules, calculations, transformations | API | Faster, deterministic, easier defect localization |
| Error code, error reason, response schema | API | Contract-level behavior |
| Persistence, stored state, audit record created by backend action | API | Backend truth can be verified without UI |
| Permission enforced by backend | API first | Security/rule enforcement should not rely only on UI |
| Permission shown as available/disabled action | UI | The user-visible affordance is the behavior |
| Button, menu item, dialog, banner, status label visibility | UI | Evidence is visual/user-facing |
| Blotter/table/page shows business state | UI | User-visible state is the behavior |
| Multi-actor handoff | UI/E2E | Requires role/session workflow confidence |
| Full lifecycle or cross-page journey | UI/E2E | End-to-end business confidence |
| Same-actor chained backend workflow | API | Can be verified faster with sequential API calls |
| Integration with external system only visible through contract/event | API or integration | UI adds little value unless user visibility matters |

## 3. API Layer Decision Heuristics

Choose API when the primary question is:
- Did the system accept or reject the business input correctly?
- Did it enforce a rule or permission?
- Did it calculate, transform, persist, or return the correct business state?
- Can the observable evidence be verified through response, database, audit, or event state?

API examples:

```text
AC evidence: validation reason is returned for missing maturity date
Layer: API
Reason: field validation and error reason are backend rules
```

```text
AC evidence: trade is stored in Pending Approval state
Layer: API
Reason: persistence state is backend truth
```

API should not be selected only because technical notes contain an endpoint. The endpoint is implementation evidence, not the business validation target.

## 4. UI/E2E Layer Decision Heuristics

Choose UI/E2E when the primary question is:
- Can the user see or use the business capability?
- Is a button, menu item, status, warning, dialog, or page state visible as expected?
- Does the workflow require multiple roles, sessions, or user-facing handoff?
- Is the value specifically about user confidence in the flow?

UI examples:

```text
AC evidence: Create Trade button is visible and enabled
Layer: UI
Reason: the behavior is user-visible capability availability
```

```text
AC evidence: cancellation confirmation dialog is displayed
Layer: UI
Reason: the behavior is a user-facing confirmation prompt
```

```text
AC evidence: maker sees Pending Approval and checker can approve it
Layer: UI/E2E
Reason: cross-role handoff and visible workflow state require user journey confidence
```

Do not push UI-visible evidence down to API just because backend state could imply it. If the story cares that the user sees it, keep a UI test point.

## 5. Dual-Layer Strategy

Some behavior deserves both API and UI coverage, but only when each layer proves different value.

Valid dual-layer cases:

| API proves | UI proves |
|------------|-----------|
| backend rejects unauthorized action | unauthorized user does not see the action button |
| backend stores Pending Approval state | blotter displays Pending Approval to the maker/checker |
| validation rule returns error reason | user sees the validation reason in the form/dialog |
| approval endpoint changes state | checker workflow exposes approval and final status |

Invalid duplication:
- API verifies status is Pending Approval and UI verifies the same state with no user-visible value.
- UI repeats every backend validation field when API coverage is enough.
- Full UI workflow is added for every negative data rule.

## 6. Scenario Economy Handoff

Phase 1 outputs atomic test points, not grouping hints or final scenarios.

Keep each test point clear enough that Phase 2 can decide scenario economy from approved fields:
- layer
- polarity and selection tags
- AC mapping
- validation target
- observable evidence
- scenario name
- reasoning

Do not add a downstream grouping hint field or any final scenario grouping decision in Phase 1. Grouping belongs to `bdd-case-design-agent` after the test point plan is approved.

## 7. Smoke And Regression Judgement

Tag field format is defined in `test-layering-standards.md`. Use this section only to decide release-confidence value.

Smoke candidates:
- critical happy path
- core workflow that proves the feature is usable
- high-risk permission or lifecycle path
- blocker behavior that would stop release if broken

Regression candidates:
- field-level validation
- boundary and negative cases
- secondary visibility checks
- non-critical variants

## 8. Challenge Questions

Challenge questions belong in methodology because they are design-review heuristics, not output format.

Before returning the Phase 1 report, challenge the design:

| Question | Action |
|----------|--------|
| Is every AC covered by at least one test point? | Add or map missing test point |
| Is every observable evidence item covered? | Add UI/API point or explain why not |
| Is a UI test only checking backend truth? | Push to API unless user visibility matters |
| Is an API test trying to prove visual behavior? | Move to UI |
| Are we duplicating the same value across layers? | Remove one or explain distinct value |
| Are test points atomic enough for Phase 2 to group safely? | Split compound points or sharpen validation target/evidence |
| Could several API/UI points later be grouped without losing traceability? | Make their layer, tags, validation target, evidence, and reasoning explicit |
| Are open questions blocking test design? | Mark as risk in reasoning |

## 9. Output Relationship

Output structure and field rules are defined in `test-layering-standards.md`.

The methodology output should make Phase 2 feature generation straightforward without reinterpreting the story.
