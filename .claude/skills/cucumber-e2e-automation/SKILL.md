---
name: cucumber-e2e-automation
description: This skill should be used when the user asks to "write E2E step definitions", "implement Java Cucumber UI tests", "add Playwright Java steps", "generate E2E tests from a feature file", or when creating/editing any Java file under `src/test/java/.../stepdefs/e2e/` or matching a `features/ui/**/*.feature`. Provides Java + Cucumber 4.x + Playwright Java implementation conventions: Page Object pattern, locator priority, auto-waiting discipline, browser-context-per-scenario isolation, and failure-screenshot capture.
---

# Cucumber E2E Automation

How to implement step definitions for `features/ui/**/*.feature` files using Java + Cucumber 4.x + Playwright Java. Covers package layout, Page Objects, locator strategy, wait discipline, and per-scenario browser isolation.

## When this applies

Use this skill when:
- A `features/ui/**/*.feature` file exists and the matching step defs are missing or out of date.
- Editing Java files under `src/test/java/**/stepdefs/e2e/**` or `pages/**`.
- The user asks "write the UI test for this feature".
- A new page or user-facing flow needs coverage.

Do NOT use this skill when:
- The feature file itself needs writing → `bdd-feature-authoring`.
- Working on `features/api/**` step defs → `cucumber-api-automation`.
- Running or filtering tests → `cucumber-test-execution`.

## Hard Rules

1. Package layout MUST be `com.<org>.tests.e2e.stepdefs.<area>` for step defs, `com.<org>.tests.e2e.pages.<area>` for Page Objects, `com.<org>.tests.e2e.support` for shared infra.
2. ONE step def class per feature file. ONE Page Object class per logical page.
3. NEVER use `Thread.sleep` or any time-based wait. Use Playwright's auto-waiting via `Locator.waitFor()`, `Page.waitForURL()`, `Page.waitForResponse()`, or `Page.waitForFunction()`.
4. NEVER assert in Page Object methods. Page Objects expose state-returning methods (`isVisible`, `currentText`, `count`); step defs ASSERT.
5. NEVER use raw `Page.locator("css string")` in step defs. Step defs call Page Object methods; locators live ONLY inside Page Objects.
6. EVERY scenario gets a FRESH `BrowserContext`. Sharing contexts across scenarios is forbidden — even a "this is faster" optimization. Reuse the `Browser`, not the `Context`.
7. EVERY scenario MUST capture a screenshot on failure via the `@After(order=0)` hook. Trace recording (`context.tracing().start(...)`) on for CI runs, off for local.
8. Locator priority is STRICT: `getByTestId` > `getByRole` > `getByLabel` > `getByText` > `getByPlaceholder` > CSS > XPath. Going DOWN the list requires justification (comment + issue link).

## Standards (index)

| # | Standard | Details |
|---|----------|---------|
| S1 | **Page Object methods return either `this` (chaining) or another Page Object (navigation), or a state value.** Never `void` (kills composition). | `references/pom.md` |
| S2 | **Page Objects are stateless about test data**; they hold `Page` reference + locators only. | `references/pom.md` |
| S3 | **Mock network only when the scenario is isolated UI behavior.** Integrated flows hit a real test backend. | `references/waits.md` |
| S4 | **Locator definitions go in fields**, not inline in methods, so they're discoverable. | `references/pom.md` |
| S5 | **Use `expect(locator)` from `com.microsoft.playwright.assertions.PlaywrightAssertions`** for retrying assertions; use Hamcrest only for non-retrying logical checks. | `references/waits.md` |

## Core Procedure

For each `.feature` file you implement:

