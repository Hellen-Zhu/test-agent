---
name: bdd-feature-authoring
description: This skill should be used when the user asks to "write a feature file", "draft Gherkin scenarios", "add scenarios to feature", "review my .feature file", "check Gherkin style", or when creating/editing any `*.feature` file under `features/`. Provides the team's Gherkin style rules, tag taxonomy, and anti-patterns so feature files compose cleanly with `/parallel-tdd` and downstream Cucumber 4.x step definitions.
---

# BDD Feature Authoring

How to write `.feature` files that are clear, declarative, traceable, and play nicely with the downstream automation (parallel-tdd dispatching, Cucumber 4.x glue resolution, tag-based execution).

## When this applies

Use this skill when:
- About to create a new `.feature` file under `features/api/` or `features/ui/`.
- Editing or extending an existing `.feature` file.
- Reviewing a `.feature` file for style or completeness.
- The test plan exists (from `story-to-test-plan`) and you need to draft the actual Gherkin.

Do NOT use this skill when:
- Deciding WHICH scenarios to write or which layer they go in → that's `story-to-test-plan`.
- Implementing step definitions in Java → that's `cucumber-api-automation` or `cucumber-e2e-automation`.

## Hard Rules

1. ONE `Feature:` per file. NEVER multiple features in one file.
2. EVERY scenario carries at least: `@story-<id>` AND `@<area>` (e.g. `@auth`). No untagged scenarios.
3. EVERY scenario has at least one `When` step followed by at least one `Then` step. `Given`s may live in `Background:`.
4. NEVER use `When` to set up state or `Given` to perform the action under test. `Given` = precondition, `When` = action, `Then` = outcome.
5. NEVER reference implementation details (CSS selectors, SQL, HTTP status codes) UNLESS the scenario explicitly tests that level.
   - API features MAY reference HTTP status codes — that IS the SUT.
   - UI features MUST NOT name CSS classes; use accessible roles or labels.
6. Scenario titles describe OUTCOMES, not actions. `"Wrong password returns 401"` ✅. `"Submit login with wrong password"` ❌.
7. NO scenario depends on side effects from another scenario in the same file. `Background:` sets shared preconditions; if scenarios need different state, do not share.
8. NEVER edit a `.feature` file that the api-test-agent or e2e-test-agent owns AFTER they have generated step defs, without re-running `/parallel-tdd` — step def signatures drift.

## Standards (index)

| # | Standard | Details |
|---|----------|---------|
| S1 | **Declarative over imperative.** Describe what the user wants, not the keystrokes. | `references/gherkin-style.md` |
| S2 | **Scenario Outline when ≥ 3 sibling scenarios** differ only by data. | `references/gherkin-style.md` |
| S3 | **Tag taxonomy**: traceability, area, priority, lifecycle. | `references/tag-conventions.md` |
| S4 | **Data tables for structured input**, doc strings for opaque payloads (JSON), examples for parameterized cases. | `references/gherkin-style.md` |
| S5 | **No "And" chains > 5 deep.** Break the scenario or extract steps into Background. | `references/gherkin-style.md` |

## Core Procedure

For each new feature file:

1. **Place the file.** Use the path from `story-to-test-plan` output. Always under `features/api/<area>/` or `features/ui/<area>/`.
2. **Write the `Feature:` header.**
   - Line 1: `Feature: <Outcome-Oriented Title>` (Title Case, no trailing period).
   - Lines 2–4: 2–3 line free-text description (As X / I want Y / So that Z is fine but optional).
3. **Decide if a `Background:` is needed.** Only if EVERY scenario shares the same setup. Otherwise inline the `Given`s.
4. **Draft scenarios in the order from the plan.** Happy path → named negatives → boundaries → resilience.
5. **For each scenario:**
   - Tags on the line directly above the `Scenario:` keyword.
   - Title: outcome statement, not action.
   - Body: Given (zero or more) → When (one, sometimes two for compound actions) → Then (one) → And/But for additional assertions.
6. **Apply declarative pass.** Re-read each step. Could it be at a higher level of abstraction? "I fill X and click Y" → "I submit the login form with X".
7. **Apply Outline pass.** Any group of ≥ 3 scenarios differ only by data → fold into `Scenario Outline:` + `Examples:` table.
8. **Tag pass.** Verify every scenario has `@story-<id>` and `@<area>`. Add `@smoke` where appropriate.
9. **Anti-pattern scan.** Run through `references/anti-patterns.md` checklist.

## When to consult what

| Situation | Load |
|-----------|------|
| Choosing declarative vs imperative wording | `references/gherkin-style.md` |
| Deciding which tags to add and what they enable downstream | `references/tag-conventions.md` |
| The feature feels noisy or repetitive | `references/anti-patterns.md` |
| Need a starter feature file structure | See "Skeleton" below |

## Skeleton (copy and adapt)

```gherkin
@auth @story-48217
Feature: <Outcome-Oriented Title>
  <2-3 line context, optional>

  Background:
    Given <shared precondition that EVERY scenario needs>

  @smoke
  Scenario: <Happy path outcome>
    When <action>
    Then <observable outcome>
    And <secondary assertion>

  Scenario: <Named negative outcome>
    When <action with bad input>
    Then <observable outcome>

  Scenario Outline: <Parameterized outcome>
    When <action with "<value>">
    Then the response is "<expected>"

    Examples:
      | value          | expected           |
      | wrong-password | invalid_credentials|
      | nobody@x.com   | invalid_credentials|
```

## Failure modes

- **Symptom**: Step def class can't find a step. → **Cause**: Step text changed after generation. → **Fix**: Re-run `/parallel-tdd`, or manually update the Cucumber expression in the step def — never edit the `.feature` file in isolation once step defs exist.
- **Symptom**: Two scenarios pass individually but the second fails when run after the first. → **Cause**: Hidden state dependency (cookies, db rows) carried over from scenario 1. → **Fix**: Either move setup into Background, or ensure step defs reset state per scenario (`@Before` hook).
- **Symptom**: Running with `--tags '@smoke'` excludes scenarios that should run. → **Cause**: `@smoke` tag missing on a scenario. → **Fix**: Tag the scenario. Tags are inherited from `Feature:` line but ALSO from the line above each `Scenario:` — be aware of inheritance rules.
- **Symptom**: Feature reads like a script ("I click X, I click Y, I see Z"). → **Cause**: Imperative style. → **Fix**: Replace concrete actions with intent verbs ("I sign in as ...", "I submit the order"). See `references/gherkin-style.md`.
