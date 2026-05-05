# BDD Feature Generation Standards

Detailed output and contract standards for `bdd-case-design-agent`. This document defines exact source boundaries, naming rules, file rules, TC ID formats, required checks, and the Phase 2 output contract.

`bdd-case-design-methodology.md` defines how to design scenarios and business step patterns. This file defines what the generated output must contain and what is allowed or forbidden.

## 1. Source Boundaries

| Purpose | Source of truth | Fallback | Forbidden |
|---------|-----------------|----------|-----------|
| Test point existence/layer/tags | Confirmed Phase 1 report | None | Re-parsing story/ACs |
| Coverage groups/scenario count | Approved Phase 1 test point fields + this document | Split for readability or execution correctness | Assuming one TP must equal one scenario or inventing new grouping intent from raw ACs |
| AC coverage | Phase 1 AC mapping | Original AC text for wording only | Changing coverage decisions |
| Validation target/evidence | Phase 1 Validation Target + Observable Evidence | None | Dropping evidence because the AC ID is covered |
| Feature naming/path | Story title + TP names | Description/persona; approved API operation wording as weak fallback | story module, class names, endpoints, story IDs |
| API details | Approved `solutionDesign.apiDesign` | Technical notes only if solution design is missing; existing feature patterns | UI assumptions; technical notes overriding solution design |
| API response contract | YAML contract bound to the current scenario | Existing response contract patterns | Duplicating status/schema/body assertions in feature steps |
| UI wording | TP names + persona + `solutionDesign.uiDesign` | Description | Endpoint names |
| Extra API assertions and test data | Phase 1 validation target + approved `solutionDesign.testDesignImplications` | Technical notes only as weak fallback | Inventing DB/audit/event assertions without design evidence |
| Feature annotations | Approved Phase 1 report + generated Phase 2 context | Source payload story identity for source trace only | Separate automation context files or automation-code decisions |

If Phase 1 has no approved test point for a behavior, do not generate a scenario for it.

When approved `solutionDesign` exists, do not use `technicalNotes` as the primary source for API paths, UI wording, response contracts, extra assertions, or test data. If `technicalNotes` conflicts with approved `solutionDesign`, use `solutionDesign` and mention the conflict in derivation evidence when relevant.

## 2. Business Language Standards

Feature files are executable business specifications. The methodology defines how to design them; this section defines the non-negotiable language constraints.

Required:
- Domain language in `Feature`, description, scenario summaries, and reusable steps.
- One consistent third-person voice such as `maker`, `checker`, `admin`, or `the user`.
- Business contract-level steps that can be reviewed without reading Java, Playwright selectors, request builders, or helper code.
- Cucumber tags only for execution selection and the generated TC ID.
- Feature and scenario annotations as Gherkin comments for traceability and test-design context.

Forbidden:
- Java class names, Cucumber function names, snippets, CSS selectors, DOM IDs, endpoint paths, payload files, request builders, response matcher names, page objects, API clients, fixtures, helpers, or framework wording.
- Tags for story IDs, AC IDs, modules, domains, or arbitrary metadata.
- Feature wording changed only to fit assumed existing automation glue.
- Annotations that mention Java methods, snippets, selectors, endpoints, page objects, API clients, fixtures, helpers, payload files, request builders, response matchers, or database table names.

## 3. Naming Rules

Derive these feature identity values:

| Field | Rule |
|-------|------|
| `featureName` | snake_case business capability, normally `{primary_business_object}_{primary_business_action}` |
| `featureTag` | same as `featureName`, without `@` |
| `featureModule` | uppercase `featureTag`, preserving underscores, used as the TC ID prefix |

`featureModule` is not a separate business module. It must be derived only from `featureTag`; never derive it from story `module`, Java classes, packages, story IDs, TC IDs, or `TP-###`.

Derivation algorithm:
1. Extract object/action from story title and TP names.
2. Drop generic verbs like `validate`; use the real operation.
3. Normalize `configure/configuration` to `config`.
4. Use the broader entity for product variants: `FX TRF trade creation` → `trade_create`.
5. If uncertain, use `general_{action}` and explain the evidence in output.

