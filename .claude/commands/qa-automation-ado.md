---
description: Load an ADO user story, implement automation from BDD feature data, review, then update ADO E2E test information
---

# ADO Automation Pipeline

You are the Automation Router Agent.

Read and follow:

- `Documents/Codex/2026-05-03/10-api-e2e-bdd-api-e2e/qa-agent-flow/en/04-automation-agent.md`
- `Documents/Codex/2026-05-03/10-api-e2e-bdd-api-e2e/qa-agent-flow/en/04-api-automation-agent.md`
- `Documents/Codex/2026-05-03/10-api-e2e-bdd-api-e2e/qa-agent-flow/en/05-e2e-automation-agent.md`
- `Documents/Codex/2026-05-03/10-api-e2e-bdd-api-e2e/qa-agent-flow/en/skills/bdd-feature-implementation/SKILL.md`
- `Documents/Codex/2026-05-03/10-api-e2e-bdd-api-e2e/qa-agent-flow/en/skills/playwright-mcp-e2e-generation/SKILL.md`
- `Documents/Codex/2026-05-03/10-api-e2e-bdd-api-e2e/qa-agent-flow/en/skills/maven-parallel-execution/SKILL.md`
- `Documents/Codex/2026-05-03/10-api-e2e-bdd-api-e2e/qa-agent-flow/en/skills/automation-stabilization/SKILL.md`
- `Documents/Codex/2026-05-03/10-api-e2e-bdd-api-e2e/qa-agent-flow/en/skills/automation-traceability-reporting/SKILL.md`

**Input:** `$ARGUMENTS`

---

## Required Flow

### 1. Load User Story From ADO

Use ADO MCP to fetch the work item from `$ARGUMENTS`.

Accept:

- ADO work item ID
- `ado:{id}`
- ADO work item URL

Load:

- title
- description
- acceptance criteria
- tags
- comments
- attachments
- linked test cases
- linked tasks

Extract BDD and E2E information:

- feature file content or feature file path
- scenarios and tags
- E2E validation points
- app URL or environment notes
- test data requirements

If ADO MCP is unavailable, the work item cannot be loaded, or no feature information exists, stop and report the blocker. Do not invent feature content.

### 2. Select Automation Route

Use the Automation Router Agent route rules:

| Condition | Route |
| --- | --- |
| API feature path exists | API Automation Agent |
| E2E feature path exists | E2E Automation Agent |
| API and E2E feature paths both exist | API Automation Agent and E2E Automation Agent in parallel |
| Single feature has both `@api` and `@e2e` scenarios | Split by tag and call both agents |
| Requirement is unclear | Stop and ask questions |

### 3. Implement Or Generate Automation

Use the required agents and skills:

- `api-automation-agent` for API feature paths or `@api` scenarios.
- `e2e-automation-agent` for E2E feature paths, `@e2e`, or `@ui` scenarios.
- `maven-parallel-execution` before running Maven when API and E2E agents may run in parallel.
- `automation-stabilization` after implementation.
- `automation-traceability-reporting` before review.

Rules:

- Reuse existing steps, page objects, API clients, fixtures, hooks, and assertions first.
- Implement only missing assets.
- Keep step definitions thin.
- Use stable Playwright locators when UI automation is needed.
- Do not let API and E2E agents share the same Maven `target/` directory in parallel.
- Prefer isolated git worktrees; otherwise use isolated Maven build directories such as `target-api-agent` and `target-e2e-agent`.
- Never run `mvn clean` in a shared workspace while another agent may be running Maven.
- Run the most focused test command first.

### 4. Human Review Gate

Stop after generating the review package.

Do not update ADO until the user explicitly approves.

### 5. Update ADO After Approval

After explicit approval, use ADO MCP to update the work item with:

- automation status
- generated or updated test assets
- E2E test cases
- execution result
- traceability
- blockers or flaky risks

If supported, link or update related ADO test cases/tasks.

If the update fails, report the failure and do not claim success.

---

## Output Before Approval

```md
# ADO Automation Review Package

## 1. ADO User Story
| Field | Value |
| --- | --- |
| Work item | |
| Title | |
| State | |
| Tags | |

## 2. Extracted BDD / E2E Information
| Item | Value |
| --- | --- |
| Feature file | |
| App URL | |
| Scenarios | |
| E2E validation points | |
| Test data needs | |

## 3. Route Decision
| Item | Value |
| --- | --- |
| Selected route | |
| Agents / skills used | |
| Reason | |

## 4. Generated / Updated Assets
| File | Action | Purpose |
| --- | --- | --- |

## 5. Execution Result
| Command | Result | Notes |
| --- | --- | --- |

## 5.1 Maven Parallel Execution
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

## 7. Review Checklist
| Check | Result | Notes |
| --- | --- | --- |
| Feature file was loaded from ADO | Pass / Fail | |
| Correct route was selected | Pass / Fail | |
| Existing assets were checked first | Pass / Fail | |
| E2E scope is justified | Pass / Fail | |
| Maven execution is parallel-safe | Pass / Fail / N/A | |
| Tests were run | Pass / Fail | |
| Traceability is complete | Pass / Fail | |
| Ready to update ADO | Yes / No | |

## 8. Open Questions / Blockers
| Item | Impact | Required Action |
| --- | --- | --- |
```

## Output After ADO Update

```md
# ADO Update Result

| Item | Result | Notes |
| --- | --- | --- |
| Work item updated | Yes / No | |
| E2E test info updated | Yes / No | |
| Test cases linked / updated | Yes / No / Not supported | |
| Final status | |
```
