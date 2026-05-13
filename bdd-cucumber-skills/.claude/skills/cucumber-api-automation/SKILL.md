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
2. **Place the step def class.** Path: `src/test/java/com/<org>/tests/api/stepdefs/<area>/<Feature>StepDefs.java`. Use the template at `assets/template-stepdefs/ApiStepDefs.java`.
3. **Wire up dependencies.** Inject `ScenarioContext`, plus the area's typed client (e.g. `AuthClient`). Cucumber 4.x's picocontainer creates one instance per scenario automatically.
4. **Map each Gherkin step to a `@Given/@When/@Then` method.**
   - Use Cucumber Expressions (`{string}`, `{int}`) — only fall back to regex when an expression can't express the pattern.
   - Step text matches EXACTLY what the feature wrote (whitespace, quotes).
5. **Drive HTTP through the typed client.** The step def calls `authClient.login(LoginRequest payload)`; the client owns base URL, auth, retry semantics.
6. **Persist response into `ScenarioContext.lastResponse`** so `Then` steps can assert on it.
7. **Implement assertions** using Hamcrest + JsonPath. Always assert status code first, then schema, then field values.
8. **Implement `@After` cleanup**. Drain `ScenarioContext.cleanupActions` in LIFO order; swallow exceptions per action but log them.
9. **Implement fixtures.** Place under `src/test/resources/fixtures/<area>/<name>.json`. Load via `FixtureLoader.load("auth/valid-login")`.
10. **Verify**: run only the matching scenario locally with `mvn test -Dcucumber.options="--tags '@story-<id>'"` (full execution patterns in `cucumber-test-execution`).

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
Client(s) used or added: <list>
Fixtures created: <list of .json paths>
Schemas referenced or added: <list of schema paths>
Cleanup actions registered: <count>
Scenarios covered: <count>
Scenarios with TODOs (could not implement): <list with reasons>
```
