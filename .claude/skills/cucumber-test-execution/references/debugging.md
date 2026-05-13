# Failure Triage and Debugging

How to go from "the suite failed" to "the actual problem" in under 5 minutes.

## Triage flow

```
mvn test fails
      │
      ▼
1. Read the SUMMARY (last 30 lines of mvn output)
      │  ── does it show scenario names + steps?
      ▼
2. Open target/cucumber-reports/<run>.html
      │  ── look at red scenarios
      ▼
3. For each failed scenario:
      a. Identify the failing STEP
      b. Identify the EXCEPTION TYPE
      c. Identify whether this is:
         (i)   product bug      → log + escalate
         (ii)  test bug         → fix the step def / fixture
         (iii) infra issue      → retry once; if persists, investigate environment
         (iv)  flake            → tag @flaky + open issue
```

## Reading the cucumber JSON report

`target/cucumber-reports/<run>.json` is the canonical source. Structure (abbreviated):

```json
[
  {
    "uri": "features/api/auth/login.feature",
    "elements": [
      {
        "name": "Wrong password returns 401",
        "type": "scenario",
        "tags": [{"name": "@story-48217"}, {"name": "@auth"}],
        "steps": [
          {
            "name": "I POST to \"/api/v1/auth/login\" with body:",
            "match": {"location": "com.hellen.tests.api.stepdefs.auth.LoginStepDefs.iPostWithBody(String,String)"},
            "result": {"status": "passed", "duration": 123456789}
          },
          {
            "name": "the response status is 401",
            "result": {
              "status": "failed",
              "duration": 4567890,
              "error_message": "java.lang.AssertionError: \nExpected: <401>\n     but: was <200>\n..."
            }
          }
        ]
      }
    ]
  }
]
```

Useful jq queries:

```bash
# All failed scenarios with their failing step name and error message:
jq '.[].elements[] | select(.steps[].result.status == "failed") |
    {scenario: .name,
     failingStep: (.steps[] | select(.result.status == "failed").name),
     error: (.steps[] | select(.result.status == "failed").result.error_message
                     | split("\n")[0])}' target/cucumber-reports/run.json

# Count failures by feature file:
jq -r '.[] | select(.elements[].steps[].result.status == "failed") | .uri' \
    target/cucumber-reports/run.json | sort | uniq -c | sort -rn

# Slowest scenarios:
jq -r '.[].elements[] | {name: .name,
       totalNs: ([.steps[].result.duration] | add)} |
       "\(.totalNs) \(.name)"' target/cucumber-reports/run.json |
   sort -rn | head -20
```

The JSON report is your friend. Drop it into the failure summary at the end of every run.

## Exception → diagnosis map

| Exception | Likely diagnosis | Where to look |
|-----------|------------------|---------------|
| `io.cucumber.junit.UndefinedStepException` | Step text in feature has no matching `@Given`/`@When`/`@Then` | Copy suggested snippet OR fix step text |
| `AssertionError: Expected: <X> but: was <Y>` | API returned different status than asserted | Check the actual response (mvn output has REST Assured log on failure) |
| `JsonPathException: Couldn't find path "..."` | Asserting a field that doesn't exist on this response | Check whether response is success or error shape; branch by status |
| `org.hamcrest.AssertionError: ... matchesJsonSchemaInClasspath` | Schema validation failed | Open the schema file + the actual response; diff |
| `TimeoutError: page.waitForURL: Timeout 30000ms exceeded` | UI navigation didn't happen | Check screenshot in `@After` attachment; verify locator + click |
| `Locator.click: Element is not visible` | Auto-wait timed out on visibility | Element may be hidden by overlay; check trace |
| `PlaywrightException: TargetClosedError` | Page or context closed mid-action | Lifecycle bug — `@After` may have run too early |
| `IllegalStateException: Fixture not found: /fixtures/...` | Missing fixture file | Path typo; or fixture not under `src/test/resources/fixtures/` |
| `NullPointerException` in client | `ScenarioContext` not populated | Picocontainer wiring; or step def order assumes prior `Given` ran |

## Reading REST Assured failure output

