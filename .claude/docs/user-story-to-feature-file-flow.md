# User Story To Feature File Flow

This document defines the handoff from a confirmed user story to executable API/UI Cucumber feature files. It keeps requirement analysis, solution design, test layering, feature generation, and automation implementation as separate responsibilities.

## End-To-End Flow

```text
Raw requirement, ADO item, or source notes
  -> /writeuserstories
  -> confirmed Story Contract JSON
  -> /enrichstorydesign when design context is needed
  -> design-ready Story Contract JSON with approved solutionDesign
  -> /bdd-gen
  -> qa-test-analysis-agent: Test Layering Analysis
  -> human-approved TP-### test point plan
  -> bdd-case-design-agent: BDD Feature Generation
  -> human-approved API/UI feature content
  -> /bdd-gen writes feature files and updates the source
```

## Command Responsibilities

| Stage | Owner | Responsibility | Output |
|-------|-------|----------------|--------|
| Requirement intake | `/writeuserstories` | Parse raw input, analyze requirement intent, write business-facing story, normalize Given/When/Then ACs, preserve raw technical hints. | Confirmed Story Contract JSON or ADO-ready story plus Story Contract JSON. |
| Solution design enrichment | `/enrichstorydesign` | Add reviewed test-relevant design evidence: API, UI, data, permissions, integrations, NFRs, observability, rollout, test data, and automation constraints. | Design-ready Story Contract JSON with approved `solutionDesign`. |
| BDD orchestration | `/bdd-gen` | Load the confirmed or design-ready Story Contract, run review gates, invoke `qa-test-analysis-agent` and `bdd-case-design-agent`, write approved feature files, and update the source. | API/UI feature files plus generation summary. |
| Test analysis | `qa-test-analysis-agent` | Creates layered test points from the confirmed Story Contract using QA and FX structured products judgement. | Phase 1 Test Layering Analysis Report. |
| BDD case design | `bdd-case-design-agent` | Converts approved test points into API/UI feature content with consistent business step wording using project standards. | Phase 2 BDD Feature Generation Result. |

## Artifact Boundaries

| Artifact | Owns | Must Not Own |
|----------|------|--------------|
| Story Contract | Business goal, persona, scope, Given/When/Then ACs, observable evidence, assumptions, open questions, raw technical notes. | Feature names, feature tags, TC IDs, test cases, scenario inventory, endpoint implementation details. |
| Solution Design | Test-relevant design evidence needed to design and automate checks. | New business behavior or unapproved scope changes. |
| Phase 1 Test Point Plan | Validation intent, layer, polarity/selection tags, AC mapping, validation target, and observable evidence. | Feature file paths, feature tags, TC IDs, scenario grouping, or final scenario text. |
| Phase 2 Feature Content | Feature identity, feature paths, scenario grouping, Gherkin, and run commands. | New validation intent beyond the approved Phase 1 plan or automation implementation decisions. |

## Agent, Methodology, Standards, And Command Maintenance

Agents consume methodology and standards. They do not own detailed methodology content or detailed output contracts.

| Artifact Type | Owns | Must Not Own |
|---------------|------|--------------|
| Agent | Role, professional skills, ownership boundary, context-read policy, execution order, internal quality loop, and which methodology/standards to apply. | Detailed output schemas, naming algorithms, tag formats, file path templates, or deep decision heuristics. |
| Methodology | Thinking model, decision heuristics, design loop, challenge questions, and professional judgement patterns. | Exact output templates, TC ID formats, file path templates, command payloads, or write/update steps. |
| Standards | Allowed values, naming and path rules, tag and TC formats, required fields, output contract, and mechanical quality gates. | Agent persona, tool policy, orchestration flow, or broad professional reasoning. |
| Command | Invocation payload, review gates, file writing, source updates, and pipeline state transitions. | Test design judgement, BDD wording decisions, automation implementation decisions, or duplicated standards. |

Maintenance rule:
- Detailed input envelope lives in the command.
- Detailed output contract lives in standards.
- Methodology explains why and how to decide.
- Agent references methodology and standards, then applies them inside its role boundary.
- If the same rule appears in more than one place, keep the canonical rule in the right artifact type and replace the duplicate with a reference.

Current canonical documents:
- Phase 1 methodology: `~/.claude/docs/test-layering-methodology.md`
- Phase 1 standards: `~/.claude/docs/test-layering-standards.md`
- Phase 2 methodology: `~/.claude/docs/bdd-case-design-methodology.md`
- Phase 2 standards: `~/.claude/docs/bdd-feature-generation-standards.md`
- BDD orchestration command: `~/.claude/commands/bdd-gen.md`

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

