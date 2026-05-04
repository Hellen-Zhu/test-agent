# BDD Feature Generation Standards

Detailed rules for `bdd-case-design-agent`. It converts confirmed Phase 1 `TP-###` test points into a small set of high-value API/UI Cucumber scenarios.

## 1. Source Boundaries

| Purpose | Source of truth | Fallback | Forbidden |
|---------|-----------------|----------|-----------|
| Test point existence/layer/tags | Confirmed Phase 1 report | None | Re-parsing story/ACs |
| Coverage groups/scenario count | Phase 1 `Grouping Key` + this document | Split for readability or execution correctness | Assuming one TP must equal one scenario |
| AC coverage | Phase 1 AC mapping | Original AC text for wording only | Changing coverage decisions |
| Validation target/evidence | Phase 1 Validation Target + Observable Evidence | None | Dropping evidence because the AC ID is covered |
| Feature naming/path | Story title + TP names | Description/persona; approved API operation wording as weak fallback | story module, class names, endpoints, story IDs |
| API details | Approved `solutionDesign.apiDesign` | Technical notes only if solution design is missing; existing feature patterns | UI assumptions; technical notes overriding solution design |
| API response contract | YAML contract bound to the current scenario | Existing response contract patterns | Duplicating status/schema/body assertions in feature steps |
| UI wording | TP names + persona + `solutionDesign.uiDesign` | Description | Endpoint names |
| Extra API assertions and test data | Phase 1 validation target + approved `solutionDesign.testDesignImplications` | Technical notes only as weak fallback | Inventing DB/audit/event assertions without design evidence |

If Phase 1 has no approved test point for a behavior, do not generate a scenario for it.

When approved `solutionDesign` exists, do not use `technicalNotes` as the primary source for API paths, UI wording, response contracts, extra assertions, or test data. If `technicalNotes` conflicts with approved `solutionDesign`, use `solutionDesign` and mention the conflict in derivation evidence when relevant.

## 2. BDD Authoring Principles

Feature files are executable business specifications. They must be readable by stakeholders and stable enough to drive or verify implementation.

Rules:
- Write the feature from expected behavior, not from existing code structure. Existing `.feature` files may provide clean business terminology, but implementation code must not shape the Gherkin wording.
- Use domain language in `Feature`, description, scenario names, and reusable steps. Avoid Java class names, CSS selectors, DOM IDs, endpoint names, paths, and other technical terms.
- Use one consistent voice. Prefer third-person role language such as `maker`, `checker`, `admin`, and `the user`; do not mix it with first-person `I`.
- One scenario proves one behavior. A scenario may assert multiple outcomes only when they are part of the same behavior and coverage group.
- Keep scenarios short. Target 3-8 executable business steps; split the behavior or move stable setup into clear business preconditions when the flow becomes hard to review.
- Use `Background:` only for shared stable `Given` setup. Do not hide behavior under test, dynamic data preparation, or assertions in `Background:`.
- Use `Scenario Outline` only for data or expectation variants of the same behavior. Do not mix positive and negative examples in one outline.
- Use tags for execution selection, not metadata. Do not add story IDs, AC IDs, modules, domains, or arbitrary labels as Cucumber tags.
- Keep feature steps at the business contract level. Downstream automation may implement them with snippets, step definitions, page objects, service clients, fixtures, or helpers, but those implementation details must not leak into feature files.
- Treat the generated feature as a stakeholder review artifact. The business behavior should be understandable without reading Java, Playwright selectors, or request builder code.

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

Default automation handoff files:
- API: `{E2E_DIR}/src/test/resources/features/api/{businessDomain}/{featureName}.automation-handoff.md`
- UI: `{E2E_DIR}/src/test/resources/features/ui/{businessDomain}/{featureName}.automation-handoff.md`

Rules:
- API and UI are always separate files.
- Create a file only for layers with approved test points.
- File names are snake_case and contain no TC IDs, story IDs, `_api`, `_ui`, or `_e2e`.
- Same feature name may exist under both `api/` and `ui/`.
- Ignore any legacy `bddFeatureFile`, `apiFeatureFile`, or `uiFeatureFile` fields in source JSON.
- Automation handoff files are layer-scoped and live next to their corresponding feature file.

