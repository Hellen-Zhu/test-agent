# Automation Implementation Standards

Detailed implementation standards for `automation-agent`. This document defines how to turn approved `.feature` files into reusable Cucumber bindings, snippets, Java step definitions, framework helpers, and deterministic test data.

The `.feature` file is the golden source. Do not change step text, TC IDs, tags, scenario summaries, scenario grouping, embedded annotations, or business behavior to fit existing automation code.

## 1. Required Skills

`automation-agent` must be able to apply these skills:

| Skill | Expected behavior |
|-------|-------------------|
| Feature parsing | Extract TC tags, scenario summaries, layer tags, Feature/Scenario Annotation comments, Given/When/Then steps, Scenario Outline examples, and assertion intent from approved `.feature` files. |
| Cucumber binding analysis | Map feature step text to exact or parameterized existing step definitions/snippets without changing feature wording. |
| Regex and parameter design | Design stable capture groups for product, role, status, ID, date, currency, amount, and quantity without over-parameterizing. |
| Snippet design | Create or reuse `.snippet` files for reusable business capabilities when the framework supports snippet-level composition, especially API contract outcome steps that compose built-in glue. |
| Java step definition design | Keep Java step definitions thin and delegate implementation mechanics to page objects, API clients, fixtures, data builders, or helpers. Use Java only when snippets/built-in glue cannot implement the approved step cleanly. |
| API automation | Implement business API steps using built-in request/response glue, current-scenario contract assertions, existing API clients, fixtures, and cleanup conventions. |
| UI automation | Implement UI business steps through page objects, stable selectors, explicit waits, workflow helpers, and screenshots/traces where supported. |
| Test data design | Build deterministic, isolated, cleanup-safe data using Scenario Outline examples, fixtures, factories, seed APIs, or approved builders. |
| Duplicate prevention | Search existing snippets, Cucumber bindings, helpers, clients, fixtures, and page objects before creating new artifacts. |
| Verification | Run dry-run, compile, targeted Cucumber, API/UI, or narrow framework checks appropriate to the changed artifacts. |

## 2. Source Rules

- The approved `.feature` file is the golden source for step text, TC IDs, tags, scenario grouping, and business behavior.
- Feature and Scenario Annotation comments inside the approved `.feature` file are trace and test-design context. They may clarify TP/AC trace, validation target, observable evidence, and business test data intent.
- Annotations are not implementation instructions. They must not force reuse of a specific step definition, snippet, Java method, page object, API client, fixture, helper, selector, endpoint, payload file, request builder, or matcher.
- Phase 2 reports, source stories, solution design, and review comments are trace context only. They must not override the feature file.
- If a feature step cannot be implemented without changing the business language, report `DESIGN_GAP` instead of changing the feature file.
- Do not add implementation-only steps to feature files.
- Do not remove or merge approved scenarios, tags, or steps during automation implementation.
- If an annotation contains implementation details, ignore the implementation-specific part and report a design follow-up. Do not implement from forbidden annotation details.

## 3. Step Inventory Rules

For every approved feature file, build a step inventory before implementing:

| Item | Required use |
|------|--------------|
| Feature path | Scope implementation and verification commands. |
| Layer tag | Select API or UI implementation strategy. |
| TC tag | Drive dry-run, targeted execution, and reporting. |
| Feature Annotation | Understand business domain, validation scope, and source trace. |
| Scenario Annotation | Understand TP/AC mapping, validation target, observable evidence, and business test data intent. |
| Scenario summary | Understand business behavior and expected outcome. |
| Given steps | Identify preconditions, fixtures, setup snippets, or existing state requirements. |
| When steps | Identify action under test. |
| Then steps | Identify assertions, contract checks, UI evidence, persistence, audit, or event validation. |
| Examples table | Drive parameterized test data and expected results. |

## 4. Binding Decision Rules

For each feature step, classify binding as one of:

