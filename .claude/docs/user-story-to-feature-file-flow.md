# User Story To Feature File Flow

This document defines the handoff from a confirmed user story to executable API/UI Cucumber feature files. It keeps requirement analysis, solution design, test layering, and feature generation as separate responsibilities.

## End-To-End Flow

```text
Raw requirement, ADO item, or source notes
  -> /writeuserstories
  -> confirmed Story Contract JSON
  -> /enrichstorydesign when design context is needed
  -> design-ready Story Contract JSON with approved solutionDesign
  -> /bdd-gen
  -> bdd-agent Phase 1: Test Layering Analysis
  -> human-approved TP-### test point plan
  -> bdd-agent Phase 2: BDD Feature Generation
  -> human-approved API/UI feature content
  -> /bdd-gen writes feature files and updates the source
```

## Command Responsibilities

| Stage | Owner | Responsibility | Output |
|-------|-------|----------------|--------|
| Requirement intake | `/writeuserstories` | Parse raw input, analyze requirement intent, write business-facing story, normalize Given/When/Then ACs, preserve raw technical hints. | Confirmed Story Contract JSON or ADO-ready story plus Story Contract JSON. |
| Solution design enrichment | `/enrichstorydesign` | Add reviewed test-relevant design evidence: API, UI, data, permissions, integrations, NFRs, observability, rollout, test data, and automation constraints. | Design-ready Story Contract JSON with approved `solutionDesign`. |
| BDD orchestration | `/bdd-gen` | Load the confirmed or design-ready Story Contract, run review gates, invoke `bdd-agent`, write approved feature files, and update the source. | API/UI feature files plus generation summary. |
| Test design and feature generation | `bdd-agent` | Phase 1 creates layered test points. Phase 2 converts approved test points into API/UI feature content using project standards. | Phase 1 report and Phase 2 feature generation result. |

## Artifact Boundaries

| Artifact | Owns | Must Not Own |
|----------|------|--------------|
| Story Contract | Business goal, persona, scope, Given/When/Then ACs, observable evidence, assumptions, open questions, raw technical notes. | Feature names, feature tags, TC IDs, test cases, scenario inventory, endpoint implementation details. |
| Solution Design | Test-relevant design evidence needed to design and automate checks. | New business behavior or unapproved scope changes. |
| Phase 1 Test Point Plan | Validation intent, layer, polarity/selection tags, AC mapping, validation target, observable evidence, grouping key. | Feature file paths, feature tags, TC IDs, final scenario text. |
| Phase 2 Feature Content | Feature identity, file paths, scenario grouping, Gherkin, step reuse decisions, new snippet/step gaps, run commands. | New validation intent beyond the approved Phase 1 plan. |

## Source Precedence

Use evidence in this order:

1. Confirmed Story Contract business fields and Given/When/Then ACs.
2. Approved `solutionDesign` for API/UI/data/security/NFR/test data/automation evidence.
3. `technicalNotes` only as fallback trace context when `solutionDesign` is missing or silent.

If approved `solutionDesign` conflicts with `technicalNotes`, use `solutionDesign`.

## Detailed Flow

### 1. Generate The Story Contract

`/writeuserstories` accepts raw notes, ADO input, or JSON-like source material. It applies the requirement-to-story methodology and produces a confirmed Story Contract.

The Story Contract must contain:
- business-facing title, description, persona, and scope
- Given/When/Then acceptance criteria
- observable evidence when the requirement includes UI affordances, messages, statuses, dialogs, or API-visible outcomes
- assumptions, dependencies, constraints, non-functional needs, and open questions
- `technicalNotes` only as raw intake evidence

Exit gate:
- the user approves the story
- ACs are individually traceable and testable
- unresolved questions are either accepted as assumptions or explicitly open
- the Story Contract JSON is persisted or attached/commented in ADO

### 2. Enrich Solution Design When Needed

`/enrichstorydesign` is recommended for API, UI workflow, permission, data, integration, NFR, observability, rollout, or release-risk stories.

It adds `solutionDesign` without changing accepted business behavior unless the user explicitly approves a story revision.

The design should capture only test-relevant evidence:
- API contracts, endpoints, request/response behavior, status semantics, response contract files
- UI entry points, visible states, controls, validation messages, dialogs, empty/loading/error states, accessibility risks, automation hooks
- data lifecycle, persistence, audit, events, downstream effects, cleanup needs
- roles, permissions, security, compliance, and negative access expectations
- test data, feature flags, environment dependencies, and known automation constraints