When an API assertion fails, REST Assured's `.log().ifValidationFails()` (configured in `RestAssuredConfig.baseSpec`) dumps:

```
Request method:   POST
Request URI:      http://localhost:8080/api/v1/auth/login
Headers:          Content-Type=application/json
                  Accept=application/json
Body:
{"email":"jane@example.com","password":"wrong"}

Response status:  401
Response time:    63 ms
Response body:
{"error":{"code":"auth_failed","message":"Invalid credentials"}}
```

This is GOLD for triage. If you don't see this for an API failure, `baseSpec` isn't applying `.log()` — fix the config.

## Reading Playwright traces

CI runs capture traces to `target/traces/<scenario>.zip` (per `cucumber-e2e-automation/references/waits.md`). View:

```bash
npx playwright show-trace target/traces/Login_redirects_after_success.zip
```

The trace viewer shows:
- Every Playwright command with screenshots before/after.
- Network log per action.
- Console messages.
- Element snapshots for the DOM at each step.

If traces aren't being generated:
- Check `CI` env var is set (the template only enables tracing in CI).
- Check `@Before` actually calls `tracing.start()`.
- Check `@After(order=0)` runs BEFORE `@After` that closes the context.

## "Passes locally, fails in CI"

Top 5 causes:

1. **Timing** — CI is slower; flaky waits surface there first. → Switch to PlaywrightAssertions retrying matchers; bump explicit `waitFor` timeouts.
2. **Different baseUrl** — local hits localhost, CI hits a real env. → Verify `test.api.baseUrl` system property.
3. **Different browser config** — local is headed, CI is headless. → Headless mode renders differently (no scrollbar, different focus behavior). Run locally with `HEADLESS=true` to reproduce.
4. **Test data drift** — local DB has rows from yesterday; CI DB is fresh. → Don't depend on pre-existing data. `Given a registered user "..."` must CREATE the user, not look it up.
5. **Parallelism** — local runs serial, CI runs `--threads 4`. → Audit per `parallel.md` checklist.

When stuck, run CI's config locally:

```bash
CI=true HEADLESS=true mvn test -Pnightly -Dcucumber.options="--threads 4"
```

## Diagnosing flake

A test that passes 9/10 times is flake. Strategy:

1. Tag `@flaky` immediately so CI keeps green while you investigate.
2. Open an issue with: feature file path, scenario name, last 3 failure modes (from JSON reports).
3. Run in a tight loop locally to reproduce:
   ```bash
   for i in {1..50}; do
     mvn test -Pall -Dcucumber.options="--tags '@story-48217 and not @wip'" \
       > flake-$i.log 2>&1 || break
   done
   ```
4. Compare failed runs against passed runs (screenshots, traces, network).
5. Once cause is known, fix → remove `@flaky` → close issue.

NEVER leave `@flaky` indefinitely. Set a 2-sprint deadline; if still unfixed, scenario should be removed or rewritten.

## "Suite is green but coverage decreased"

Cucumber doesn't report coverage natively. Two proxies:

- **Tag coverage**: `jq '[.[].elements[].tags[].name] | unique' target/cucumber-reports/all.json` — should include every story id you expect.
- **Skipped scenarios**: search the JSON for `"status": "skipped"`. Skipped = matched filter but Cucumber didn't run (usually means a `@Before` failed or a `@Given` raised PendingException).

If skipped > 0, the run is NOT green. Treat as failure.

## Quick reference

```bash
# What scenarios match a tag without running them
mvn test -Pall -Dcucumber.options="--dry-run --tags '@smoke'"

# Just one feature file
mvn test -Pall -Dcucumber.options="features/api/auth/login.feature"

# One scenario by exact name (Cucumber 4.x)
mvn test -Pall -Dcucumber.options="features/api/auth/login.feature:9"   # line 9

# Re-run only failed (after a run that produced cucumber.json)
mvn test -Pall -Dcucumber.options="@target/cucumber-reports/failures.txt"
# (You need to generate failures.txt from the JSON report — script helpful here.)

# Verbose log everything (debug only)
mvn test -Pall -Dcucumber.options="--plugin pretty" -X
```