| Decision | Meaning |
|----------|---------|
| Exact existing match | Existing snippet or step definition matches the approved step text exactly. |
| Parameterized existing match | Existing regex/string pattern matches the same business meaning and layer. |
| Built-in glue composition | Existing built-in glue can implement the approved business step through a snippet or framework binding. |
| New business snippet | A reusable snippet should compose built-in glue behind the approved business step. |
| New Java step definition | A Java binding is required because snippet/glue composition is insufficient. |
| Existing helper/client/page object reuse | Binding is missing but lower-level implementation support already exists. |
| `DESIGN_GAP` | The step is ambiguous, unimplementable, or requires changing business wording. |

Rules:
- Reuse exact same-layer bindings before creating new ones.
- Reuse parameterized same-layer bindings when the business meaning and outcome are the same.
- For API contract outcome steps, prefer existing or new parameterized business snippets over new Java step definitions.
- Do not reuse across API and UI layers.
- Do not create duplicate regex patterns for the same business meaning.
- Do not create one Java step definition per API entity when the only difference is the business object name, such as `reason created successfully` vs `trade created successfully`.
- Do not create story-specific, TC-specific, endpoint-specific, selector-specific, or payload-file-specific step definitions.
- Prefer business-domain parameters over technical parameters.

## 5. Snippet Rules

Read `~/.claude/docs/snippet-design-guide.md` when the project uses genie snippets or snippet-level business steps.

Use snippets when:
- a UI business action requires multiple low-level navigation, click, fill, wait, or assertion operations
- an API precondition requires multiple setup calls to create reusable state
- an API contract outcome business step can be implemented by composing built-in glue such as request execution, status-code assertion, current-scenario response contract matching, and response field storage
- the behavior is reusable across scenarios and can be named as a business capability

Do not use snippets when:
- the step is already bound by an existing same-layer step definition
- the step requires custom business-field assertion logic that built-in glue cannot express
- the snippet would hide unrelated behaviors behind a vague business phrase
- more than three unrelated parameters are needed

Snippet naming rules:
- Use business intent, not UI operations or API mechanics.
- Parameterize stable business variables only.
- Keep snippets layer-specific.
- Store snippets in the existing project convention and update any catalog only when that is the repo practice.

## 6. Java Step Definition Rules

Use Java step definitions when snippets or built-in glue cannot implement the approved business step cleanly.

Rules:
- Keep step definitions thin.
- Step definitions should parse parameters, call helpers/clients/page objects, and assert high-signal outcomes.
- Do not put large workflow logic directly inside step definitions.
- Do not duplicate existing regex patterns.
- Avoid broad regex that can accidentally bind unrelated steps.
- Use clear parameter names and domain types when the framework supports them.
- Delegate UI mechanics to page objects or workflow helpers.
- Delegate API mechanics to API clients, request builders, fixtures, or contract assertion helpers.

## 7. API Automation Rules

- Implement API business steps without exposing HTTP paths, payload files, request builders, or matcher names in Gherkin.
- For contract-driven API scenarios, implement the approved business outcome step through existing built-in glue or a reusable business snippet that performs the expected status-code assertion and current-scenario response contract assertion.
- Use existing API clients, request builders, auth helpers, response contract helpers, built-in glue, and cleanup conventions.
- If the scenario tests an API response contract, prefer the framework's current-scenario contract assertion when available, and keep the feature wording at business-outcome level.
- Use explicit assertions for business state, error reason, persistence, audit, event, or downstream effect only when required by the feature step.
- Do not duplicate schema/status/body assertions if a single framework contract assertion already verifies them.
- If the project convention separates status-code assertion from current-scenario contract matching, keep both checks inside the snippet/binding rather than repeating them in every Java step definition.
- If feature wording claims list content, included item, business status, audit, event, or persistence, do not satisfy it with status/schema alone. Implement the business-field assertion or report `DESIGN_GAP`.
- API setup should use seed APIs, factories, fixtures, or clients rather than UI workflows.
- Keep generated records uniquely identifiable and cleanup-safe.