Existing files:
- Read target file when present.
- Determine file mode per layer: `create`, `append`, or `not generated`.
- Continue TC numbering from existing scenarios with the same TC prefix.
- In `append` mode, output scenario/scenario outline blocks only.
- In `append` mode, do not introduce a new top-level `Background:`. Put setup explicitly in the appended scenarios.
- Do not duplicate top-level tags, `Feature:`, descriptions, or `Background:`.

Automation handoff files:
- Handoff mode is derived independently from handoff file existence for the generated layer.
- Use `create` when the layer has generated scenarios and the handoff file does not exist.
- Use `append` when the layer has generated scenarios and the handoff file already exists.
- Use `not generated` when the layer has no generated scenarios.
- In `create` mode, write a complete handoff document for that layer.
- In `append` mode, append a new handoff batch for the newly generated scenarios only. Do not overwrite previous handoff batches.
- In `not generated` mode, do not create a handoff file for that layer.
- A layer handoff file must contain only step patterns and implementation notes for that layer.

## 5. Feature Level

Common structure:

```gherkin
@{layerTag} @{featureTag}
Feature: {Business Object} {Capability} {Layer Label}
  Story: {storyId} - {title}
  Goal: {one sentence business goal}
  Scope: {layer scope}
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

## 6. Coverage Grouping

Do not assume one test point equals one scenario. Phase 2 should group compatible test points so a smaller scenario set covers more approved validation intent.

Coverage Group rules:
- One Coverage Group becomes one scenario or one Scenario Outline.
- Every approved TP must appear in exactly one Coverage Group unless the human-approved plan explicitly says otherwise.
- Use the confirmed Phase 1 `Grouping Key` as the primary grouping input.
- Preserve each group's validation target and observable evidence in scenario design.
- Test points with the same `Grouping Key` should normally stay in the same group.
- Split a shared `Grouping Key` only when execution, readability, or assertion strategy would become unclear.
- Merge different `Grouping Key` values only when the same layer, entry point, precondition, action, and assertion theme are demonstrably identical; explain the evidence in the grouping reason.
- A group must stay within one layer.
- A group must have one executable flow and one clear business purpose.
- Do not group positive and negative behavior in the same scenario or Scenario Outline. Scenario-level polarity tags must remain unambiguous.

Good grouping candidates:

| Compatible TPs | Scenario strategy |
|----------------|------------------|
| Same API business operation + same precondition + different invalid fields | One API `Scenario Outline` |
| Same API business operation + same success outcome + persistence evidence | One API scenario with multiple assertions |
| Same UI journey + multiple visible status checks | One UI journey scenario |
| Same lifecycle path + maker/checker handoff + final state checks | One UI lifecycle scenario |

Do not group when:
- Layers differ.
- Grouping keys indicate different entry points, preconditions, or assertion themes.
- Preconditions differ materially.
- The actions under test are different business flows.
- Failure handling differs enough to require different assertions.
- Grouping would make the scenario name vague or the steps hard to read.

UI scenario economy:
- Prefer 1-3 key UI journeys per feature.
- Push field validation, boundary values, data transformations, and error-code checks down to API.
- UI should prove the critical user path and visible business state, not duplicate every API rule.

## 7. Scenario Level

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
- Scenario line: `Scenario: [TC-ID] {specific English behavior}`.
- Use active business wording.
- Use third-person role language consistently; avoid mixing `I`, `the user`, and named roles in the same feature.
- Negative names must identify rejected condition.
- Use `Scenario Outline` for one behavior repeated over multiple examples.
- Do not combine positive and negative behaviors in the same scenario or Scenario Outline.

## 8. API Step Pattern Rules

API feature files describe business API behavior, not HTTP mechanics or automation glue.

```gherkin
  @TC-TRADE_CREATE-API-001 @positive @smoke
  Scenario: [TC-TRADE_CREATE-API-001] Maker submits a valid FX TRF trade
    Given maker has valid FX TRF trade details
    When maker submits the FX TRF trade for booking
    Then the trade should be accepted for approval
