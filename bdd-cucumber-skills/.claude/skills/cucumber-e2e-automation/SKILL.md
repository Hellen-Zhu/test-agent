---
name: cucumber-e2e-automation
description: This skill should be used when the user asks to "write E2E step definitions", "implement Java Cucumber UI tests", "add Playwright Java steps", "generate E2E tests from a feature file", or when creating/editing any Java file under `src/test/java/.../stepdefs/e2e/`, `src/test/java/.../snippets/`, `src/test/resources/locators/`, or matching a `features/ui/**/*.feature`. Provides the team's reuse-first BDD workflow: discover built-in steps → discover existing project steps → compose a snippet → only last-resort author a new Java step. Locators live in per-page JSON files; selectors are discovered live via Playwright MCP.
---

# Cucumber E2E Automation

How to implement step definitions for `features/ui/**/*.feature` files using Java + Cucumber + the team's internal Playwright BDD framework. The framework provides pre-integrated steps (Maven dependency), a JSON locator catalog, and a snippet pattern for composing reusable business flows. This skill exists primarily to keep agents from skipping the reuse hierarchy and authoring redundant Java steps.

## When this applies

Use this skill when:
- A `features/ui/**/*.feature` file exists and the matching step defs / snippets / locators are missing or out of date.
- Editing Java files under `src/test/java/**/stepdefs/**`, `src/test/java/**/snippets/**`, or JSON under `src/test/resources/locators/**`.
- The user asks "write the UI test for this feature".
- A new page or user-facing flow needs coverage.

Do NOT use this skill when:
- The feature file itself needs writing → `bdd-feature-authoring`.
- Working on `features/api/**` step defs → `cucumber-api-automation`.
- Running or filtering tests → `cucumber-test-execution`.

## Hard Rules

1. **Reuse priority is STRICT**: built-in step (from Maven dep) → existing project step → new snippet composing existing steps → new Java step. Every downward jump requires written justification in the output report. Authoring a new Java step before exhausting the upper tiers is the single biggest anti-pattern this skill prevents.
2. **Locators NEVER appear inline in Java code.** They live ONLY in `src/test/resources/locators/<page-or-module>.json`. Java steps look up locators by key from this catalog via the framework's locator-loader API — never hardcode a selector string.
3. **ONE locator JSON file per page/module.** Filename matches the module key (`loginPage.json`, `checkoutPage.json`). Do not create umbrella files spanning multiple pages.
4. **New Java step authoring is LAST RESORT.** Before writing a new `@Given/@When/@Then`, the discovery checklist (built-in → existing project step → snippet) MUST be complete and findings recorded. If you skip the checklist, the step gets rejected on review.
5. **NEVER use `Thread.sleep`** or any time-based wait. Use Playwright's auto-waiting via the locator strategies the built-in steps already implement; if you must wait explicitly, use `Locator.waitFor()` / `Page.waitForURL()` / `Page.waitForResponse()`.
6. **NEVER re-implement lifecycle** (browser context creation, hooks, screenshot-on-failure, tracing). The built-in framework provides these. Verify by Grep'ing `@Before`/`@After` in the dependency before assuming missing — and only add hooks if Grep confirms a gap.
7. **Locator priority within a JSON entry is STRICT**: `data-testid` > role-based > label > text > placeholder > CSS > XPath. Going down requires a `_comment` field in the JSON entry explaining why and linking an issue.
8. **Selector discovery via Playwright MCP is the PREFERRED path** when the target page is reachable. Probe the live DOM/accessibility tree with `mcp__playwright` tools BEFORE writing locator JSON entries. Fall back to spec/screenshot inference ONLY when the app is not reachable. Either way, surface which mode was used in the output report.

## Standards (index)

| # | Standard | Details |
|---|----------|---------|
| S1 | **The locator JSON catalog is the SINGLE source of truth for selectors.** Code reviews reject any Java-side hardcoded locator. | `references/locators.md` |
| S2 | **Snippets compose existing steps; they NEVER touch Playwright directly.** A snippet that calls `page.locator(...)` is a smell — that logic belongs in a primitive step (preferably built-in). | `references/snippets.md` |
| S3 | **New Java steps are only justified when a primitive action is missing from the built-in library.** Composition belongs in snippets, not new primitives. | `references/step-discovery.md` |
| S4 | **Mock network only when the scenario is isolated UI behavior.** Integrated flows hit a real test backend. | `references/waits.md` |
| S5 | **Use `expect(locator)` from `PlaywrightAssertions`** for retrying assertions; Hamcrest only for non-retrying logical checks. | `references/waits.md` |

## Core Procedure

For each `.feature` file you implement:

### 1. Read the feature

Identify pages/modules touched, user flows, expected outcomes. Note which steps look like primitive actions ("click the X button") vs business flows ("complete checkout as default user") — the latter are snippet candidates.

### 2. Discovery phase (reuse inventory)

Build a reuse inventory BEFORE writing anything. See `references/step-discovery.md` for the full procedure. Summary:

