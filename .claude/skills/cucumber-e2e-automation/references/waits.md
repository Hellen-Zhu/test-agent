# Waits, Auto-Waiting, and Network Observation

How to make tests fast AND deterministic. The single most common source of E2E flake is wait misuse — this document is the playbook against it.

## The core rule

**NEVER `Thread.sleep`.** Hard Rule 3. This includes:
- `Thread.sleep(N)`
- `await Task.Delay(N)` (wrong language anyway)
- `page.waitForTimeout(N)` (Playwright HAS this method — it's a foot-gun)
- Custom `while (!ready) { wait 100ms }` polling that doesn't bound the iteration

If you need to wait, wait on a SEMANTIC condition.

## Playwright's auto-waiting

Playwright auto-waits for actionability before most operations:

- `click()` waits for: visible, stable, enabled, receives events
- `fill()` waits for: visible, stable, enabled, editable
- `selectOption()` waits for: visible, enabled
- `hover()`, `dblclick()`, etc. — same actionability checks

This means in MANY cases you don't need explicit waits at all:

```java
page.getByRole(BUTTON, new Page.GetByRoleOptions().setName("Sign in")).click();
// Playwright already waited for the button to be visible + enabled + stable.
```

The places you DO need explicit waits:

1. **Navigation that doesn't immediately trigger a visible element**: `page.waitForURL("**/dashboard")`.
2. **Disappearance**: `locator.waitFor(new Locator.WaitForOptions().setState(HIDDEN))`.
3. **Custom JavaScript state**: `page.waitForFunction("window.appReady === true")`.
4. **Network call observation**: `page.waitForResponse(predicate)`.

## Retrying assertions (the PlaywrightAssertions API)

For any assertion against page state, use `PlaywrightAssertions.assertThat(locator)` — it RETRIES until timeout (default 5s):

```java
import static com.microsoft.playwright.assertions.PlaywrightAssertions.assertThat;

assertThat(loginPage.inlineError()).hasText("Invalid email or password");
assertThat(loginPage.submitButton()).isDisabled();
assertThat(loginPage.submitButton()).isEnabled();
assertThat(page).hasURL("**/dashboard");
assertThat(loginPage.passwordInput()).hasAttribute("type", "password");
```

vs. NON-RETRYING (one-shot snapshot):

```java
import static org.hamcrest.MatcherAssert.assertThat;
import static org.hamcrest.Matchers.*;

assertThat(loginPage.submitIsDisabled(), is(true));   // ← reads ONCE, fails if not disabled NOW
```

Pick based on intent:
- "Eventually the error appears" → PlaywrightAssertions
- "Right now, in this synchronous moment, X is true" → Hamcrest

99% of UI assertions are eventual. Default to PlaywrightAssertions.

## Common wait patterns

### Wait for navigation

```java
// After click that triggers redirect:
submitButton.click();
page.waitForURL("**/dashboard");
```

`waitForURL` accepts glob, regex, or predicate. Globs handle query strings.

### Wait for an element to disappear

```java
loadingSpinner.waitFor(new Locator.WaitForOptions().setState(HIDDEN));
```

Don't `waitForTimeout` and then check. Wait on the disappearance.

### Wait for an API response (observation only — not mocking)

```java
Response response = page.waitForResponse(
    "**/api/v1/auth/login",
    () -> submitButton.click()
);
assertThat(response.status()).isEqualTo(200);
```

The lambda is the trigger; `waitForResponse` blocks until a matching response is received. Pattern is "set up the listener, then act, then assert on the response".

### Wait for a custom condition

Use `page.waitForFunction` ONLY when there's no DOM observable:

```java
page.waitForFunction("() => window.appReady === true");
```

Avoid if a DOM element can serve as the sentinel — `locator.waitFor(VISIBLE)` is simpler and more reliable.

## Network observation: when to use `page.route`

Two modes: OBSERVE (passively watch network) vs MOCK (intercept and return canned response).

### Observe — assert what the browser DID

For a scenario like "submitting with empty fields sends no network request":

```java
List<String> calls = new ArrayList<>();
page.route("**/api/v1/auth/login", route -> {
    calls.add(route.request().url());
    route.fallback();   // pass through to real server
});

submitButton.click();
page.waitForTimeout(...);    // ❌ DON'T

// Better: bounded wait via expect
expect(loginPage.submitButton()).isEnabled();   // proxy for "request completed or was never made"
assertThat(calls, hasSize(0));
```

Pattern: subscribe to route, perform action, then assert on the observed list. ALWAYS bound the wait via a semantic condition, not a timeout.

### Mock — isolate the UI from the backend

Use mocking ONLY when the scenario tests UI behaviour in isolation (e.g. "the spinner appears during the request"):

```java
page.route("**/api/v1/auth/login", route -> {
    // Delay response so we can verify the spinner appears
    page.waitForTimeout(0);   // even here, prefer a real signal
    route.fulfill(new Route.FulfillOptions()
        .setStatus(200)
        .setBody("{\"token\": \"fake\"}")
        .setContentType("application/json"));
});
```

CRITICAL: when you mock, ALSO ensure the corresponding REAL behaviour is covered at the API layer. Otherwise mock drift will hide regressions.

## Timing budgets

For "X must happen within Y ms":

```java
long start = System.currentTimeMillis();
submitButton.click();
page.waitForURL("**/dashboard");
long elapsed = System.currentTimeMillis() - start;

assertThat("redirect was " + elapsed + "ms", elapsed, lessThan(2000L));
```

Wrap the navigation in a stopwatch. NEVER `Thread.sleep(2000)` and check after — that asserts "happened within OR took exactly 2000ms".

For sub-second budgets, UI timing is inherently noisy. Treat < 200ms assertions with suspicion; they'll be flaky in CI.

## Tracing for diagnosis

Enable Playwright tracing in CI runs ONLY (it's slow + heavy):

```java
@Before
public void setUp() {
    boolean ci = System.getenv("CI") != null;
    if (ci) {
        ctx.context().tracing().start(new Tracing.StartOptions()
            .setScreenshots(true)
            .setSnapshots(true)
            .setSources(true));
    }
}

@After(order=0)
public void afterScenario(Scenario scenario) {
    if (scenario.isFailed() && ci) {
        Path trace = Paths.get("target/traces/" + scenario.getName() + ".zip");
        ctx.context().tracing().stop(new Tracing.StopOptions().setPath(trace));
    } else if (ci) {
        ctx.context().tracing().stop();
    }
}
```

On failure, `npx playwright show-trace target/traces/<scenario>.zip` gives a frame-by-frame replay. Worth the disk space.

## Anti-patterns

### Anti-pattern: arbitrary sleep before assertion

```java
submitButton.click();
Thread.sleep(2000);   // "wait for it"
assertThat(page).hasURL("**/dashboard");
```

If 2000ms isn't enough on a slow CI, you'll flake. If it's too much, your tests are slow.

### Anti-pattern: wait for an arbitrary intermediate

```java
submitButton.click();
page.waitForLoadState(LoadState.NETWORKIDLE);   // ← very fragile
```

`networkidle` is unstable on apps with WebSockets, polling, or analytics. Wait for the SPECIFIC thing you care about.

### Anti-pattern: assertions that aren't retrying

```java
assertThat(loginPage.inlineErrorText(), equalTo("Invalid email or password"));
```

If the error appears asynchronously, this reads the field BEFORE the error is set → fails → flake. Use PlaywrightAssertions instead.

### Anti-pattern: re-querying inside a wait loop

```java
while (!page.getByText("Done").isVisible()) {
    Thread.sleep(100);
}
```

This is reinventing `locator.waitFor(VISIBLE)` — badly. Use the built-in.

## Quick grep

```bash
# Find disallowed sleeps
grep -rn "Thread.sleep\|waitForTimeout" src/test/java/

# Find non-retrying boolean assertions on UI state
grep -rn "assertThat.*isVisible()\|isDisabled()\|isEnabled()" src/test/java/com/hellen/tests/e2e/stepdefs/
# (Most of these should be PlaywrightAssertions.assertThat(locator).isXxx() — retrying.)
```
