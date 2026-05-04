# Engineering Delivery Flow

This document defines a closed-loop engineering flow from requirement intake to
production launch and post-launch closure. It is designed to sit above the
story, solution design, and BDD generation pipelines and to align with Harness-style software
delivery controls: CI, CD/GitOps, feature flags, security gates, observability,
and engineering insights.

## Goals

- Preserve traceability from requirement to code, tests, deployment, and closure.
- Move quality decisions left without turning every check into a manual gate.
- Keep UI/E2E testing focused on high-value journeys and push rule validation
  down to API or lower-level tests.
- Use progressive delivery and rollback plans for production changes.
- Make repeated verification, deployment, rollback, and evidence collection
  executable through reviewed scripts.
- Feed release results and delivery metrics back to the work item.

## Core Principles

| Principle | Meaning |
|-----------|---------|
| Single source of truth | The ADO/Jira work item or local story JSON owns requirement scope. |
| Evidence over assertion | Every gate needs concrete artifacts: tests, logs, pipeline links, screenshots, metrics, or approvals. |
| Risk-based depth | High-risk changes need stronger test, security, rollout, and observability evidence. |
| Progressive launch | Prefer feature flags, canary, ring rollout, or low-blast-radius deployment when available. |
| Closed loop | The story is not done until production verification and work item updates are complete. |

## Inputs

The flow accepts either an ADO work item, a local story JSON file, or an existing
delivery state file.

Minimum requirement fields:

| Field | Required | Notes |
|-------|----------|-------|
| `storyId` | yes | ADO ID or local identifier. |
| `title` | yes | Business-facing title. |
| `description` | yes | User need and intended outcome. |
| `acceptanceCriteria` | yes | Testable ACs; split if compound. |
| `persona` | recommended | Primary actor or consumer. |
| `module` | recommended | Technical module or service scope. |
| `nonFunctionalRequirements` | recommended | Performance, security, reliability, audit, compliance. |
| `dependencies` | recommended | Services, teams, migrations, feature flags, data setup. |
| `releaseTarget` | recommended | Target environment/date/window if known. |
| `riskLevel` | recommended | Low, medium, high, critical. |

## State File

`/eng-flow` keeps resumable state in:

```text
.claude/engineering-flow.local.md
```

The file is intentionally local because it can contain branch names, pipeline
links, environment names, and reviewer decisions. The command must preserve any
existing entries and append or update only the current story section.

Suggested state section:

```markdown
## {storyId} - {title}

- Current stage: requirement-readiness | solution-design | bdd-design | delivery-design | scripts-automation | implementation | ci-gate | env-acceptance | release-readiness | production-launch | post-launch-closure
- Source: {ADO URL or JSON path}
- Branch/PR: {branch or PR URL}
- Feature files: {paths}
- Pipeline runs: {links or IDs}
- Environments: {dev/test/stage/prod}
- Release strategy: {direct | flag | canary | ring | blue-green}
- Last gate decision: {approved | revise | blocked | stopped}
- Open blockers:
  - {blocker}
```

## Flow Stages

| Stage | Purpose | Primary Output | Exit Gate |
|-------|---------|----------------|-----------|
| 1. Requirement readiness | Validate clarity, AC quality, scope, dependencies, and risk. | Requirement Readiness Report. | Product/engineering approval or clear revision list. |
| 2. Solution design | Clarify product behavior, UI, API, data, security, integrations, NFRs, observability, and rollout. | Design-ready Story Contract. | Engineering/QA approval that design is testable and implementable. |
| 3. BDD and test design | Convert approved behavior and design evidence into layered test points and feature files. | API/UI feature files and coverage matrix. | Human approval that coverage and steps are correct. |
| 4. Delivery design | Slice implementation, define verification, rollout execution, and operational readiness. | Delivery Plan. | Engineering approval that plan is executable. |
| 5. Scripts and automation | Discover, validate, or create the scripts needed for gates and evidence. | Script Inventory and Gap Plan. | Required scripts exist or gaps are explicitly accepted. |
| 6. Implementation | Make code/config/test changes. | Code changes, tests, docs, config. | Local verification passes or failures are documented. |
| 7. CI quality gate | Build, unit/integration tests, static checks, security scans. | Pipeline evidence. | Required CI checks pass or approved exception exists. |
| 8. Environment acceptance | Deploy to non-prod and run acceptance/regression checks. | Acceptance evidence. | PO/QA/engineering approval. |
| 9. Release readiness | Confirm change, risk, rollout, rollback, monitoring, and ownership. | Go/No-Go report. | Explicit release approval. |
| 10. Production launch | Deploy or enable feature progressively. | Production deployment record. | Smoke and health checks pass. |
| 11. Post-launch closure | Capture metrics, incidents, verification, and work item updates. | Closure report and updated story. | Story tagged/closed with production evidence. |

## Harness-Style Control Mapping

| Capability | How the flow uses it |
|------------|----------------------|
| CI | Build, unit tests, integration tests, contract tests, static analysis, and artifact creation. |
| CD/GitOps | Controlled deployment to dev, test, stage, and production environments. |
| Feature flags or FME | Dark launch, ring rollout, kill switch, percentage rollout, and instant rollback where supported. |
| Security testing | SAST, SCA, secret scanning, container/image checks, IaC checks, and policy exceptions. |
| Supply chain controls | Artifact provenance, signed images, dependency review, and deployment approvals. |
| Observability/SRM | Service health, SLOs, logs, traces, alerts, and error budget impact. |
| SEI / engineering insights | DORA metrics, lead time by stage, PR cycle time, failure rate, and MTTR feedback. |
| Internal developer portal | Service ownership, runbooks, dependencies, scorecards, and operational readiness. |

