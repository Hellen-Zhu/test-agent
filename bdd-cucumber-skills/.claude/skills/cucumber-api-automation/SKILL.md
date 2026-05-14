---
name: cucumber-api-automation
description: This skill should be used when the user asks to "write API step definitions", "implement Java Cucumber steps", "add REST Assured tests", "generate API tests from a feature file", or when creating/editing any Java file under `src/test/java/.../stepdefs/api/` or matching a `features/api/**/*.feature`. Provides Java + Cucumber 4.x + REST Assured implementation conventions: package layout, step def patterns, fixtures, schema validation, and state-cleanup discipline.
---

# Cucumber API Automation

How to implement step definitions for `features/api/**/*.feature` files using Java + Cucumber 4.x + REST Assured. Covers package layout, request/response idioms, fixture management, and per-scenario isolation.

## When this applies

Use this skill when:
- A `features/api/**/*.feature` file exists and the matching step defs are missing or out of date.
- Editing Java files under `src/test/java/**/stepdefs/api/**`.
- The user asks "write the API test for this feature".
- A new HTTP route or response shape needs coverage.

Do NOT use this skill when:
- The feature file itself needs writing → `bdd-feature-authoring`.
- Working on `features/ui/**` step defs → `cucumber-e2e-automation`.
- Running or filtering tests → `cucumber-test-execution`.

## Hard Rules

1. Package layout MUST be `com.<org>.tests.api.stepdefs.<area>` for step defs, `com.<org>.tests.api.clients.<area>` for typed clients, `com.<org>.tests.api.support` for shared infra.
2. ONE step def class per feature file. File name = `<FeatureName>StepDefs.java`. Class name in PascalCase.
3. Step def classes MUST be stateless across scenarios. Share scenario-scoped state via PicoContainer-injected `ScenarioContext`, NEVER static fields.
4. NEVER call `RestAssured.given()` directly inside step defs. All HTTP goes through a typed client in `clients.<area>`. Step defs orchestrate, clients perform.
5. NEVER inline test data in step defs. Fixtures live in `src/test/resources/fixtures/<area>/*.json` and are loaded via `FixtureLoader.load(...)`.
6. EVERY scenario that creates server-side state MUST clean up in a `@After` hook keyed by the `@AfterEach` cleanup queue on `ScenarioContext`.
7. NEVER hardcode credentials, tokens, base URLs. Use `System.getProperty("test.<key>")` with sensible defaults from `src/test/resources/application-test.properties`.
8. EVERY response assertion MUST include a schema check via `JsonSchemaValidator.matchesJsonSchemaInClasspath("schemas/<area>/<name>.json")` for any non-trivial response body.
9. **The SUT's online OpenAPI/Swagger spec is the upstream source of truth** for endpoints, status codes, and request/response shapes. The agent reads it via `WebFetch` against the URL resolved from `application-test*.properties` (`test.api.docsUrl` or equivalent, environment-pinned). Local `schemas/<area>/*.json` files are spec-pinned snapshots — authoritative for `matchesJsonSchemaInClasspath` at runtime, but the spec is upstream. **Drift between spec and local schema is surfaced in the output report, NEVER silently fixed by the agent.**

## Standards (index)

| # | Standard | Details |
|---|----------|---------|
| S1 | **Request building uses the builder pattern**; never long chains of `.queryParam().header().body()` inline. | `references/rest-assured.md` |
| S2 | **Response extraction via Hamcrest matchers**, not raw `equals`. Use `JsonPath` for nested fields. | `references/rest-assured.md` |
| S3 | **Fixtures are immutable; mutations happen via builders** that return new instances. | `references/fixtures.md` |
| S4 | **Schema files are versioned**; breaking changes get a new file, not in-place edits. | `references/schema-validation.md` |
| S5 | **Idempotent setup**: any entity created in `Given` must be cleaned in `@After`, even on failure. | This SKILL.md, Hard Rule 6 |

## Core Procedure

For each `.feature` file you implement:

1. **Read the feature.** Note scenarios, tags, doc-string payloads, data tables, parameter types.