```

Rules:
- API steps must use business language: actor, business request, accepted/rejected outcome, persisted state, audit/event outcome, or downstream business effect.
- Do not expose HTTP methods, paths, headers, payload files, request builders, response matcher names, Java classes, service clients, fixtures, or helper names.
- Do not force wording to match existing automation glue.
- A `Given` may describe business preconditions or data state.
- A `When` describes the business request/action.
- A `Then` describes the business outcome or observable evidence approved by Phase 1.
- Downstream Automation Agent decides whether the implementation uses genie-rest, YAML response contracts, Java assertions, API clients, fixtures, or helpers.

Assertion design table:

| Approved validation target | Phase 2 business step strategy |
|----------------------------|--------------------------------|
| Status code, schema, response body, error code, error reason | Business outcome step, implemented later by API contract checks. |
| Returned business state, calculated value, permission rejection shown in response | Business outcome step with the expected state/reason in domain language. |
| Database persistence, audit record, emitted event, asynchronous state, downstream side effect | Business evidence step stating the persisted/audit/event/side-effect outcome. |
| UI-visible evidence such as button, dialog, banner, or blotter status | UI scenario, not API assertion. |

## 9. UI Step Pattern Rules

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

## 10. Automation Handoff Contract

Phase 2 designs reusable business step pattern contracts and persists them in the Automation Handoff Contract. It does not inspect or decide concrete step definition, snippet, page object, API client, fixture, helper, or Java method reuse.

Reuse design order:
1. Same business meaning inside the generated feature set -> use one identical pattern.
2. Same actor + verb + business object + outcome -> use the same pattern.
3. Same intent with variable product/status/role/date/amount -> define a parameterized business pattern.
4. Existing `.feature` files use a clean business term for the same concept -> align terminology if it does not leak implementation detail.
5. Otherwise define a new business step pattern contract.

Automation Handoff Contract must include:
- `Step Pattern`
- `Business Meaning`
- `Reusable Scope`
- `Implementation Need`
- `Suggested Owner`
- `Notes For Automation Agent`

Rules:
- Use business wording, not implementation wording.
- Parameterize product, status, role, ID, currency, date, amount, and quantity when stable.
- Avoid story-specific, TC-specific, endpoint-specific, selector-specific, or class-specific wording.
- Do not add `[REUSE]`, `[NEW_SNIPPET_NEEDED]`, or `[NEW_JAVA_STEP_NEEDED]` markers in Phase 2.
- Do not check whether a Cucumber step definition already exists.
- Do not decide which concrete step definition function, snippet file, Java method, page object, API client, fixture, or helper should be reused.
- Use `Automation Agent to resolve implementation reuse` when the downstream owner is unknown.

Phase 2 should hand off implementation needs without designing implementation internals.

Automation Handoff Contract is a persisted downstream contract. `/bdd-gen` writes it to:
- API: `{E2E_DIR}/src/test/resources/features/api/{businessDomain}/{featureName}.automation-handoff.md`
- UI: `{E2E_DIR}/src/test/resources/features/ui/{businessDomain}/{featureName}.automation-handoff.md`

When both API and UI are generated, create one handoff file per generated layer. Do not put UI step patterns in the API handoff file or API step patterns in the UI handoff file.

Automation Handoff Contract fields:

| Field | Meaning |
|-------|---------|
| Step Pattern | Business step contract from the feature file. |
| Layer | API or UI. |
| Business Meaning | What business behavior or evidence the step represents. |
| Reusable Scope | Where this business step pattern can be reused. |
| Implementation Need | Existing implementation unknown / likely new implementation / likely reusable business capability. |
| Suggested Owner | Automation Agent, API automation owner, UI automation owner, or team-specific owner. |
| Notes For Automation Agent | Business intent, data/state considerations, and constraints that should guide implementation. |

Each persisted handoff file should include:
- feature file path for the same layer
- generated TC tags for the same layer
- Automation Handoff Contract rows for the same layer

Forbidden in Automation Handoff Contract:
- Specific Cucumber function names.
- Page object, selector, API client, fixture, helper, or Java method design.
- Suggestions to change feature wording to fit existing code.

## 11. Required Output Checks

Before returning:
- Every approved TP is represented once in Coverage Grouping Plan, Scenario Blueprint, and Breakdown.
- No scenario exists without an approved TP.
- Scenario count is minimized through valid grouping without losing traceability.
- Scenario language follows the BDD authoring principles: domain language, consistent third-person voice, one behavior per scenario, and strategic tags.
- API and UI scenarios keep implementation mechanics out of feature steps.
- Coverage grouping is justified by Phase 1 `Grouping Key` values and the grouping rules above.
- Every approved validation target and observable evidence item is asserted or explicitly covered by a generated scenario.
- Generation Context explains evidence for object/action/module/tag/domain/path.
- Generation Context declares each layer's file mode: `create`, `append`, or `not generated`.
- Generation Context declares each layer's automation handoff path and mode.
- API/UI files are separate.
- Existing files are append-only.
- Automation handoff files are layer-scoped and written next to the corresponding feature file.
- Automation Handoff Contract covers every generated business step pattern.
- Automation Handoff Contract covers implementation ownership without selecting concrete automation code reuse.
- AC Coverage Matrix covers every AC referenced by Phase 1.

## 12. Output Contract

This section is the single detailed output contract for `bdd-case-design-agent`. Other workflow files should reference this section instead of duplicating the template.

`Generation Context` is Phase 2 generation metadata. It is not a restatement of Phase 1. It records how Phase 2 derived feature identity, file paths, file modes, handoff paths, and evidence from:
- approved `qa-test-analysis-agent` output for trace and coverage constraints
- source payload title, description, persona, and approved solution design for naming and wording evidence
- `{E2E_DIR}` path hints and existing `.feature` files for file mode, terminology, and TC sequence evidence
- this standards document for naming, path, tag, and handoff rules

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
| API Handoff File | features/api/{businessDomain}/{featureName}.automation-handoff.md or N/A | {evidence} |
| API Handoff Mode | create / append / not generated | create if generated layer handoff file does not exist; append if it exists; not generated when API is not generated |
| UI File | features/ui/{businessDomain}/{featureName}.feature or N/A | {evidence} |
| UI Mode | create / append / not generated | {scenario count and file existence evidence} |
| UI Handoff File | features/ui/{businessDomain}/{featureName}.automation-handoff.md or N/A | {evidence} |
| UI Handoff Mode | create / append / not generated | create if generated layer handoff file does not exist; append if it exists; not generated when UI is not generated |

## Context Gaps

| Context | Gap | Impact | Action |
|---------|-----|--------|--------|

If no context gaps exist, write: `None`.

## Coverage Grouping Plan

| Group ID | Layer | Source TPs | Grouping Key(s) | Validation Target(s) | Observable Evidence Covered | Grouping Reason | Scenario Strategy |
|----------|-------|------------|-----------------|----------------------|-----------------------------|-----------------|------------------|

## Scenario Blueprint

| Coverage Group | Source TPs | Layer | Final TC ID | Scenario Name | Tags | AC Covered | Evidence Covered |
|----------------|------------|-------|-------------|---------------|------|------------|------------------|

## API Feature

**File:** `features/api/{businessDomain}/{featureName}.feature`
**Mode:** create / append / not generated
**Feature tags:** `@api @{featureTag}`
**Scenario count:** {N}

```gherkin
{complete API feature content for create mode; new scenario/scenario outline blocks only for append mode; omit block when mode is not generated}
```

## UI Feature

**File:** `features/ui/{businessDomain}/{featureName}.feature`
**Mode:** create / append / not generated
**Feature tags:** `@playwright @{featureTag}`
**Scenario count:** {N}

```gherkin
{complete UI feature content for create mode; new scenario/scenario outline blocks only for append mode; omit block when mode is not generated}
```

## Scenario Breakdown

| # | Coverage Group | Source TPs | TC Tag | Layer | Scenario Description | Scenario Tags | Validation Target | Evidence Covered | AC Covered |
|---|----------------|------------|--------|-------|---------------------|---------------|-------------------|------------------|------------|

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

## Automation Handoff Contract

| Step Pattern | Layer | Business Meaning | Reusable Scope | Implementation Need | Suggested Owner | Notes For Automation Agent |
|--------------|-------|------------------|----------------|---------------------|-----------------|----------------------------|

Do not decide whether a concrete Cucumber step definition already exists. Write `Automation Agent to resolve implementation reuse` when implementation ownership is unknown.
````