Exit gate:
- `solutionDesign.designStatus` is `approved`
- design gaps that affect test design are resolved or explicitly owned
- technical notes are summarized only for compatibility; design evidence lives in `solutionDesign`

Simple low-risk stories may skip this stage only when the user intentionally accepts reduced design context.

### 3. Load The Story For BDD

`/bdd-gen` consumes the confirmed or design-ready Story Contract. It does not normalize, repair, split, or rewrite story content.

Allowed sources:
- local Story Contract JSON from `/writeuserstories`
- design-ready Story Contract JSON from `/enrichstorydesign`
- ADO work item only when it contains the full Story Contract JSON as an attachment or clearly titled comment

`/bdd-gen` performs only interface-level sanity checks:
- source is a Story Contract JSON object
- enough envelope data exists to route the BDD pipeline
- `solutionDesign` status is surfaced for traceability

### 4. Phase 1 - Test Layering Analysis

`/bdd-gen` invokes `bdd-agent` with:
- `phase: phase1_test_layering`
- the loaded `sourcePayload` unchanged
- project path when known

`bdd-agent` reads `test-layering-methodology.md` and creates a Test Layering Analysis Report.

Phase 1 output:
- neutral `TP-###` test point IDs
- API/UI layer decisions
- positive/negative and smoke/regression tags
- AC mapping
- validation target
- observable evidence
- neutral grouping key
- reasoning and coverage matrix

Phase 1 must not derive:
- feature names
- feature tags
- feature modules
- business domains
- target feature paths
- final TC IDs

Human review gate:
- every AC and observable evidence item is covered or explicitly justified
- layer assignments are correct
- grouping keys are compatible for Phase 2
- missing, duplicated, or wrong-layer validation points are corrected

### 5. Phase 2 - Feature Generation

After Phase 1 approval, `/bdd-gen` invokes `bdd-agent` with:
- `phase: phase2_feature_generation`
- the same loaded `sourcePayload` unchanged
- the approved Phase 1 report
- project path

Phase 2 source of truth:
- validation intent comes only from the approved Phase 1 test points
- source payload supports naming, descriptions, approved design details, test data, and executable step details
- original ACs may inform wording but must not add new test points

Phase 2 derives:
- `featureName`
- `featureTag`
- `featureModule`, derived only from `featureTag` and used as the TC ID prefix
- `businessDomain` for file routing
- API/UI target file paths
- file mode: `create`, `append`, or `not generated`
- scenario grouping and Scenario Outline usage
- step reuse decisions and new snippet/Java-step gaps

Feature identity:
- `featureName`: snake_case business capability, normally `{primary_business_object}_{primary_business_action}`
- `featureTag`: same as `featureName`, without `@`
- `featureModule`: uppercase `featureTag`, preserving underscores, used in `TC-{FEATURE_MODULE}-...`

Human review gate:
- feature files use business language and correct top-level tags
- scenarios preserve approved validation targets and observable evidence
- compatible TPs are grouped without losing traceability
- API scenarios use YAML-backed response contract assertion when sufficient
- UI scenarios use snippet-level business behavior, not raw UI operations
- missing snippets or Java steps are listed with reusable implementation guidance

### 6. Write Feature Files And Update Source

After Phase 2 approval, `/bdd-gen` writes only approved feature content:
- API files under `features/api/{businessDomain}/{featureName}.feature`
- UI files under `features/ui/{businessDomain}/{featureName}.feature`
- no file is created for a layer with zero approved scenarios

Write rules:
- `create` mode writes full feature content
- `append` mode writes scenario/scenario-outline blocks only
- existing top-level tags, `Feature:`, descriptions, and `Background:` are not duplicated
- generated output is not expanded beyond the approved Phase 2 result

Source update:
- local JSON receives generated file paths, scenario summary, coverage matrix, and timestamp
- ADO receives a BDD generation comment and may receive the updated Story Contract JSON

## Practical Control Points

| Control Point | Question |
|---------------|----------|
| After `/writeuserstories` | Is the behavior clear and testable as business value? |
| After `/enrichstorydesign` | Is there enough API/UI/data/security evidence to design tests without guessing? |
| After Phase 1 | Are we testing each behavior at the cheapest reliable layer? |
| After Phase 2 | Are scenarios concise, reusable, traceable, and executable by the existing framework? |
| After file write | Are the files placed correctly and ready for implementation or execution? |