2. **Discovery phase — read upstream first, then reuse before authoring.** This agent has no Bash tool by design (least privilege); the only network-touching tool is `WebFetch`, scoped to fetching the SUT spec. Use Glob / Grep / Read / WebFetch in the order below. Record findings in the Output report. Full procedure: `references/step-discovery.md`.

   - **2a. Tier 0 — SUT contract (online OpenAPI/Swagger spec).** Per Hard Rule 9. Resolve `test.api.docsUrl` from `src/test/resources/application-test*.properties` (or ask the user if absent). WebFetch the spec, extract endpoint paths / status codes / request shapes / response shapes for the endpoints the feature touches. Detect drift against local `schemas/<area>/*.json`. If unreachable, mark `SUT contract source: unreachable — <reason>` and continue under that caveat — do NOT silently degrade to "guess from feature text".
   - **2b. Tier 1–5 — Built-in steps from the internal BDD framework.** Walk the 5-tier hierarchy from `references/step-discovery.md § 1`: `.bdd-step-index/api-*.txt` → `STEPS.md` → cached Javadoc → AskUserQuestion → mark unavailable. Record which tier resolved each match.
   - **2c. Existing typed clients.** Glob `src/test/java/**/clients/**/*.java`. For each `<Area>Client`, Read the public method signatures. If a method already covers the HTTP call the feature needs, REUSE it — do not create a parallel client.
   - **2d. Existing step defs.** Glob `src/test/java/**/stepdefs/**/*.java`. Grep for `@Given|@When|@Then` annotations whose regex matches a Gherkin line in this feature. If a match exists, decide whether to reuse (cross-feature shared step) or to author a feature-scoped step in this file — and justify the choice in the report.
   - **2e. Existing fixtures.** Glob `src/test/resources/fixtures/<area>/*.json`. If a fixture covers the payload shape (possibly via the builder mutation pattern, see `references/fixtures.md`), reuse it.
   - **2f. Existing schemas.** Glob `src/test/resources/schemas/<area>/*.json`. If a schema already validates the response shape AND the spec confirms it's still current (no drift from 2a), reference it. Author a new schema only when the response shape genuinely doesn't exist yet OR drift forces a versioned new file (Hard Rule S4).
   - **2g. Reuse tags.** For each piece you decided to author, assign one tag and record it in the inventory:
     | Tag | Meaning |
     |-----|---------|
     | `REUSE_BUILTIN` | Built-in step from internal framework (Tier 1) matches |
     | `REUSE_CLIENT` | Existing typed client method covers the call |
     | `REUSE_STEP` | Existing project `@Given/@When/@Then` matches the Gherkin line |
     | `REUSE_FIXTURE` | Existing fixture (possibly mutated) covers the payload |
     | `REUSE_SCHEMA` | Existing schema covers the response shape AND spec confirms no drift |
     | `NEW_CLIENT` / `NEW_STEP` / `NEW_FIXTURE` / `NEW_SCHEMA` | No existing artifact matches; justify in the report |

3. **Place the step def class.** Path: `src/test/java/com/<org>/tests/api/stepdefs/<area>/<Feature>StepDefs.java`. Use the template at `assets/template-stepdefs/ApiStepDefs.java`.
4. **Wire up dependencies.** Inject `ScenarioContext`, plus the area's typed client (e.g. `AuthClient`). Cucumber 4.x's picocontainer creates one instance per scenario automatically.
5. **Map each Gherkin step to a `@Given/@When/@Then` method.**
   - Use Cucumber Expressions (`{string}`, `{int}`) — only fall back to regex when an expression can't express the pattern.
   - Step text matches EXACTLY what the feature wrote (whitespace, quotes).
6. **Drive HTTP through the typed client.** The step def calls `authClient.login(LoginRequest payload)`; the client owns base URL, auth, retry semantics.
7. **Persist response into `ScenarioContext.lastResponse`** so `Then` steps can assert on it.
8. **Implement assertions** using Hamcrest + JsonPath. Always assert status code first, then schema, then field values.
9. **Implement `@After` cleanup**. Drain `ScenarioContext.cleanupActions` in LIFO order; swallow exceptions per action but log them.
10. **Implement fixtures.** Place under `src/test/resources/fixtures/<area>/<name>.json`. Load via `FixtureLoader.load("auth/valid-login")`.

