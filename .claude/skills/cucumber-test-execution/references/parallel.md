# Parallel Execution

How to run Cucumber 4.x scenarios in parallel safely. Most flake during parallel adoption traces to a SINGLE thing: hidden shared state. Fix the state, the parallelism takes care of itself.

## Cucumber 4.x parallel modes

| Option | Effect |
|--------|--------|
| `--threads N` | N scenarios in parallel within ONE JVM (lightweight) |
| Multiple JVM forks (Surefire `forkCount`) | True process isolation; heavier startup |
| Both combined | Multiplicative |

Default recommendation: start with `--threads 2`, measure flake rate over 10 runs, scale up.

## Pre-parallel checklist

Before turning on parallel execution, audit:

- [ ] All step def state is in `ScenarioContext` (PicoContainer-scoped per scenario).
- [ ] No `public static` fields in step defs or clients (except `final` constants).
- [ ] REST Assured `RequestSpecBuilder` is constructed PER scenario, not shared.
- [ ] Playwright `BrowserContext` is created per scenario (`browser.newContext()`).
- [ ] Fixtures are loaded as IMMUTABLE objects + mutated via withers (see `cucumber-api-automation/references/fixtures.md`).
- [ ] No scenario reads from a file that another scenario writes (e.g. shared snapshot files).
- [ ] Database fixtures (if any) use unique IDs / schemas / rows per scenario.

If ANY box is unchecked, fix it BEFORE enabling parallel. Otherwise you'll spend more time debugging parallel flakes than the parallel speedup saves.

## Threads vs forks

### Threads (`--threads N`)

- One JVM, N scenarios concurrent.
- Fast startup, low memory overhead.
- Static state IS shared (the JVM is shared).
- Browser lifecycle: ONE `Playwright` instance can serve multiple threads if each gets its own `BrowserContext`.

Use when: scenarios are state-clean (per checklist above).

### Forks (Surefire `forkCount`)

```xml
<plugin>
  <artifactId>maven-surefire-plugin</artifactId>
  <configuration>
    <forkCount>2</forkCount>
    <reuseForks>false</reuseForks>
    <argLine>-Xmx1024m</argLine>
  </configuration>
</plugin>
```

- Multiple JVMs, each runs scenarios sequentially.
- Heavier startup (each fork loads classes from scratch).
- No static state sharing — strongest isolation.
- Good when threads expose state leakage you can't easily fix.

Forks are usually overkill for Cucumber suites — fix the state and use threads.

## Browser isolation under parallel

Playwright Java thread safety:

- `Playwright` instance: NOT thread-safe; create one per JVM (or per thread if needed).
- `Browser`: thread-safe in practice; can be shared across threads.
- `BrowserContext`: NOT thread-safe; one per scenario, period.
- `Page`: NOT thread-safe; belongs to its `BrowserContext`.

Pattern in `E2eScenarioContext`:

```java
private static final Playwright PLAYWRIGHT = Playwright.create();    // JVM-wide
private static final Browser BROWSER = PLAYWRIGHT.chromium().launch(...);

// PER scenario:
@Before
public void setUp() {
    BrowserContext context = BROWSER.newContext();   // isolated
    ctx.setContext(context);
    ctx.setPage(context.newPage());
}
```

If threads cause Playwright errors ("Page already closed", etc.), the most likely cause is `BrowserContext` reuse — verify Hard Rule 6 in `cucumber-e2e-automation`.

## API client isolation under parallel

REST Assured is thread-safe AT THE CALL SITE, but:

- `RestAssured.given()` reads global state (default URI, default content type). Don't mutate these at runtime.
- Use `RequestSpecBuilder` to create per-scenario specs.
- Authentication tokens MUST live in `ScenarioContext`, not as a static field on a client.

Pattern (from `cucumber-api-automation/references/rest-assured.md`):

```java
public class AuthClient {
    private final RequestSpecification spec;        // per-instance
    public AuthClient() { this.spec = RestAssuredConfig.baseSpec()...; }
}
```

Cucumber's picocontainer creates a fresh `AuthClient` per scenario, so each thread gets its own `spec`.

## Database fixtures under parallel

If scenarios touch a real DB:

- Use unique IDs per scenario (`UUID.randomUUID()`).
- Or, use a per-scenario schema/database/namespace.
- Or, wrap each scenario in a transaction that rolls back (works only if the API supports test transactions).
- NEVER `TRUNCATE table_x` from a scenario — kills siblings running in parallel.

Cleanup runs in `@After`: drain a LIFO cleanup queue. Each scenario cleans only what it created.

## Measuring parallel correctness

After enabling, run this 10 times and tally results:

```bash
for i in {1..10}; do
  mvn test -Pall -Dcucumber.options="--threads 4" > run-$i.log 2>&1
  echo "Run $i: $(grep -c FAILED run-$i.log)"
done
```

Expected: ZERO failures across all 10 runs. Even one is a sign of parallel-unsafe state. Investigate before increasing thread count.

## Common parallel-only failures

| Symptom | Likely cause |
|---------|--------------|
| Test passes alone, fails in parallel | Static state OR shared resource |
| "Connection refused" intermittently | Local backend running out of connections; increase pool or reduce threads |
| Browser test sees wrong page content | BrowserContext reuse |
| Random `JsonPathException: error.code missing` | Two scenarios writing to the same `ScenarioContext` instance — picocontainer wiring broken |
| `Address already in use` | Two scenarios trying to bind the same port |
| Auth token from scenario A appears in scenario B's request | Static `authToken` field somewhere |

If you see any of these, audit per the checklist above.

## When NOT to use parallel

- Smoke suite (already small — parallel adds startup overhead with no wall-clock win).
- Debugging a flaky test (parallel adds noise; isolate first).
- Tests that touch external systems with low rate limits.
- Tests where scenario interaction is intended (some integration tests legitimately need serial execution; tag them `@serial` and exclude from parallel runs).

## Tuning thread count

Rule of thumb:

| Suite type | Threads |
|-----------|---------|
| API only, in-memory backend | `Runtime.getRuntime().availableProcessors() - 1` |
| API only, real test backend | 2–4 (backend often bottlenecks) |
| E2E (browsers) | 2 (each Chromium uses ~300MB; balance memory) |
| Mixed | Pick lower of the two |

Don't go above 4 threads on E2E without measuring CPU + memory headroom — browsers are heavy.

## Quick grep

```bash
# Static state — must not exist in step defs or clients
grep -rn "public static\s\+[A-Z]" src/test/java/com/hellen/tests/ | grep -v final

# Shared mutable singleton patterns
grep -rn "getInstance()" src/test/java/com/hellen/tests/
```

If any results, those need to be cleaned up before scaling parallelism.