Derive `businessDomain` separately for file routing only:

| Signal                                        | Domain            |
|-----------------------------------------------|-------------------|
| trade / trf / cancellation / amend / novation | `trading`         |
| approve / checker / approval                  | `entitlement`     |
| reference data / mapping                      | `reference_data`  |
| product / composer                            | `product`         |
| risk                                          | `risk_management` |
| user / permission / user configuration        | `user_management` |
| notification                                  | `notification`    |
| login / authentication                        | `authentication`  |
| otherwise                                     | `general`         |

If multiple signals match, prefer the most business-facing object named in the title, description, and confirmed test points. Do not let a technical module override the business domain.

Do not use story `module`, Java classes, endpoint names, story IDs, TC IDs, or `TP-###` in feature naming.

## 4. File Rules

Default files:
- API: `{E2E_DIR}/src/test/resources/features/api/{businessDomain}/{featureName}.feature`
- UI: `{E2E_DIR}/src/test/resources/features/ui/{businessDomain}/{featureName}.feature`

Rules:
- API and UI are always separate files.
- Create a file only for layers with approved test points.
- File names are snake_case and contain no TC IDs, story IDs, `_api`, `_ui`, or `_e2e`.
- Same feature name may exist under both `api/` and `ui/`.
- Ignore any legacy `bddFeatureFile`, `apiFeatureFile`, or `uiFeatureFile` fields in source JSON.
- Generated feature files are the golden source for `automation-agent`; do not produce separate automation context files.
- Feature and scenario annotations are embedded as Gherkin comments inside the generated `.feature` file. Do not create `.automation-handoff.md`, `.handoff.md`, or any separate automation context artifact.

Existing files:
- Read target file when present.
- Determine file mode per layer: `create`, `append`, or `not generated`.
- Continue TC numbering from existing scenarios with the same TC prefix.
- In `append` mode, output scenario/scenario outline blocks only.
- In `append` mode, do not introduce a new top-level `Background:`. Put setup explicitly in the appended scenarios.
- Do not duplicate top-level tags, `Feature:`, descriptions, or `Background:`.

## 5. Feature Level

Common structure:

```gherkin
@{layerTag} @{featureTag}
Feature: {Business Object} {Capability} {Layer Label}
  Story: {storyId} - {title}
  Goal: {one sentence business goal}
  Scope: {layer scope}

  # Feature Annotation:
  # businessDomain: {businessDomain}
  # validationScope: {business validation scope}
  # source: {storyId}
  # implementationBoundary: Feature file is the golden source; preserve business wording during implementation.
```

API:
- Layer tag: `@api`
- Feature title example: `Feature: FX TRF Trade Creation API`
- Scope mentions API contract, validation, persistence, and response verification.
- No API `Background:`.

UI:
- Layer tag: `@playwright`
- Feature title example: `Feature: FX TRF Trade Creation Workflow`
- Scope mentions user workflow, visible status, cross-role handoff, or lifecycle.
- `Background:` is optional and only for stable reusable setup such as login.

## 6. Feature Annotation Standards

Feature annotations are Gherkin comments that keep trace and test-design context next to the executable specification. They replace separate automation context markdown files.

They are not automation instructions.

Feature-level annotation:
- Required in `create` mode.
- Not added in `append` mode because append mode must not rewrite top-level feature content.
- Must appear after `Story`, `Goal`, and `Scope`, before `Background:` or scenarios.
- Allowed keys: `businessDomain`, `validationScope`, `source`, `implementationBoundary`.
- `implementationBoundary` must be a generic boundary reminder only; it must not name implementation artifacts.

Scenario-level annotation:
- Required before every generated `Scenario` and `Scenario Outline` in both `create` and `append` mode.
- Must appear immediately before the scenario tags so the tags remain directly attached to the scenario.
- Allowed keys: `tp`, `ac`, `validationTarget`, `observableEvidence`, `testDataIntent`.
- `tp` must list the approved Phase 1 test point IDs covered by the scenario.
- `ac` must list the approved AC IDs covered by the scenario.
- `validationTarget` and `observableEvidence` must come from approved Phase 1 fields.
- `testDataIntent` must describe business data intent only, not fixtures, builders, payload files, database rows, or helper names.