11. **Hand off — do NOT run tests.** This skill is **write-only**. Test execution is the orchestrator's responsibility, performed via the `cucumber-test-execution` skill in a separate step (typically a separate agent invocation). The api-test-agent intentionally has no `Bash` tool — there is no path for this skill to run `mvn test` itself.

    What you DO at this step:

    - Stop after the code is written, fixtures + schemas are in place, and cleanup is registered.
    - Set `Verification status: NOT VERIFIED — handoff to orchestrator` in the Output report.
    - If you suspect a syntactic problem (e.g. you referenced a fixture path you weren't 100% sure existed), call it out under `Concerns for orchestrator run`. Do NOT attempt to compile or invoke the test runner to confirm.

    What you do NOT do:

    - Run `mvn test`, `mvn compile`, `javac`, or any test/build command.
    - Invoke `cucumber-test-execution` skill from inside this skill (the orchestrator owns that handoff).
    - Silently "fix" anything based on assumed test output.

    Failure feedback loop: if the orchestrator's run produces failures, it will dispatch a follow-up task to this same agent with the failure log. Handle that as a new invocation of this skill, scoped to the failing scenarios.

## When to consult what

| Situation | Load |
|-----------|------|
| Designing request builders / response extraction | `references/rest-assured.md` |
| Adding a new fixture or refactoring an existing one | `references/fixtures.md` |
| Asserting response shape | `references/schema-validation.md` |
| Starting a brand-new step def class | `assets/template-stepdefs/ApiStepDefs.java` |
| Auth, token refresh, or session handling | `references/rest-assured.md` (§ "Authenticated requests") |

## Tooling assumptions

This skill assumes the project's `pom.xml` includes (Cucumber 4.x compatible versions):

- `io.cucumber:cucumber-java` 4.8.x
- `io.cucumber:cucumber-junit` 4.8.x
- `io.cucumber:cucumber-picocontainer` 4.8.x
- `io.rest-assured:rest-assured` 4.x
- `io.rest-assured:json-schema-validator` 4.x
- `org.hamcrest:hamcrest` 2.x

If versions differ, surface this in the report — do NOT silently adapt code to incompatible versions.

## Failure modes

- **Symptom**: `io.cucumber.junit.UndefinedStepException`. → **Cause**: Step text in feature doesn't match any `@When`/`@Then` annotation. → **Fix**: Copy the suggested snippet Cucumber prints, OR adjust the step text in the feature (but see Hard Rule 8 in `bdd-feature-authoring`).
- **Symptom**: Scenario passes alone, fails when run in suite. → **Cause**: Static state leaking between scenarios (violates Hard Rule 3). → **Fix**: Move state into `ScenarioContext` (PicoContainer scopes per scenario).
- **Symptom**: Cleanup not running on assertion failure. → **Cause**: Cleanup happens in `@After` — but exceptions in cleanup short-circuit subsequent actions. → **Fix**: Wrap each cleanup action in its own try/catch; log and continue.
- **Symptom**: `JsonPathException: Couldn't find path "..."`. → **Cause**: Schema-mismatched response (e.g. error case where success-shape field doesn't exist). → **Fix**: Branch on status code; only assert success-shape fields when status is 2xx.
- **Symptom**: Schema validation fails on backwards-compatible change. → **Cause**: Schema treats additional properties as forbidden. → **Fix**: Set `additionalProperties: true` in schema for fields you don't pin; bump schema version when shape truly changes.
- **Symptom**: Hardcoded `http://localhost:8080` works on dev, fails on CI. → **Cause**: Violates Hard Rule 7. → **Fix**: Read from `System.getProperty("test.api.baseUrl")` with default in `application-test.properties`.

## Output report

When done implementing a feature's step defs:

```
Feature: <path>
Step def class: <path to .java>

Discovery inventory:
  SUT contract source: <URL or "unreachable — <reason>">
  Spec format: <OpenAPI 3.x | Swagger 2.x | unknown>
  Endpoints touched by feature: <count>
    - <METHOD> <path>  [verified against spec | not verified — spec unreachable]
  Local schema drift detected: <count>
    - <endpoint>: <what changed in spec that local schema doesn't reflect>

  Built-in step discovery (Tier 1):
    Discovery source: index | catalog | javadoc | user-provided | unavailable
    Built-in step library: <groupId:artifactId:version>
    Index file consulted: <path, or "n/a — used <tier>">
    Built-in steps matched: <count>
      - <step regex>  →  <FQN>

  Project-side scan:
    Existing clients scanned: <count> under src/test/java/**/clients/
    Existing step defs scanned: <count> under src/test/java/**/stepdefs/
    Existing fixtures scanned: <count> under src/test/resources/fixtures/
    Existing schemas scanned: <count> under src/test/resources/schemas/

Reuse vs. new (per artifact):
  REUSE_BUILTIN: <count> — list FQNs
  REUSE_CLIENT:  <count> — list FQNs
  REUSE_STEP:    <count> — list FQNs
  REUSE_FIXTURE: <count> — list paths
  REUSE_SCHEMA:  <count> — list paths
  NEW_CLIENT:    <count> — files: <list>  ← justify each below
  NEW_STEP:      <count> — files: <list>
  NEW_FIXTURE:   <count> — files: <list>
  NEW_SCHEMA:    <count> — files: <list>

New artifact justifications (if any NEW_* > 0):
  - <artifact>: <why no existing artifact covers this need>

Cleanup actions registered: <count>
Scenarios covered: <count>
Scenarios with TODOs (could not implement): <list with reasons>

Verification status: NOT VERIFIED — handoff to orchestrator
Concerns for orchestrator run: <list, or "none">
  e.g. "fixture `auth/legacy-login.json` referenced from generated code — verified
        exists via Glob but contents not validated against schema"
```
