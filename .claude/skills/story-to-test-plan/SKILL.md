---
name: story-to-test-plan
description: This skill should be used when the user asks to "plan tests for this story", "decompose acceptance criteria into scenarios", "decide what to test where", "design test cases for user story X", or is starting work on a new ADO/Jira user story before writing any .feature files. Produces a test plan that maps each acceptance criterion to BDD scenarios assigned to the correct layer (API vs UI), ready for `/parallel-tdd` to consume.
---

# Story to Test Plan

Turn a user story (ADO / Jira / written spec) into a layered BDD test plan: a set of `.feature` files under `features/api/` and `features/ui/`, each scenario tagged for traceability, and the file paths recorded back to the story's `Custom.BddFeatureFiles` field so `/parallel-tdd` can dispatch agents.

## When this applies

Use this skill when:
- A new user story arrives and no `.feature` files exist for it yet.
- An existing story's acceptance criteria changed and feature coverage needs review.
- A planning conversation explicitly asks "what should we test, and at which layer?"

Do NOT use this skill when:
- The feature files already exist and you only need to write step definitions → use `cucumber-api-automation` or `cucumber-e2e-automation`.
- The Gherkin style itself needs review → use `bdd-feature-authoring`.
- Running existing tests → use `cucumber-test-execution`.

## Hard Rules

1. EVERY acceptance criterion must map to ≥ 1 scenario. List uncovered ACs explicitly; do not silently drop them.
2. EVERY scenario is assigned to exactly ONE layer. If a behaviour appears at both layers (e.g. "API returns 401 AND UI shows error"), split into TWO scenarios in TWO files.
3. EVERY scenario carries a `@story-<id>` tag for traceability back to the source story.
4. Server-side behaviour (status codes, persistence, locking, JWT claims, schema, timing) → `features/api/`.
5. Browser-observable behaviour (DOM, focus, URL, form validation, visual state) → `features/ui/`.
6. NEVER write a scenario that depends on another scenario's side effects. Each scenario sets up its own state via Background or Given.
7. NO scenario lives outside `features/api/` or `features/ui/` — `/parallel-tdd` Phase 2 will reject paths that match neither.
8. Report the final `bddFeatureFiles` array (JSON-encoded string) so the user can paste it into the ADO story's `Custom.BddFeatureFiles` field.

## Standards (index)

| # | Standard | Details |
|---|----------|---------|
| S1 | Test pyramid: prefer API > E2E. Test each behaviour at the lowest layer that can observe it. | `references/layering.md` |
| S2 | Coverage discipline: happy path + each named negative + boundary + at least one resilience case (timeout / lockout / etc.). | `references/ac-to-scenarios.md` |
| S3 | Scenario granularity: one observable outcome per scenario. Split when "And" clauses in the `Then` exceed 2. | `references/ac-to-scenarios.md` |
| S4 | Tag taxonomy: `@story-<id>`, `@<area>`, optional `@smoke` / `@regression` / `@wip`. | See `bdd-feature-authoring/references/tag-conventions.md` |

## Core Procedure

1. **Read the story.** Extract: `id`, `Title`, `Description`, `Acceptance Criteria` (HTML — strip to plain text or numbered list).
2. **Enumerate ACs.** List as `AC1, AC2, ...`. If the AC text is one long paragraph, split into atomic claims first.
3. **Classify each AC.** For each AC apply the decision tree in `references/layering.md`:
   - Server-observable rule → api
   - Browser-observable behaviour → ui
   - Mixed → split into two AC fragments, route separately
4. **Group by area + layer.** Cluster ACs into feature files at `features/<layer>/<area>/<name>.feature`. One file per coherent feature, not per AC.
5. **Derive scenarios per AC.** Use the patterns in `references/ac-to-scenarios.md`:
   - Happy path → 1 scenario
   - Each named failure mode → 1 scenario
   - Boundary / negative inputs → 1 scenario each
   - Resilience (lockout, retry, timeout) → 1 scenario each
6. **Tag every scenario.** Minimum: `@story-<id> @<area>`. Add `@smoke` if it's part of the smoke set.
7. **Verify completeness.** Walk the AC list one more time — anything unmapped is a hole, surface it.
8. **Emit `bddFeatureFiles` JSON.** Format:
   ```json
   ["features/api/<area>/<a>.feature","features/ui/<area>/<b>.feature"]
   ```
   This is the exact shape `Custom.BddFeatureFiles` expects (see `fixtures/ado-user-story-sample.json`).

## When to consult what

| Situation | Load |
|-----------|------|
| Deciding whether an AC is API or UI | `references/layering.md` |
| Translating an AC sentence into Gherkin scenario(s) | `references/ac-to-scenarios.md` |
| Choosing tags or naming the feature | sibling skill `bdd-feature-authoring` |
| About to write the .feature files themselves | hand off to `bdd-feature-authoring` |

## Failure modes

- **Symptom**: An AC appears in both `features/api/*` and `features/ui/*` testing the same thing. → **Cause**: Layer split not performed. → **Fix**: Decide which layer is canonical for the rule (usually API); the other layer asserts only its observable consequence.
- **Symptom**: `/parallel-tdd` Phase 2 rejects a path. → **Cause**: File created at `features/<area>/...` without `api` or `ui` segment. → **Fix**: Move under `features/api/<area>/` or `features/ui/<area>/`.
- **Symptom**: AC mentions timing ("within 2 seconds") but no scenario asserts it. → **Cause**: Performance assertion missed during decomposition. → **Fix**: Add an explicit timing scenario at the API layer (response-time) AND/OR a UI layer scenario observing the navigation latency.
- **Symptom**: Story has 8 ACs but only 4 scenarios produced. → **Cause**: ACs collapsed into compound scenarios. → **Fix**: Per S3 split — one outcome per scenario.

## Output template

When the plan is ready, emit this report:

```
Story: <id> — <title>

ACs covered:
  AC1 → features/api/<area>/<file>.feature [Scenario: ...]
  AC2 → features/ui/<area>/<file>.feature [Scenario: ...]
  ...

ACs uncovered: <list or "none">

bddFeatureFiles:
[
  "features/api/<area>/...",
  "features/ui/<area>/..."
]

Next: hand off to bdd-feature-authoring to draft the .feature files.
```
