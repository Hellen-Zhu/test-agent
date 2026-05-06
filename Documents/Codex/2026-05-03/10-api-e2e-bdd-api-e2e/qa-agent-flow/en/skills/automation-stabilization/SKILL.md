---
name: automation-stabilization
description: Run, debug, and stabilize BDD or Playwright automation by improving waits, locators, test data isolation, failure artifacts, and flaky-risk handling.
---

# Automation Stabilization

Use this skill after tests are implemented or generated.

## Flow

```text
Run targeted test
  ↓
Inspect failure
  ↓
Fix selector / wait / data / assertion issue
  ↓
Re-run targeted test
  ↓
Run related suite or tag
  ↓
Return stabilization result
```

## Rules

- No hard waits.
- Use web-first assertions.
- Prefer stable locators.
- Keep test data isolated, repeatable, cleanable, and parallel-safe.
- Do not depend on execution order.
- Capture screenshots, traces, videos, logs, and API details on failure.
- Do not hide product bugs with retries.
- Document flaky risks.

## Output

```md
## Stabilization Result

| Command | Result | Notes |
| --- | --- | --- |

| Issue | Fix | Residual Risk |
| --- | --- | --- |
```

