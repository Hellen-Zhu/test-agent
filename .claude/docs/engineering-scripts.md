# Engineering Scripts And Automation

This document defines the scripts layer for `/eng-flow`. Scripts are the
repeatable automation contract between local development, CI, CD, release, and
post-launch evidence collection.

## Purpose

- Make quality gates executable instead of purely checklist-based.
- Keep local verification aligned with CI behavior.
- Provide deterministic deployment, smoke, rollback, and evidence commands.
- Reduce manual release risk by turning operational steps into reviewed scripts.
- Preserve audit evidence for the requirement-to-production traceability chain.

## Script Discovery Order

When `/eng-flow` enters scripts, implementation, CI, acceptance, release, or
launch stages, discover automation in this order:

1. Repository guidance: `README*`, `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING*`.
2. Package/build scripts: `package.json`, `Makefile`, `justfile`, `Taskfile*`,
   `pom.xml`, `build.gradle`, `gradlew`, `pyproject.toml`, `tox.ini`, `noxfile.py`.
3. Project scripts: `scripts/`, `bin/`, `tools/`, `dev/`.
4. CI/CD config: `.github/workflows/`, `.gitlab-ci.yml`, `.harness/`,
   `harness/`, `.azure-pipelines/`, `azure-pipelines.yml`, `Jenkinsfile`.
5. Test framework config: Cucumber, Playwright, Cypress, JUnit, pytest,
   Gradle/Maven test tasks, report generation config.
6. Deployment config: Helm charts, Kustomize, Terraform, Docker Compose,
   Kubernetes manifests, environment overlays.

Do not create new scripts if an equivalent maintained script already exists.
Prefer wrapping existing project commands only when the wrapper adds clear gate
semantics, evidence capture, or environment safety.

This repository includes a helper for the discovery step:

```bash
scripts/engineering-flow/discover-automation.sh .
```

The helper emits a markdown Script Inventory that `/eng-flow` can use as the
starting point for the scripts and automation gate.

## Script Categories

| Category | Purpose | Typical Name |
|----------|---------|--------------|
| Local verification | Fast developer confidence before PR. | `scripts/verify-local.sh` |
| Test execution | Layer-specific unit/API/UI/BDD test runs. | `scripts/run-tests.sh`, `scripts/run-bdd.sh` |
| CI quality gate | Same checks required by CI in one command. | `scripts/ci-quality-gate.sh` |
| Security gate | SAST/SCA/secrets/container/IaC checks. | `scripts/security-gate.sh` |
| Artifact build | Build and package versioned artifacts. | `scripts/build-artifact.sh` |
| Non-prod deploy | Deploy to dev/test/stage only. | `scripts/deploy-env.sh` |
| Smoke verification | Environment smoke checks after deploy. | `scripts/smoke.sh` |
| Release readiness | Validate evidence before production. | `scripts/release-readiness.sh` |
| Production launch | Trigger approved prod deployment or flag rollout. | `scripts/prod-launch.sh` |
| Rollback | Revert deployment or disable feature flag. | `scripts/rollback.sh` |
| Evidence capture | Collect pipeline/deploy/test/metric links. | `scripts/capture-evidence.sh` |

## Script Contract

Every gate script should follow this contract unless the repository already has
a stronger convention:

| Requirement | Rule |
|-------------|------|
| Exit code | `0` means pass; non-zero means blocked or failed. |
| Arguments | Use explicit flags such as `--env stage`, `--tag @smoke`, `--sha abc123`. |
| Environment safety | Default to local or non-prod. Production actions require explicit flags and approval. |
| Secrets | Never print secrets, tokens, headers, cookies, or connection strings. |
| Logging | Print concise stage markers and write detailed logs/reports to a known path. |
| Idempotency | Re-running should be safe or should fail before making duplicate changes. |
| Evidence | Emit report paths, pipeline URLs, deployment IDs, or metric links. |
| Portability | Avoid machine-specific absolute paths. |
| Dependency checks | Fail early with clear missing dependency messages. |
| Dry run | Deployment, release, and rollback scripts should support `--dry-run` when feasible. |

## Harness Alignment

Harness-style delivery should map scripts to pipeline steps instead of hiding
logic inside ad hoc UI configuration.

| Harness Area | Script Role |
|--------------|-------------|
| CI stage | Run build/test/security scripts and upload reports. |
| CD stage | Call deploy scripts or GitOps sync commands for target environment. |
| Feature flags/FME | Toggle, target, canary, or rollback via reviewed scripts or approved pipeline steps. |
| STO/security | Standardize scan invocation and exception evidence. |
| SRM/observability | Query or link health checks during rollout and post-launch verification. |
| SEI | Feed lead time, deployment, incident, and PR-cycle evidence into closure. |

## Minimum Script Set By Risk

| Risk Level | Minimum Automation |
|------------|--------------------|
| Low | Local verification, CI quality gate, non-prod smoke. |
| Medium | Low + BDD/API acceptance, release readiness, rollback notes. |
| High | Medium + security gate, staged deploy, production smoke, rollback script or approved rollback runbook. |
| Critical | High + dry-run, canary/ring support, monitoring checks, evidence capture, named launch owner. |

## Script Inventory Template

Use this table in Delivery Design and Release Readiness reports.

| Gate | Existing Script/Command | Status | Gap | Action |
|------|-------------------------|--------|-----|--------|
| Local verification | `...` | ready/missing/needs update | | |
| CI quality gate | `...` | ready/missing/needs update | | |
| BDD/API/UI acceptance | `...` | ready/missing/needs update | | |
| Non-prod deploy | `...` | ready/missing/needs update | | |
| Smoke | `...` | ready/missing/needs update | | |
| Release readiness | `...` | ready/missing/needs update | | |
| Production launch | `...` | ready/missing/needs update | | |
| Rollback | `...` | ready/missing/needs update | | |
| Evidence capture | `...` | ready/missing/needs update | | |

## Recommended Shell Template

Use this style when the flow must create a new repository script:

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: script-name.sh [--env dev|test|stage|prod] [--dry-run]
USAGE
}

main() {
  # Parse arguments explicitly.
  # Check dependencies before doing work.
  # Print evidence paths/links at the end.
  :
}

main "$@"
```

## No-Go Script Conditions

- Production deploy or flag rollout has no reviewed rollback path.
- Required CI or security script is missing and no equivalent pipeline evidence exists.
- Smoke test exists only as manual steps for a high-risk change.
- Script prints secrets or requires local machine-specific paths.
- Deployment script defaults to production without explicit environment selection.