## Scripts Layer

The scripts layer is documented in `.claude/docs/engineering-scripts.md`.
It is the executable contract for local verification, CI quality gates,
security scans, non-prod deploy, smoke checks, production launch, rollback, and
evidence capture.

Required behavior:

- Discover existing scripts before proposing new ones.
- Prefer maintained repository commands over one-off wrappers.
- Create or update scripts only when they close a real gate or evidence gap.
- Default scripts to local or non-production behavior.
- Require explicit approval before production deployment or feature flag rollout.
- Treat rollback and smoke scripts as release readiness evidence for high-risk
  changes.

## Gate Evidence Checklist

Requirement readiness:

- User outcome is explicit.
- ACs are testable and individually traceable.
- Dependencies and non-functional requirements are captured.
- Risk level and rollout expectations are known.

Solution design:

- API contracts, UI states, data rules, permissions, and integration behavior are known enough for test design.
- NFR, observability, rollout, and rollback constraints are captured when relevant.
- Open design questions are explicit and have an owner.
- Solution design does not silently expand or change accepted business behavior.

BDD and test design:

- Every AC maps to at least one test point.
- API/UI layer decisions follow `.claude/docs/test-layering-methodology.md`.
- Generated feature files reuse existing step catalog where possible.
- New snippets or Java steps are listed with implementation targets.

Delivery design:

- Implementation slices are small enough to review.
- Data migration, compatibility, and rollback needs are known.
- Required tests are named by layer.
- Observability and alerting impact is clear.

Scripts and automation:

- Existing scripts and CI/CD pipeline steps are inventoried.
- Missing gate scripts are listed with owner, target path, and required behavior.
- Local verification can be run with one clear command or documented equivalent.
- Non-prod deploy, smoke, release readiness, and rollback commands are known.
- Scripts follow `.claude/docs/engineering-scripts.md` safety and evidence rules.

CI quality gate:

- Build passes.
- Unit and integration tests pass.
- Required lint/type/static checks pass.
- Security scans are clean or exceptions are approved.
- Artifact version and commit SHA are recorded.
- The CI command or Harness step maps back to reviewed repository scripts where
  practical.

Environment acceptance:

- Deployment to non-prod succeeded.
- BDD/API/UI acceptance checks ran.
- Known defects are triaged with severity and owner.
- Product/QA acceptance is recorded when required.

Release readiness:

- Production change window and owner are confirmed.
- Rollout plan and rollback plan are explicit.
- Smoke and rollback scripts, or equivalent reviewed runbooks, are ready.
- Feature flag or kill switch is ready if applicable.
- Dashboards and alerts are available before launch.
- Support/runbook notes are updated for user-facing changes.

Post-launch closure:

- Production smoke checks pass.
- Error rate, latency, and key business metrics are within expected bounds.
- Incidents or rollback decisions are documented.
- Work item is updated with files, pipeline/deploy links, release evidence, and metrics.

## Traceability Matrix

Use this table in reports and work item comments.

| AC | Test Point | Test Layer | Feature/Automated Test | Code/PR | Pipeline Evidence | Release Evidence |
|----|------------|------------|-------------------------|---------|-------------------|------------------|
| AC-1 | TP-001 | API | `features/api/...` | PR link | CI run | Deploy/smoke link |

## Release Decision Model

Use these decision values consistently:

| Decision | Meaning |
|----------|---------|
| Go | Evidence is complete; launch can proceed. |
| Conditional Go | Launch can proceed only with listed mitigations or approvals. |
| No-Go | Blocker prevents launch. |
| Stop | User explicitly ends the flow. |

Common No-Go conditions:

- Untested or unclear acceptance criteria for critical user behavior.
- Failing required CI or security gate without approved exception.
- No rollback strategy for a high-risk production change.
- Missing smoke or rollback automation for a high-risk release without an
  approved manual runbook.
- Missing owner for production monitoring.
- Production-impacting dependency is not ready.

## Post-Launch Metrics

Capture these when available:

| Metric | Source |
|--------|--------|
| Lead time for change | Work item created/ready date to production time. |
| Deployment frequency | Deployment records. |
| Change failure rate | Incidents, rollback, hotfixes, failed releases. |
| MTTR | Incident open/resolve timestamps. |
| PR cycle time | Version control platform. |
| Review latency | Version control platform. |
| Escaped defects | Bug tracker or incident system. |

## Work Item Closure Comment

Use this structure for ADO/Jira closure comments:

```markdown
Engineering delivery closed loop complete.

Requirement:
- Story: {storyId} - {title}
- Scope: {summary}

Artifacts:
- PR: {link}
- Feature files/tests: {paths or links}
- CI: {pipeline link}
- Deployment: {deployment link}

Release:
- Strategy: {direct | flag | canary | ring | blue-green}
- Production time: {timestamp}
- Rollback plan: {summary}
- Smoke result: {pass/fail}

Coverage:
{traceability matrix}

Post-launch:
- Health: {summary}
- Incidents: {none or links}
- Metrics: {lead time, deploy frequency contribution, failure/MTTR notes}
```
