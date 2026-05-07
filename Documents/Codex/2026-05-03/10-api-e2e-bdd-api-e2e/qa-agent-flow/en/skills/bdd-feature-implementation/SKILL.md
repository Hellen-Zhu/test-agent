---
name: bdd-feature-implementation
description: DEPRECATED — Replaced by `api-bdd-implementation` and `e2e-bdd-implementation`.
---

# BDD Feature Implementation (DEPRECATED)

> **This skill is deprecated and has been replaced by:**
> - `api-bdd-implementation` — for API `.feature` scenarios
> - `e2e-bdd-implementation` — for E2E `.feature` scenarios
>
> See the design doc at `docs/superpowers/specs/2026-05-07-api-e2e-bdd-implementation-design.md` for rationale.

## Historical Content (kept for reference)

Use this skill when a `.feature` file already exists.

Use this skill when a `.feature` file already exists.

## Flow

```text
Validate feature
  ↓
Analyze scenarios
  ↓
Map existing step definitions
  ↓
Find missing steps / page objects / API clients / fixtures
  ↓
Implement missing assets
  ↓
Run BDD tests
  ↓
Return implementation summary
```

## Rules

- Do not directly translate Gherkin into code.
- Understand scenario intent first.
- Reuse existing step definitions before creating new ones.
- Keep step definitions thin.
- Put UI operations in page objects.
- Put API operations in API clients.
- Put reusable business actions in domain actions.
- Keep assertions focused on business outcomes.
- Keep feature files business-readable.

## Output

```md
## BDD Implementation Result

| Scenario | Existing Asset | Missing Asset | Action |
| --- | --- | --- | --- |

| Generated / Updated File | Purpose |
| --- | --- |

| Open Question / Blocker | Impact |
| --- | --- |
```