Format:

```gherkin
  # Scenario Annotation:
  # tp: TP-001, TP-002
  # ac: AC-01, AC-02
  # validationTarget: trade booking is persisted with the expected business status
  # observableEvidence: booking response contains trade id and booked status
  # testDataIntent: valid active customer, supported currency pair, and valid FX TRF product terms
  @TC-TRADE_CREATE-API-001 @positive @smoke
  Scenario: [TC-TRADE_CREATE-API-001] Should accept a valid FX TRF trade submitted by maker
```

Forbidden in annotations:
- step definition names
- snippet names
- Java class or method names
- page object, API client, fixture, helper, request builder, or response matcher names
- selectors, endpoints, payload files, database tables, environment IDs, or implementation commands
- instructions to reuse or create a specific automation artifact

## 7. Coverage Grouping

`bdd-case-design-methodology.md` defines how to decide grouping. This section defines the exact output constraints.

Coverage Group standards:
- One Coverage Group becomes one scenario or one Scenario Outline.
- Every approved TP must appear in exactly one Coverage Group unless the human-approved plan explicitly says otherwise.
- Use approved Phase 1 layer, tags, validation target, observable evidence, AC mapping, scenario name, and reasoning as grouping inputs.
- Preserve each group's validation target and observable evidence in scenario design.
- A group must stay within one layer.
- A group must have one executable flow and one clear business purpose.
- Do not group positive and negative behavior in the same scenario or Scenario Outline.
- The `Grouping Basis` must explain why the selected test points are compatible using approved Phase 1 fields.

## 8. Scenario Level

TC IDs:
- API: `TC-{FEATURE_MODULE}-API-{NNN}`
- UI: `TC-{FEATURE_MODULE}-{SUBTYPE}-UI-{NNN}`

`{FEATURE_MODULE}` is the `featureModule` value derived from `featureTag`.
`{SUBTYPE}` is UI-only and represents the primary UI business action: `CREATE`, `APPROVE`, `CANCEL`, `AMEND`, `CONFIG`, `LIFECYCLE`, etc.

Scenario rules:
- One Coverage Group normally becomes one scenario.
- One scenario proves one behavior and should stay within 3-8 executable steps when practical.
- Preserve TP order within each layer.
- TC sequence scope is the TC prefix before `{NNN}`:
  - API prefix: `TC-{FEATURE_MODULE}-API`
  - UI prefix: `TC-{FEATURE_MODULE}-{SUBTYPE}-UI`
- In `append` mode, use the existing max sequence for the same prefix + 1.
- If the same file has no matching prefix, start that prefix at `001`.
- Tags order: `@{TC-ID} @{positive|negative} @{smoke|regression}`.
- Scenario summary format: `Scenario: [{TC-ID}] Should {specific expected business behavior}`.
- Scenario Outline summary format: `Scenario Outline: [{TC-ID}] Should {specific expected business behavior}`.
- The `{TC-ID}` inside the summary must exactly match the scenario's `@{TC-ID}` tag without the leading `@`.
- Use active business wording.
- Use third-person role language consistently; avoid mixing `I`, `the user`, and named roles in the same feature.
- Negative names must identify rejected condition.
- Use `Scenario Outline` for one behavior repeated over multiple examples.
- Do not combine positive and negative behaviors in the same scenario or Scenario Outline.
- Every scenario or Scenario Outline must include a Scenario Annotation comment block immediately before its tags.
- In `append` mode, append each Scenario Annotation together with its scenario block.

## 9. API Step Pattern Standards

`bdd-case-design-methodology.md` defines how to design API business steps. This section defines allowed and forbidden API step wording.

API feature files describe business API behavior, not HTTP mechanics or automation glue.