## 8. UI Automation Rules

- Implement UI business steps without changing approved Gherkin into clicks, fills, selectors, or page-object names.
- Use page objects or workflow helpers for page interactions.
- Use stable selectors or approved automation hooks.
- Wait on observable state, not arbitrary sleeps.
- Keep assertions tied to user-visible evidence required by the feature.
- Capture screenshots, traces, logs, or browser artifacts when the project convention supports failure diagnostics.
- Do not make UI tests responsible for broad data permutation coverage that belongs at API level.

## 9. Test Data Rules

Use the smallest deterministic data design that proves the approved feature behavior.

Data source priority:
1. Scenario Outline `Examples` values.
2. Explicit values in feature step parameters.
3. Scenario Annotation `testDataIntent` when present.
4. Existing fixtures, factories, seed APIs, or test data builders.
5. Approved solution-design context when the feature file needs implementation context.
6. Technical notes only as weak fallback when approved design evidence is missing.

Rules:
- Keep test data isolated per scenario.
- Generate unique IDs, trade references, request IDs, and external references.
- Make cleanup explicit for created trades, users, events, files, and downstream records when the framework supports cleanup.
- Do not hard-code environment-specific IDs unless they are documented reference data.
- Keep negative data purposeful; encode why it is invalid.
- For FX/TRF scenarios, treat product, currency pair, direction, notional, strike, tenor, fixing/settlement dates, status, and role as business-significant values.
- Do not invent pricing formulas, rounding rules, settlement calendars, or market data behavior without approved source evidence.
- Prefer builders/fixtures over large inline payloads.
- Avoid sharing mutable test data across parallel scenarios.

## 10. Fixture And Cleanup Rules

- Reuse existing fixture and cleanup patterns before creating new ones.
- Setup should create only the state required by the feature step.
- Cleanup should run even when assertions fail, using the repo's hooks or teardown conventions.
- Avoid hidden dependencies on scenario execution order.
- Store generated identifiers in scenario context only as needed for later steps.
- Do not leak business assertions into generic fixtures.

## 11. Verification Rules

Run the narrowest meaningful checks available:
- Cucumber dry-run for generated TC tags
- compile/test command for changed Java code
- snippet or binding validation when the framework supports it
- targeted API or UI scenario command when safe
- lint/static checks used by the repo for test code

If verification cannot run, report:
- exact command attempted or recommended
- blocker
- residual risk

## 12. Anti-Patterns

Avoid:
- changing feature wording to match existing glue
- duplicate step definitions with slightly different regex
- one Java step definition per API business object when a parameterized outcome snippet/binding would cover the same contract outcome
- broad catch-all regex such as `(.*)` for unrelated business meanings
- story-specific snippets or step definitions
- selector, endpoint, payload, Java class, fixture, or helper names in feature steps
- UI data setup for API tests
- shared mutable test data
- hidden assertions in setup snippets
- step definitions that contain large UI or API workflows directly
- tests that pass only because of execution order

## 13. Required Output Checks

Before returning:
- Every feature step has a binding decision.
- Missing bindings are implemented or reported as `DESIGN_GAP`.
- No approved feature wording, TC ID, tag, scenario summary, or grouping was changed.
- New bindings do not duplicate existing same-layer business meanings.
- API contract outcome steps reuse or create parameterized snippet/glue bindings instead of duplicate entity-specific Java implementations.
- Any API business evidence step that claims data correctness has a real business assertion beyond status/schema, or is reported as `DESIGN_GAP`.
- Test data is deterministic, isolated, and cleanup-safe.
- API/UI implementation details remain outside feature files.
- Feature annotations were parsed as trace/test-design context only and did not override approved step wording or force implementation artifact choices.
- Verification was run or the blocker is reported with exact commands.
