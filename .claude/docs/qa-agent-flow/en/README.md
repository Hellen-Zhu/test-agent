# QA Agent Flow: API + E2E BDD Automation

This English version defines a practical multi-agent workflow that simulates how a senior QA engineer moves from requirements to maintainable API + E2E BDD automation.

## Agents

0. [Flow Orchestrator](./00-flow-orchestrator.md)
   - Coordinates the full workflow, handoffs, gates, and rework rules.

1. [Requirement Agent](./01-requirement-agent.md)
   - Turns raw requirements into a testable business model.

2. [Test Strategy Agent](./02-test-strategy-agent.md)
   - Defines risk-based layered testing strategy.

3. [BDD + Case Design Agent](./03-bdd-case-design-agent.md)
   - Converts acceptance criteria and test strategy into Gherkin scenarios and test case matrices.

4. [Automation + Review Agent](./04-automation-review-agent.md)
   - Designs Java + Cucumber API + E2E hybrid automation and performs quality review.

## Commands

If your tool supports slash commands, use the command templates in [commands](./commands/README.md):

- `/qa-flow`
- `/qa-requirement`
- `/qa-strategy`
- `/qa-bdd`
- `/qa-automation-review`

## Recommended Flow

```text
Requirement / PRD / User Story / API Spec / UI Prototype
  ↓
Requirement Agent
  Output: business rules, acceptance criteria, boundaries, exceptions, open questions
  ↓
Test Strategy Agent
  Output: risk matrix, layered strategy, automation scope, execution priority
  ↓
BDD + Case Design Agent
  Output: feature files, scenarios, examples, test case matrix, tags
  ↓
Automation + Review Agent
  Output: framework design, code mapping, test data strategy, review checklist, quality gates
```

## How To Use

For each agent:

1. Open the related Markdown file.
2. Copy the section named `Direct-Use Agent Prompt`.
3. Paste it into your agent platform as the agent instruction, system prompt, or role prompt.
4. Use the full Markdown file as the detailed working standard.

If your platform does not support independent agents, use the command templates instead. Each command contains the agent prompt plus a `{{user_input}}` placeholder.

## Shared Principles

- Do not invent requirements. Mark all inferred content as `Assumption`.
- Put unclear items into `Open Questions`.
- Do not start automation design before requirements are testable.
- Prefer API-level validation for stable business rules.
- Keep E2E scenarios for critical user journeys and true integration risks.
- Use business language in Gherkin.
- Keep step definitions thin.
- Put reusable business behavior into domain actions.
- Keep API clients, page objects, assertions, and data setup responsibilities separate.
- Make test data repeatable, isolated, parallel-safe, and cleanable.