```gherkin
  # Scenario Annotation:
  # tp: TP-001
  # ac: AC-01
  # validationTarget: FX TRF trade creation request is accepted
  # observableEvidence: response matches the expected trade-create contract
  # testDataIntent: valid maker and valid FX TRF trade details
  @TC-TRADE_CREATE-API-001 @positive @smoke
  Scenario: [TC-TRADE_CREATE-API-001] Should create an FX TRF trade successfully
    Given maker has valid FX TRF trade details
    When maker submits the FX TRF trade for booking
    Then the FX TRF trade should be created successfully
```

Rules:
- API steps must use business language: actor, business request, accepted/rejected outcome, persisted state, audit/event outcome, or downstream business effect.
- Status code and current-scenario schema/body validation must not appear as Gherkin steps. They are implementation details for `automation-agent`.
- Do not expose HTTP methods, paths, headers, payload files, request builders, response matcher names, Java classes, service clients, fixtures, or helper names.
- Do not force wording to match existing automation glue.
- A `Given` may describe business preconditions or data state.
- A `When` describes the business request/action.
- A `Then` describes the business outcome or observable evidence approved by Phase 1.
- A `Then` must not claim stronger business evidence than the implementation is expected to verify. If approved evidence is only status code plus current-scenario contract, use contract outcome wording, not data-completeness wording.
- Downstream Automation Agent decides whether the implementation uses genie-rest, YAML response contracts, Java assertions, API clients, fixtures, or helpers.

Contract outcome step patterns:

| API outcome | Preferred business step pattern | Intended implementation evidence |
|-------------|---------------------------------|----------------------------------|
| Create success | `Then the {business object} should be created successfully` | Expected status code and current-scenario response contract. |
| Retrieve success | `Then the {business object} should be retrieved successfully` | Expected status code and current-scenario response contract. |
| List retrieval success | `Then the {business object} list should be retrieved successfully` | Expected status code and current-scenario list response contract. |
| Update success | `Then the {business object} should be updated successfully` | Expected status code and current-scenario response contract. |
| Delete/cancel success | `Then the {business object} should be deleted successfully` or `Then the {business object} should be cancelled successfully` | Expected status code and current-scenario response contract. |
| Rejection | `Then the {business object} request should be rejected` | Expected error status code and current-scenario error contract. |

Business evidence step patterns:

Use these only when approved Phase 1 validation target and observable evidence require more than status/schema contract validation:

| Required evidence | Allowed business step pattern |
|-------------------|-------------------------------|
| Response contains an entity created earlier | `Then the created {business object} should be included in the response` |
| Response contains a specific business state | `Then the {business object} should have status "{status}"` |
| Rejection reason must be specific | `Then the rejection reason should identify {business reason}` |
| Persistence/audit/event must be verified | `Then the {business object} should be recorded for {business purpose}` |

Do not write data-completeness claims such as `Then all configured reasons should be returned` unless Phase 1 explicitly requires that content assertion and downstream automation will implement a business-field check.

Assertion design table:

| Approved validation target | Phase 2 business step strategy |
|----------------------------|--------------------------------|
| Status code, schema, response body contract | Contract outcome step such as `the reason should be created successfully`; implemented later by status + current-scenario contract checks. |
| Error code or generic error response contract | Rejection outcome step such as `the reason request should be rejected`; implemented later by error status + current-scenario error contract checks. |
| Returned business state, calculated value, permission rejection reason shown in response | Business evidence step with the expected state/reason in domain language. |
| Database persistence, audit record, emitted event, asynchronous state, downstream side effect | Business evidence step stating the persisted/audit/event/side-effect outcome. |
| UI-visible evidence such as button, dialog, banner, or blotter status | UI scenario, not API assertion. |

## 10. UI Step Pattern Standards

`bdd-case-design-methodology.md` defines how to design UI business steps. This section defines allowed and forbidden UI step wording.

UI feature files contain business-intent steps only.

Good UI steps:
- `When maker creates a new FX TRF trade`
- `Then user verifies trade status is 'Pending Approval' in blotter`
- `When checker approves the pending trade`

Bad UI steps:
- `When user clicks the Create button`
- `When user fills 'FX TRF' into product type`
- `When user completes full trade lifecycle`