- **2a. Built-in steps.** This agent has no Bash tool, so all built-in discovery goes through pre-materialized artifacts. Walk the 5-tier source hierarchy in `references/step-discovery.md § 1`:
  1. **Tier 1** — Glob `bdd-cucumber-skills/.bdd-step-index/*.txt`; Grep matching lines (pipe-delimited `@When|I click {string}|FQN`).
  2. **Tier 2** — Glob `docs/STEPS.md` / `docs/step-catalog.md` (framework-team-published catalog).
  3. **Tier 3** — cached Javadoc URL referenced in `pom.xml` or `docs/` → WebFetch the specific class page.
  4. **Tier 4** — AskUserQuestion for catalog pointer or explicit `NEW_STEP` permission.
  5. **Tier 5** — mark `Discovery source: unavailable` in the report; surface every unverified Gherkin line.
  - Record which tier you used (`Discovery source` field) and every match relevant to the feature's verbs into the inventory.
  - Do NOT escalate to Bash / unzip / mvn to "fix" a missing index — that's a build-engineer concern, raise it in the report instead.

- **2b. Existing project steps.** Glob `src/test/java/**/{steps,stepdefs}/**/*.java`. Grep for `@Given|@When|@Then` patterns matching each Gherkin line. Record matches.

- **2c. Distinguish snippets from primitives** within 2b's hits. Open each match. If the method body invokes other steps (via picocontainer-injected step classes or the framework's `runStep`/`executeStep` helper), it's a snippet — flag it as such. Snippets are great reuse targets; mistaking them for atomic primitives leads to layering violations.

### 3. Mapping phase

For each Gherkin line in the feature, assign one tag:

| Tag | Meaning | Action |
|-----|---------|--------|
| `REUSE_BUILTIN` | Matches a built-in step verbatim or via regex parameters | Use as-is. |
| `REUSE_PROJECT` | Matches an existing project step or snippet | Use as-is. |
| `NEW_SNIPPET` | Needs composition of 2+ existing steps into a higher-level abstraction | Author a new snippet (see `references/snippets.md`). |
| `NEW_STEP` | Primitive action genuinely missing from the built-in library | Author a new Java step (see `references/step-discovery.md` § "Last-resort new step"). Must justify in report. |

Every line must have exactly one tag. Lines you cannot tag stop the procedure — surface them to the user before proceeding.

### 4. Locator phase

For any element a new snippet or step touches that isn't already in the JSON catalog:

- **4a.** Probe via Playwright MCP (Hard Rule 8):
  - `mcp__playwright__browser_navigate` to the target URL.
  - `mcp__playwright__browser_snapshot` to capture the accessibility tree.
  - Walk the snapshot; pick the highest-priority stable locator per Hard Rule 7.
  - If `data-testid` is missing on a needed element, record this in the "Elements missing data-testid (dev follow-up)" section of the report — DO NOT silently degrade to text/CSS.
- **4b.** Open `src/test/resources/locators/<page>.json`. If absent, create it. Filename = module key, lowerCamelCase (matches existing convention — verify by Glob).
- **4c.** Insert the entry. Match the schema used by sibling JSON files exactly (different frameworks expect different selector syntax — verify by reading one existing entry before authoring). See `references/locators.md` for the team's schema.
- **4d. Fallback path** (only if app unreachable): infer locators from `.feature` text, available screenshots, and adjacent JSON entries. Tag every fallback entry with a `_todo` field: `"verify via MCP when <env> reachable"`.

### 5. Wire-up phase

- For `NEW_SNIPPET` rows: create or extend a class under `src/test/java/.../snippets/<area>/` (verify the existing convention via Glob first — if the project uses a different package, follow that). The snippet method should be a single `@Given/@When/@Then` annotation whose body calls other step classes via picocontainer injection, NEVER `Page`/`Locator` directly. Pattern in `references/snippets.md`.
- For `NEW_STEP` rows: create the step under `src/test/java/.../stepdefs/e2e/<area>/`. Inject the framework's locator-loader and use it to fetch the selector by key. Never hardcode the selector. Pattern in `references/step-discovery.md` § "Last-resort new step".

### 6. Hand off — do NOT run tests

This skill is **write-only**. Test execution is the orchestrator's responsibility, performed via the `cucumber-test-execution` skill in a separate step (typically a separate agent invocation). The e2e-test-agent intentionally has no `Bash` tool — there is no path for this skill to run `mvn test` itself.

What you DO at this step:

- Stop after the code is written and the locator JSON is updated.
- Set `Verification status: NOT VERIFIED — handoff to orchestrator` in the Output report.
- If you suspect a syntactic problem (e.g. you referenced a step regex you weren't sure existed), call it out in the Output report under `Concerns for orchestrator run`. Do NOT attempt to compile or invoke the test runner to confirm.

What you do NOT do:

- Run `mvn test`, `mvn compile`, `javac`, or any test/build command.
- Invoke `cucumber-test-execution` skill from inside this skill (the orchestrator owns that handoff, not you).
- Silently "fix" anything based on assumed test output.

Failure feedback loop: if the orchestrator's run produces failures, it will dispatch a follow-up task to this same agent with the failure log. Handle that as a new invocation of this skill, scoped to the failing scenarios.

## When to consult what

| Situation | Load |
|-----------|------|
| Discovering reusable built-in / project steps | `references/step-discovery.md` |
| Authoring a snippet (composing built-in steps) | `references/snippets.md` |
| Designing or editing a locator JSON entry | `references/locators.md` |
| Need a stable selector for an element you haven't seen | `mcp__playwright__browser_navigate` + `browser_snapshot` (Procedure step 4a) |
| MCP probe returns no `data-testid` for a target element | Record as report finding; pick next-best locator per Hard Rule 7 |
| Network mocking (route.fulfill, route.abort) | `references/waits.md` (§ "Network observation and mocking") |
| Test is flaky / unwanted waits | `references/waits.md` |

## Tooling assumptions

This skill assumes the project's `pom.xml` includes (Cucumber 4.x compatible versions):

- `io.cucumber:cucumber-java` 4.8.x
- `io.cucumber:cucumber-junit` 4.8.x
- `io.cucumber:cucumber-picocontainer` 4.8.x
- `com.microsoft.playwright:playwright` 1.40+
- The internal BDD framework artifact (read `pom.xml` to identify; e.g. `com.<org>.framework:bdd-core-steps`).
- `org.hamcrest:hamcrest` 2.x

If versions differ, surface this in the report — do NOT silently adapt to incompatible versions.

## Failure modes

- **Symptom**: PR review comment "this duplicates an existing step in `com.x.framework.steps.AuthSteps`". → **Cause**: Skipped Discovery phase 2a (built-in step search), or `.bdd-step-index/` was stale/missing and no fallback tier was consulted. → **Fix**: Always Grep `.bdd-step-index/builtin-steps.txt` first; if absent, walk Tiers 2–5 from `references/step-discovery.md § 1`. Record `Discovery source` tier in the report so reviewers can spot a degraded run.
- **Symptom**: Authored a new Java step that just chains `framework.click(...)` + `framework.fill(...)`. → **Cause**: Classified a composition as `NEW_STEP` instead of `NEW_SNIPPET`. → **Fix**: If the body is ≥ 2 calls to OTHER steps, it's a snippet — relocate it to `snippets/` and annotate accordingly.
- **Symptom**: Locator works locally, breaks in CI after a UI text change. → **Cause**: JSON entry used `getByText` when a `data-testid` exists. → **Fix**: Re-probe via MCP; bump up the locator priority. Update the JSON entry; no Java changes needed (this is the whole point of the JSON catalog).
- **Symptom**: Hardcoded selector string slipped into a Java step. → **Cause**: Hard Rule 2 violation. → **Fix**: Move the selector to `src/test/resources/locators/<page>.json` under a meaningful key; replace the inline string with a locator-loader call.
- **Symptom**: Test passes the first time, fails when re-run. → **Cause**: BrowserContext or cookies leaked between scenarios. → **Fix**: Verify the framework's `@Before` actually creates a fresh context (Grep the framework sources JAR). If it doesn't — that's a framework bug, not a test bug; raise upstream.
- **Symptom**: Page Object–style class created under `pages/`. → **Cause**: Misapplied the obsolete POM pattern. → **Fix**: This codebase does NOT use Page Objects. Delete the class; move its behaviors into snippets (composition) and its locators into the JSON catalog.
- **Symptom**: Assertion message is unhelpful (just "expected true got false"). → **Cause**: `assertTrue(locator.isVisible())` evaluated once. → **Fix**: Use `assertThat(locator).isVisible()` from PlaywrightAssertions — auto-retries and gives full diagnostic.

## Output report

When done implementing a feature's step defs:

```
Feature: <path>

Discovery inventory:
  Discovery source: index | catalog | javadoc | user-provided | unavailable
  Built-in step library: <groupId:artifactId:version>
  Index file consulted: <path, or "n/a — used <tier>">
  Built-in steps matched: <count>
    - <step regex>  →  <FQN>
  Project steps matched: <count>
    - <step regex>  →  <FQN>  [snippet|primitive]
  Gherkin lines unverified against built-ins (Tier 5 only): <list or "none">
    - <gherkin line>: <why no tier resolved it>

Mapping:
  REUSE_BUILTIN: <count> lines
  REUSE_PROJECT: <count> lines
  NEW_SNIPPET:   <count> lines — files: <list>
  NEW_STEP:      <count> lines — files: <list>  ← justify each below

New step justifications (if NEW_STEP > 0):
  - <step>: <why no built-in / project step / snippet works>

Locator changes:
  JSON files touched: <list of src/test/resources/locators/*.json>
  Entries added: <count>
  Entries upgraded (priority bumped): <count>
  Locator discovery mode: mcp-probed | fallback-inferred | mixed
  MCP probe target URL(s): <list or "n/a — fallback mode">
  Elements missing data-testid (dev follow-up): <list or "none">

Network mocks used: <list or "none">
Scenarios covered: <count>
Scenarios with TODOs (could not implement): <list with reasons>

Verification status: NOT VERIFIED — handoff to orchestrator
Concerns for orchestrator run: <list, or "none">
  e.g. "referenced built-in step `@When(\"I confirm the modal\")` not found in
        sources JAR — may be in a transitive dep we couldn't grep"
```
