---
name: bdd-feature-implementation
description: Implement existing Gherkin feature files as executable automation by mapping scenarios to step definitions, page objects, API clients, fixtures, and assertions.
---

# BDD Feature Implementation

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