Rules:
- One step pattern = one user intent or one business-visible assertion.
- Do not expose raw genie-playwright glue, selectors, clicks, fills, page object names, fixture names, or helper names.
- Use domain language and third-person role language consistently.
- Multi-actor flow is allowed for handoff/lifecycle TPs.
- Use `Given` for setup/state, `When` for action, `Then` for assertions.

## 11. Design Integrity Rules

These rules are mandatory for Phase 2 generation. Treat any violation as a defect to classify and repair before returning the final output.

### Phase 1 Preservation Rules

- Do not add scenarios, assertions, AC coverage, validation targets, or observable evidence that are not represented by approved Phase 1 test points.
- Do not change approved Phase 1 layer, tags, AC mapping, validation target, or observable evidence.
- Do not re-parse the raw story or ACs to create new test intent.
- If safe generation requires changing Phase 1 intent, classify it as `PHASE_1_GAP` and do not self-repair it in Phase 2.

### Coverage Rules

- Every approved TP must appear exactly once in Coverage Grouping Plan, Scenario Blueprint, and Scenario Breakdown.
- Every generated scenario must trace to one or more approved TPs.
- Every approved validation target and observable evidence item must be asserted by generated feature content or explicitly identified as blocked by a classified gap.
- AC Coverage Matrix must cover every AC referenced by approved Phase 1.

### Grouping Rules

- Group only test points with the same layer and compatible polarity.
- Group only test points with compatible validation targets, observable evidence, setup shape, and business flow.
- Split a candidate group when it creates a vague scenario, mixes unrelated behavior, mixes positive and negative behavior, hides evidence, or requires materially different setup.
- Use `Scenario Outline` only for variants of the same behavior with compatible expected outcomes.
- `Grouping Basis` must cite approved Phase 1 fields as evidence for compatibility.

### Scenario Design Rules

- One scenario must prove one cohesive business behavior.
- Scenario and Scenario Outline summaries must start with `[{TC-ID}] Should ...`.
- The TC ID in the summary must match the TC ID tag on the same scenario.
- API scenario summaries must not overclaim beyond approved API evidence. Contract-only scenarios should use outcome wording such as `Should create/retrieve/update/delete {business object} successfully`.
- Every generated scenario must include a Scenario Annotation comment block with approved TP, AC, validation target, observable evidence, and business test data intent.
- Scenario steps must preserve Given/When/Then completeness.
- `Background:` may contain only stable shared setup, never the behavior under test, dynamic data preparation, or assertions.
- Scenario summaries must be specific and active; negative scenario summaries must identify the rejected condition.
- TC IDs, scenario tags, feature tags, and file modes must follow this standards document.

### Business Language Rules

- API and UI steps must use business language and stay free of implementation mechanics.
- Feature and scenario annotations must use business and test-design language only.
- The same business meaning must use one consistent step pattern.
- API contract outcome steps should use parameterizable business-object/outcome wording instead of entity-specific wording that implies different implementation.
- Feature wording must not be changed only to fit assumed existing automation glue.
- Existing `.feature` files may influence terminology only when the wording remains clean business language.

### Context Rules

- Missing path, existing feature evidence, TC sequence evidence, or other safe-generation context must be classified as `CONTEXT_GAP`.

## 12. Required Output Checks

Before returning:
- Every approved TP is represented once in Coverage Grouping Plan, Scenario Blueprint, and Breakdown.
- No scenario exists without an approved TP.
- Scenario count is minimized through valid grouping without losing traceability.
- Scenario and Scenario Outline summaries include the matching TC ID in `[TC-...] Should ...` format.
- Feature content in create mode includes a Feature Annotation comment block.
- Every generated scenario includes a Scenario Annotation comment block.
- Annotations contain only allowed trace and test-design fields and no implementation details.
- API contract-only scenarios use contract outcome wording and do not claim data completeness, persistence, audit, event, or field-level business assertions unless approved Phase 1 evidence requires those checks.
- Scenario language follows the methodology and Business Language Standards: domain language, consistent third-person voice, one behavior per scenario, and strategic tags.
- API and UI scenarios keep implementation mechanics out of feature steps.
- Coverage grouping is justified by approved Phase 1 test point fields and the grouping rules above.
- Every approved validation target and observable evidence item is asserted or explicitly covered by a generated scenario.
- Generation Context explains evidence for object/action/module/tag/domain/path.
- Generation Context declares each layer's file mode: `create`, `append`, or `not generated`.
- API/UI files are separate.
- Existing files are append-only.
- AC Coverage Matrix covers every AC referenced by Phase 1.