1. **Read the feature.** Identify pages involved, user flows, expected outcomes.
2. **Inventory Page Objects.** For each page mentioned, check `pages/<area>/`. Create or extend Page Objects FIRST, before step defs.
3. **Place the step def class.** Path: `src/test/java/com/<org>/tests/e2e/stepdefs/<area>/<Feature>StepDefs.java`. Use the template at `assets/template-stepdefs/E2eStepDefs.java`.
4. **Wire dependencies.** Inject `ScenarioContext` (holds `Page`, `BrowserContext`, fixtures) and the Page Objects you need. Cucumber 4.x picocontainer creates fresh instances per scenario.
5. **Map each Gherkin step to `@Given/@When/@Then`.**
   - `Given I am on the "/login" page` → ctx navigates + returns LoginPage POM
   - `When I sign in as "..."` → call POM method that drives the form
   - `Then I see "..."` → call POM state method + `assertThat`
6. **Auto-wait, never sleep.** Every action returns AFTER the page is ready (Playwright handles this for stable selectors).
7. **Wire up `@Before` and `@After` lifecycle.** Before: create browser context, optionally start tracing. After (order=0): screenshot on failure, stop tracing, close context.
8. **Verify**: run just the matching scenario with `mvn test -Dcucumber.options="--tags '@story-<id>'"` (full execution patterns in `cucumber-test-execution`).

## When to consult what

| Situation | Load |
|-----------|------|
| Designing a new Page Object or refactoring an existing one | `references/pom.md` |
| Choosing a locator | `references/locators.md` |
| Test is flaky or has unwanted waits | `references/waits.md` |
| Starting a brand-new step def class | `assets/template-stepdefs/E2eStepDefs.java` |
| Network mocking (route.fulfill, route.abort) | `references/waits.md` (§ "Network observation and mocking") |

## Tooling assumptions

This skill assumes the project's `pom.xml` includes (Cucumber 4.x compatible versions):

- `io.cucumber:cucumber-java` 4.8.x
- `io.cucumber:cucumber-junit` 4.8.x
- `io.cucumber:cucumber-picocontainer` 4.8.x
- `com.microsoft.playwright:playwright` 1.40+
- `org.hamcrest:hamcrest` 2.x

If versions differ, surface this in the report — do NOT silently adapt to incompatible versions.

## Failure modes

- **Symptom**: Test passes locally but fails in CI with "Locator not found". → **Cause**: Race condition or different viewport. → **Fix**: Replace immediate `.click()` with `.waitFor(WaitForOptions(VISIBLE))` then `.click()`. Or check the locator priority — falling back to CSS often picks up CI-only differences.
- **Symptom**: Test passes the first time, fails when re-run. → **Cause**: BrowserContext or cookies leaked between scenarios (violates Hard Rule 6). → **Fix**: Verify `@Before` creates a NEW context; `@After` calls `context.close()`.
- **Symptom**: `Page.evaluate(...)` returns stale data. → **Cause**: JS executed before page hydration. → **Fix**: Use `page.waitForFunction(...)` or `expect(locator).toBeVisible()` on a sentinel element before reading.
- **Symptom**: Assertion message is unhelpful (just "expected true got false"). → **Cause**: `assertTrue(locator.isVisible())` evaluated once. → **Fix**: Use `assertThat(locator).isVisible()` from PlaywrightAssertions — auto-retries and gives full diagnostic.
- **Symptom**: Screenshots not produced on failure. → **Cause**: `@After` order — cleanup hooks run in REVERSE order; the screenshot hook must be `@After(order=0)` so it runs FIRST (before `context.close()`).
- **Symptom**: Test asserts inline error appears but flake: "sometimes empty, sometimes 'Invalid email'". → **Cause**: Asserting too soon after blur. → **Fix**: `expect(emailError).hasText("Invalid email")` — built-in retry covers eventual consistency.

## Output report

When done implementing a feature's step defs:

```
Feature: <path>
Step def class: <path to .java>
Page Object(s) used or added: <list>
Locators added (with priority used): <list>
Network mocks used: <list or "none">
Screenshots configured: yes (per @After order=0)
Tracing configured: yes (CI only) / no
Scenarios covered: <count>
Scenarios with TODOs (could not implement): <list with reasons>
```