`/bdd-gen` invokes `qa-test-analysis-agent` with:
- the loaded `sourcePayload` unchanged

`qa-test-analysis-agent` reads `test-layering-methodology.md` for reasoning and `test-layering-standards.md` for the exact output contract, then creates a Test Layering Analysis Report.

Phase 1 output:
- neutral `TP-###` test point IDs
- API/UI layer decisions
- positive/negative and smoke/regression tags
- AC mapping
- validation target
- observable evidence
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
- test points are atomic and explicit enough for Phase 2 grouping
- missing, duplicated, or wrong-layer validation points are corrected

If the reviewer requests changes, `/bdd-gen` re-invokes `qa-test-analysis-agent` with a Phase 1 `reinvokeContext` containing the previous final checked Phase 1 output and the exact user revision request. The command must not manually patch the report outside the agent's quality loop.

### 5. Phase 2 - Feature Generation

After Phase 1 approval, `/bdd-gen` invokes `bdd-case-design-agent` with:
- the same loaded `sourcePayload` unchanged
- the approved Phase 1 report
- path hints for resolving `{E2E_DIR}`

Phase 2 source of truth:
- validation intent comes only from the approved Phase 1 test points
- source payload supports naming, descriptions, approved design details, test data, and executable step details
- original ACs may inform wording but must not add new test points

`bdd-case-design-agent` reads `bdd-case-design-methodology.md` for design reasoning and `bdd-feature-generation-standards.md` for exact naming, path, TC, and output rules.

Phase 2 derives:
- `featureName`
- `featureTag`
- `featureModule`, derived only from `featureTag` and used as the TC ID prefix
- `businessDomain` for file routing
- API/UI target file paths
- file mode: `create`, `append`, or `not generated`
- scenario grouping and Scenario Outline usage, derived from approved Phase 1 test point fields
- Feature and Scenario Annotation comments embedded in the generated `.feature` files for traceability, validation target, observable evidence, and business test data intent

Feature identity:
- `featureName`: snake_case business capability, normally `{primary_business_object}_{primary_business_action}`
- `featureTag`: same as `featureName`, without `@`
- `featureModule`: uppercase `featureTag`, preserving underscores, used in `TC-{FEATURE_MODULE}-...`

Human review gate:
- feature files use business language and correct top-level tags
- scenarios preserve approved validation targets and observable evidence
- compatible TPs are grouped without losing traceability
- annotations contain only business/test-design context and no automation implementation details
- API and UI scenarios use business-readable step patterns without implementation details

If the reviewer requests changes, `/bdd-gen` re-invokes `bdd-case-design-agent` with a Phase 2 `reinvokeContext` containing the previous final checked Phase 2 output, exact user revision request, and any still-valid discovery snapshot such as resolved `{E2E_DIR}`, feature-file style evidence, file-mode evidence, and TC sequence evidence. Required methodology and standards references may be reused only when their paths and hashes are unchanged; otherwise the agent must read them again.

### 6. Write Feature Files And Update Source

After Phase 2 approval, `/bdd-gen` writes only approved feature content:
- API files under `features/api/{businessDomain}/{featureName}.feature`
- UI files under `features/ui/{businessDomain}/{featureName}.feature`
- no file is created for a layer with zero approved scenarios

Write rules:
- `create` mode writes full feature content
- `append` mode writes Scenario Annotation + scenario/scenario-outline blocks only
- existing top-level tags, `Feature:`, descriptions, and `Background:` are not duplicated
- Feature Annotation is written only in `create` mode; Scenario Annotation is written with every generated scenario
- generated output is not expanded beyond the approved Phase 2 result

Source update:
- local JSON receives generated feature paths, scenario summary, coverage matrix, and timestamp
- ADO receives a BDD generation comment and may receive the updated Story Contract JSON

Automation implementation:
- `automation-agent` consumes the written `.feature` files as the golden source for step text, TC IDs, tags, scenario grouping, business behavior, and embedded annotations.
- No separate automation context file is generated or required.

## Practical Control Points

| Control Point | Question |
|---------------|----------|
| After `/writeuserstories` | Is the behavior clear and testable as business value? |
| After `/enrichstorydesign` | Is there enough API/UI/data/security evidence to design tests without guessing? |
| After Phase 1 | Are we testing each behavior at the cheapest reliable layer? |
| After Phase 2 | Are scenarios concise, reusable, traceable, and ready for automation implementation without leaking implementation detail? |
| After file write | Are the files placed correctly and ready for implementation or execution? |
