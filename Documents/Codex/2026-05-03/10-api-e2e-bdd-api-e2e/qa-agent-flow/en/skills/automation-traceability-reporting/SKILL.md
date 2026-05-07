---
name: automation-traceability-reporting
description: Produce final automation reporting that maps user stories and acceptance criteria to scenarios, generated assets, execution results, blockers, and quality gate status.
---

# Automation Traceability Reporting

Use this skill before final delivery.

## Required Report

```md
# Automation Agent Output

## 1. Route Decision
- Selected route:
- Reason:
- Skills used:

## 2. Scenario Strategy
| Scenario | Layer | Needs Playwright MCP | Reason |
| --- | --- | --- | --- |

## 3. Generated / Updated Assets
| Asset | Action | Notes |
| --- | --- | --- |

## 4. Execution Result
| Command | Result | Notes |
| --- | --- | --- |

## 5. Maven Parallel Execution
| Item | Value |
| --- | --- |
| Strategy | |
| Agent ID | |
| Build output directory | |
| Local Maven repository | |
| Parallel-safe | Yes / No |

## 6. Traceability
| User Story / AC | Scenario | Automation Asset | Status |
| --- | --- | --- | --- |

## 7. Open Questions / Blockers
| Item | Impact | Required Action |
| --- | --- | --- |

## 8. Quality Gate
| Gate | Result | Notes |
| --- | --- | --- |
```

## Quality Gate Items

- Route is justified.
- E2E scope is justified.
- Existing assets were checked first.
- Playwright MCP was used when real UI behavior was needed.
- Locators are stable.
- Step definitions are thin.
- Test data is isolated and cleanable.
- Maven execution is parallel-safe when API and E2E agents run concurrently.
- Tests can run locally and in CI.
- Execution result is reported.
- Traceability is complete.
