# Tag Conventions

Tags drive THREE things: traceability, execution scoping, and lifecycle. A well-tagged suite lets you answer "which tests cover story 48217?", "what runs on a PR?", "what's currently broken?" — without reading any code.

## Required tags on every scenario

| Tag | Purpose | Example |
|-----|---------|---------|
| `@story-<id>` | Trace back to source ADO/Jira story | `@story-48217` |
| `@<area>` | Functional area grouping | `@auth`, `@billing`, `@search` |

These two are MANDATORY (Hard Rule 2 in SKILL.md). Without them, the scenario is invisible to anything except a full-suite run.

## Optional priority tags

Apply at most one of these per scenario:

| Tag | Meaning | Where it runs |
|-----|---------|---------------|
| `@smoke` | Critical path — must pass before any merge | Pre-commit, PR check, every CI run |
| `@regression` | Standard regression suite | Nightly + release-candidate CI |
| `@perf` | Has timing assertions | Dedicated perf job, NOT on PR (flaky) |
| `@security` | Tests an auth, authz, or data-leak rule | Both regression and security audit suite |

Default (no priority tag) = regression-eligible but not smoke. Most scenarios fall here.

## Lifecycle tags

| Tag | Meaning | Effect |
|-----|---------|--------|
| `@wip` | Work in progress; not yet stable | Excluded from CI (`not @wip` in execution) |
| `@flaky` | Known intermittent failure; under investigation | Excluded from PR check; runs on nightly with retry |
| `@manual` | Cannot be automated currently; documents the case | NEVER executed |
| `@blocked-<reason>` | Blocked on external work | Excluded until tag removed |

Lifecycle tags MUST be temporary. Add an issue link in a comment above the scenario:

```gherkin
# Flaky on macOS only — investigating in #issue-1234
@flaky @story-48217 @auth
Scenario: ...
```

## Tag inheritance

Cucumber 4.x propagates tags from the Feature line to every Scenario in the file:

```gherkin
@auth @story-48217
Feature: Sign-in API authenticates valid credentials

  @smoke
  Scenario: Successful login returns a signed JWT
    # ← This scenario effectively has @auth @story-48217 @smoke
```

This means you can put `@story-<id>` and `@<area>` ONCE on the `Feature:` line. Per-scenario tags add priority/lifecycle.

**Pitfall**: when SCANNING for coverage, remember Feature-level tags. `grep '@auth'` will miss scenarios that inherit `@auth` from their Feature header. Use `grep -B 20 '^  Scenario:'` or a real Gherkin parser to count properly.

## Execution patterns these tags enable

| Goal | Tag expression (Cucumber 4.x) |
|------|-------------------------------|
| PR check — fast critical | `'@smoke and not @wip and not @flaky'` |
| Nightly regression | `'@regression or @smoke and not @wip'` |
| Security audit | `'@security'` |
| Performance suite | `'@perf'` |
| Coverage for story 48217 | `'@story-48217'` |
| Everything for the auth area | `'@auth and not @wip'` |
| Re-run just the flakes overnight | `'@flaky'` |

Pass via Maven:

```bash
mvn test -Dcucumber.options="--tags '@smoke and not @wip'"
```

See `cucumber-test-execution` skill for full Maven invocation patterns.

## Discouraged tag patterns

- `@high`, `@low`, `@medium` — too vague; map to `@smoke` / `@regression` / no tag.
- `@<person-name>` — ownership belongs in code review or CODEOWNERS, not in tests.
- `@browser-<name>` — environment dimensions belong in Cucumber profiles / Maven profiles, not scenario tags.
- `@todo`, `@fixme` — use `@wip` plus a comment with an issue link instead.
- Status-of-the-day tags (`@release-24.05`) — these rot. Use Git tags / branches for releases.

## Adding a new tag — checklist

Before introducing a new tag, ask:

1. Is this **functional** (about behaviour) or **operational** (about execution)? Operational tags need to map cleanly to a CI job or filter.
2. Will more than 3 scenarios use it? If not, it's probably not worth the cognitive overhead.
3. Does it overlap with an existing tag? If `@critical` already exists, don't add `@must-pass`.
4. Add it to THIS file with definition + execution effect, in the same PR.

## Quick reference for this repo

| Tag | Status | Notes |
|-----|--------|-------|
| `@story-<id>` | Required | Every scenario. |
| `@<area>` | Required | Area is the first segment under `features/<layer>/<area>/`. |
| `@smoke` | Optional | PR check set. |
| `@regression` | Optional | Default for nightly. |
| `@wip` | Lifecycle | Excluded from CI. |
| `@flaky` | Lifecycle | Excluded from PR, runs nightly. |
| `@security` | Cross-cut | Run in security audit + regression. |
| `@perf` | Cross-cut | Dedicated perf job. |