## 13. Output Contract

This section is the single detailed output contract for `bdd-case-design-agent`. Other workflow files should reference this section instead of duplicating the template.

`Generation Context` is Phase 2 generation metadata. It is not a restatement of Phase 1. It records how Phase 2 derived feature identity, file paths, file modes, and evidence from:
- approved `qa-test-analysis-agent` output for trace and coverage constraints
- source payload title, description, persona, and approved solution design for naming and wording evidence
- `{E2E_DIR}` path hints and existing `.feature` files for file mode, terminology, and TC sequence evidence
- this standards document for naming, path, tag, and feature-generation rules

Return only this markdown structure:

````markdown
# BDD Feature Generation Result

**Business Domain:** {businessDomain}
**Feature Name:** {featureName}
**Feature Tag:** `@{featureTag}`
**Feature Module:** {featureModule}

## Generation Context

| Field | Value | Derivation Evidence |
|-------|-------|---------------------|
| Feature Name | {featureName} | {evidence} |
| Feature Tag Name | {featureTag} | {evidence} |
| Feature Module | {featureModule} | Uppercase featureTag for TC ID prefix |
| Business Domain | {businessDomain} | {evidence} |
| API File | features/api/{businessDomain}/{featureName}.feature or N/A | {evidence} |
| API Mode | create / append / not generated | {scenario count and file existence evidence} |
| UI File | features/ui/{businessDomain}/{featureName}.feature or N/A | {evidence} |
| UI Mode | create / append / not generated | {scenario count and file existence evidence} |

## Context Gaps

| Context | Gap | Impact | Action |
|---------|-----|--------|--------|

If no context gaps exist, write: `None`.

## Coverage Grouping Plan

| Group ID | Layer | Source TPs | Grouping Basis | Validation Target(s) | Observable Evidence Covered | Grouping Reason | Scenario Strategy |
|----------|-------|------------|----------------|----------------------|-----------------------------|-----------------|------------------|

## Scenario Blueprint

| Coverage Group | Source TPs | Layer | Final TC ID | Scenario Summary | Tags | AC Covered | Evidence Covered |
|----------------|------------|-------|-------------|------------------|------|------------|------------------|

## API Feature

**File:** `features/api/{businessDomain}/{featureName}.feature`
**Mode:** create / append / not generated
**Feature tags:** `@api @{featureTag}`
**Scenario count:** {N}

```gherkin
{complete API feature content with annotations for create mode; new scenario annotation + scenario/scenario outline blocks only for append mode; omit block when mode is not generated}
```

## UI Feature

**File:** `features/ui/{businessDomain}/{featureName}.feature`
**Mode:** create / append / not generated
**Feature tags:** `@playwright @{featureTag}`
**Scenario count:** {N}

```gherkin
{complete UI feature content with annotations for create mode; new scenario annotation + scenario/scenario outline blocks only for append mode; omit block when mode is not generated}
```

## Scenario Breakdown

| # | Coverage Group | Source TPs | TC Tag | Layer | Scenario Summary | Scenario Tags | Validation Target | Evidence Covered | AC Covered |
|---|----------------|------------|--------|-------|------------------|---------------|-------------------|------------------|------------|

## AC Coverage Matrix

| AC # | Summary | Covered by |
|------|---------|------------|

**Uncovered ACs:** None

## Cucumber Run Commands

```bash
{single generated scenario command}
{API feature command, only when API scenarios exist}
{UI feature command, only when UI scenarios exist}
```

````
