---
name: cucumber-test-execution
description: This skill should be used when the user asks to "run the tests", "run cucumber", "mvn test", "filter by tag", "execute with @smoke", "run in parallel", "generate cucumber report", or after generating new step defs and wanting to verify. Provides Maven + Cucumber 4.x execution patterns: tag expression syntax (the new `or`/`and`/`not` form, not commas), parallel execution, profile-based scoping, report generation, and failure triage.
---

# Cucumber Test Execution

How to run the Cucumber 4.x suite with the right scope, in parallel, and produce reports that survive triage. This skill OWNS execution discipline — agents and humans should defer to it for every `mvn` invocation.

## When this applies

Use this skill when:
- The user wants to run any subset of tests (`mvn test`, `@smoke`, "this one feature", etc.).
- After step defs have been generated and you need to verify them.
- The user says "run cucumber", "filter by tag", "make it parallel", "where's the report".
- Triaging failures from a CI run.

Do NOT use this skill when:
- The tests don't exist yet — write them via `cucumber-api-automation` or `cucumber-e2e-automation` first.
- Designing a new tag — that's `bdd-feature-authoring` (specifically `tag-conventions.md`).

## Hard Rules

1. Cucumber 4.x tag expressions use `or`, `and`, `not` keywords. NEVER commas. `@smoke,@regression` is a syntax error in 4.x.
2. The tag expression MUST be quoted: single quotes inside double quotes when passed via `-Dcucumber.options="..."`. Unquoted `or` becomes a shell keyword and breaks.
3. CI runs MUST exclude `@wip`. Use `not @wip` in every CI-bound tag expression.
4. Parallel execution via `--threads N`. Before enabling, verify all step defs use `ScenarioContext` (no static state) — see `cucumber-api-automation` / `cucumber-e2e-automation` Hard Rule 3.
5. Reports go to `target/cucumber-reports/`. Plugins: `pretty`, `html:target/cucumber-reports/<run-id>.html`, `json:target/cucumber-reports/<run-id>.json`. NEVER overwrite report paths across runs in CI.
6. NEVER use `--retry` to mask flakiness without an `@flaky` tag on the affected scenarios AND an issue link. Retry hides bugs; tag-and-track surfaces them.
7. The build MUST fail when ANY scenario fails. NEVER configure `testFailureIgnore=true` in pom.xml.

## Standards (index)

| # | Standard | Details |
|---|----------|---------|
| S1 | **Maven profiles for execution scope** (`-Papi`, `-Pe2e`, `-Psmoke`, `-Pall`). Profiles fix the glue path + tag expression. | `references/maven-profiles.md` |
| S2 | **Local: scoped + verbose. CI: full + concise.** Different plugin configs per environment. | `references/maven-profiles.md` |
| S3 | **Parallel default is conservative.** Start with `--threads 2`; increase only after measuring flake rate. | `references/parallel.md` |
| S4 | **Failure triage starts at the JSON report**, not the console. JSON has structured per-step results. | `references/debugging.md` |

## Core Procedure

For each test execution:

1. **Identify scope.** What's being verified?
   - All API tests for a story → `-Pall --tags '@story-<id>'`
   - Smoke on a PR → `-Pall --tags '@smoke and not @wip and not @flaky'`
   - Single scenario → `--tags '@story-<id> and @<some-discriminator>'` or use feature file path
2. **Build the tag expression.** Use `references/maven-profiles.md` as the menu; combine via `and`/`or`/`not`.
3. **Decide parallelism.** Local fast iteration: `--threads 1` (easier to read output). CI: thread count from profile.
4. **Pick reports.** Local: `pretty` only (console-friendly). CI: `pretty + html + json`.
5. **Run.**
   ```bash
   mvn test -Pall -Dcucumber.options="--tags '@smoke and not @wip' --threads 2 --plugin pretty --plugin html:target/cucumber-reports/run.html --plugin json:target/cucumber-reports/run.json"
   ```
   OR use the wrapper:
   ```bash
   scripts/run-by-tag.sh "@smoke and not @wip" --threads 2
   ```
6. **Triage failures.** If exit != 0, open `target/cucumber-reports/run.json` (or the HTML report) — `references/debugging.md` walks through how.
7. **Report results.** Format:
   ```
   ✅ <N> scenarios passed in <duration>
   ❌ <M> scenarios failed:
      - <feature> :: <scenario name>
        Step: <failing step>
        Cause: <message + first stack line>
   ```

## When to consult what

| Situation | Load |
|-----------|------|
| Setting up or editing `pom.xml` profiles | `references/maven-profiles.md` |
| Enabling/expanding parallel execution | `references/parallel.md` |
| Tests failed and you need to understand why | `references/debugging.md` |
| Need a one-liner for a specific tag combo | `scripts/run-by-tag.sh --help` |

## Cucumber 4.x tag expression cheat sheet

| Intent | Expression |
|--------|-----------|
| Either | `'@smoke or @regression'` |
| Both | `'@auth and @smoke'` |
| Negation | `'not @wip'` |
| Combined | `'(@smoke or @regression) and not @wip and not @flaky'` |
| Specific story | `'@story-48217'` |
| Story + smoke subset | `'@story-48217 and @smoke'` |

## Failure modes

- **Symptom**: `Tag expression '@smoke,@regression' could not be parsed`. → **Cause**: Old-style comma syntax (Cucumber 3.x). → **Fix**: Use `'@smoke or @regression'`.
- **Symptom**: `or: command not found` or similar shell error. → **Cause**: Tag expression isn't quoted properly. → **Fix**: Single-quote the expression inside double-quoted `-Dcucumber.options`.
- **Symptom**: Tests pass with `--threads 1` but fail with `--threads 4`. → **Cause**: Hidden shared state. → **Fix**: Audit step defs and clients for static fields, shared `ScenarioContext` instances, or non-isolated resources.
- **Symptom**: Report file is empty / corrupt after CI run. → **Cause**: Multiple runs overwrote the same path, or build was interrupted. → **Fix**: Use unique report names per run (`run-${BUILD_ID}.json`).
- **Symptom**: `mvn test` runs but skips all scenarios. → **Cause**: Tag expression filters everything out. → **Fix**: Run `mvn test -Dcucumber.options="--dry-run --tags '<expr>'"` to confirm which scenarios match.
- **Symptom**: Build returns 0 even though scenarios failed. → **Cause**: `testFailureIgnore=true` somewhere in pom — violates Hard Rule 7. → **Fix**: Remove the property.
- **Symptom**: After step defs are renamed, `mvn test` finds zero glue. → **Cause**: Glue package mismatch. → **Fix**: Verify `cucumber.glue` system property OR `@CucumberOptions(glue = ...)` in the runner class matches the new package.

## Output report format

After every run:

```
Scope:       --tags '@smoke and not @wip'
Profile:     -Pall
Parallelism: 2 threads
Duration:    47.3s
Result:      ✅ 28 / 28 passed
             OR
             ❌ 26 / 28 passed; 2 failed:
                1. features/api/auth/login.feature :: Wrong password returns 401 with stable error code
                   Step: Then the response body has "error.code" equal to "invalid_credentials"
                   Cause: NoSuchElementException — JsonPath "error.code" missing
                2. ...
Reports:     target/cucumber-reports/run.html
             target/cucumber-reports/run.json
```

NEVER dump full stack traces in the summary. Open the report for those.
