# Step Discovery (API)

Before authoring any new Java code for an API feature, you MUST walk the reuse hierarchy and record findings. This is the Discovery phase from `SKILL.md § Core Procedure § 2`. Skipping it is the most common review-rejection cause for API tests too — the internal BDD framework ships built-in steps for both UI and API layers, and re-implementing one is a high-noise PR comment.

## The reuse hierarchy

```
0. SUT contract (online OpenAPI/Swagger spec)           ← read FIRST — endpoint truth
1. Built-in step (Maven dependency, API-side library)   ← then this
2. Existing project step / client / fixture / schema    ← then this
3. New step composed of existing primitives             ← then this
4. Author a new Java step + client + fixture + schema   ← last resort, justify each
```

Each downward step requires evidence the upper tiers don't satisfy the need. Recording that evidence in the output report is what makes the discipline reviewable.

## Discovery is mostly read-only

This agent has **no Bash tool by design** (least privilege — see `SKILL.md § 11 Hand off`). The single network-touching tool is `WebFetch`, scoped to fetching the SUT's online OpenAPI/Swagger spec (Tier 0 below). All other discovery uses Read / Glob / Grep against artifacts the build system has already produced. If you find yourself wanting to run `unzip`, `mvn`, `javap`, or any shell command, **stop** — that's a build-time concern that should have been pre-materialized into one of the discovery sources below. Surface the gap in the output report instead of trying to escalate privilege.

## 0. Reading the SUT contract (online OpenAPI/Swagger spec) — Tier 0

The system under test publishes its HTTP contract as an OpenAPI 3.x or Swagger 2.x document. This is the **authoritative source of truth** for: endpoint paths, HTTP methods, request body shapes, response body shapes, status codes, and parameter constraints. Every API feature you implement MUST be reconciled against this contract before you author or reuse anything else.

### Locating the spec URL

The URL is environment-dependent and lives in test config, not in this skill. Resolution order:

1. Glob `src/test/resources/application-test*.properties`. Read the file. Look for a key like `test.api.docsUrl`, `test.openapi.url`, `swagger.url`, or `api.docs.url`.
2. If no properties file, Glob `bdd-cucumber-skills/CLAUDE.md` and `**/CLAUDE.md` — the project root may document the URL there for agent consumption.
3. If still unresolved, AskUserQuestion for the URL (a one-line answer is fine; do NOT proceed to Tier 1 with the contract unknown).

Record the resolved URL verbatim in the output report under `SUT contract source`.

### Fetching the spec

Use `WebFetch` against the resolved URL with a prompt like:

> Extract from this OpenAPI/Swagger document, for the endpoints mentioned in this feature:
> `<list endpoint method+path candidates from the feature's Gherkin lines>`
> — request body schema, response body schema (per status code), required vs optional parameters, valid status codes.

WebFetch returns a summarized extraction (not the full spec, which can be megabytes). The summary is what you reason against.

If WebFetch fails (network unreachable, 401/403, host blocked), do NOT silently degrade to "I'll guess from feature text". Mark `SUT contract source: unreachable — <reason>` in the output report, list every endpoint you couldn't verify, and continue with Tier 1+ under that documented caveat.

### What to reconcile

For every endpoint your feature touches, check:

| Question | Authority |
|----------|-----------|
| Does this endpoint exist? | Spec — if not, raise as `Feature touches undocumented endpoint` |
| What status codes are valid? | Spec — feature's `Then the response status is N` must be in the spec's responses list |
| What's the request shape? | Spec — feature's fixture must conform |
| What's the response shape? | Spec — informs which `schemas/<area>/*.json` to reuse, or whether a NEW_SCHEMA is needed |

### Local schema files are snapshots of the spec, NOT independent truth

`src/test/resources/schemas/<area>/*.json` are version-pinned snapshots of response shapes derived from the spec. They remain authoritative for `matchesJsonSchemaInClasspath` validation at test runtime (because tests must be reproducible and CI may not have spec-host access). But the **spec is upstream truth**; if you detect drift during discovery (e.g. spec adds a new required field that the local schema doesn't pin), record it as `Local schema drift detected:` in the output report. **Do NOT auto-update the local schema** — schema regeneration is a build-engineer/maintainer task, not an agent action. Surface the drift so the orchestrator/reviewer can dispatch the refresh.

### Recording Tier 0 in the inventory

```
SUT contract source: https://api.staging.hellen.com/v3/api-docs
Spec format: OpenAPI 3.0.3
Endpoints touched by feature: 3
  - POST /v2/auth/login              [verified against spec]
  - POST /v2/auth/logout             [verified against spec]
  - GET  /v2/users/{id}              [verified against spec]
Local schema drift detected: 0
```

## 1. Discovering built-in API steps — the 5-tier source hierarchy

The internal BDD framework ships built-in steps for the API layer in the same repo as the UI steps (different artifact / shard, same plugin). Walk these sources in order and stop at the first one that answers. Record which tier you used in the output report (`Discovery source` field).

### Tier 1 — `.bdd-step-index/` (preferred)

The Maven build produces a pre-extracted index of every built-in step at `bdd-cucumber-skills/.bdd-step-index/`. API steps live in a shard (filename depends on how the framework plugin shards — common patterns: `api-builtin-steps.txt`, `api-*-steps.txt`, or a combined `builtin-steps.txt`).

Each line is pipe-delimited:

```
@Given|the user {string} exists|com.hellen.framework.bdd.api.steps.UserSteps#userExists
@When|I POST {string} with body {string}|com.hellen.framework.bdd.api.steps.HttpSteps#postWithBody
@Then|the response status is {int}|com.hellen.framework.bdd.api.steps.AssertionSteps#statusIs
@Then|the response JSON path {string} equals {string}|com.hellen.framework.bdd.api.steps.AssertionSteps#jsonPathEquals
```

Procedure:

1. Glob `bdd-cucumber-skills/.bdd-step-index/*.txt`. Prefer `api-*.txt` shards. If empty/missing, jump to Tier 2.
2. For each Gherkin verb in the feature, Grep the index for the matching annotation pattern:
   - Gherkin `When I POST "/login" with body "valid-login"` → Grep for `^@When\|I POST ` in the api shard.
   - Gherkin `Then the response status is 200` → Grep for `^@Then\|the response status is `.
3. Read the relevant shard directly if you need surrounding context (e.g. to see signature variants).
4. Record the match in the inventory with FQN from column 3.

The index is generated by `step-index-maven-plugin` during `mvn install` (see `bdd-cucumber-skills/.bdd-step-index/README.md` for plugin setup and regeneration cadence). It is gitignored; agents read it but never write it.

### Tier 2 — `STEPS.md` catalog published by the framework team

If `.bdd-step-index/` is absent (fresh checkout, plugin not yet wired), look for a step catalog committed by the framework owners. Probe these paths via Glob:

```
docs/STEPS.md
docs/api-steps.md
docs/step-catalog.md
bdd-cucumber-skills/docs/STEPS.md
```

A catalog is a Markdown table listing every step verb, parameter signature, and FQN. Read it and treat it as authoritative — it ships with the framework JAR, so it's version-locked to whatever the project depends on.

### Tier 3 — cached Javadoc / generated docs site

Some teams publish step Javadoc as a static site. If `pom.xml` or `bdd-cucumber-skills/docs/` references a URL like `https://docs.<org>.com/bdd-steps/api/`, use WebFetch (one-shot) to retrieve a specific class page if needed. Do NOT crawl — pick the page that names the verb you're looking for.

### Tier 4 — ask the user

If Tiers 1–3 all came up empty, do NOT silently degrade to "I'll just author a new step". Use AskUserQuestion to ask the user for:

- A path to a step catalog you missed, OR
- A pointer to the framework team's documentation, OR
- Explicit permission to proceed with `NEW_STEP` for the unmatched verbs (which puts the reuse-vs-write decision on the user, with audit trail).

### Tier 5 — surface as unavailable

If even Tier 4 yields nothing, mark the discovery source as `unavailable` in the Output report. List every Gherkin line that couldn't be checked against built-ins. The orchestrator/reviewer decides whether to proceed or block — agents do NOT decide for them.

## 2. Discovering existing project artifacts

Project-side discovery uses ordinary Read / Glob / Grep — no special index needed because the source files are in the working tree. API has more artifact types than UI to consider (clients + fixtures + schemas alongside step defs).

### 2a. Existing step defs

```
Glob: src/test/java/**/{steps,stepdefs}/**/*.java
Grep: @(Given|When|Then)\(  in those files
```

For each Gherkin line still unmatched after Tier 1–5, check whether any project step matches. Note that on the API side these are usually feature-scoped (one StepDefs class per feature, per Hard Rule 2) rather than shared snippets — but cross-feature sharing happens when a step is genuinely reusable.

### 2b. Existing typed clients

```
Glob: src/test/java/**/clients/**/*.java
```

For each `<Area>Client`, Read the public method signatures. If a method already covers the HTTP call the feature needs, REUSE it — do NOT create a parallel client. Two clients hitting the same endpoint is the #1 source of test-codebase rot.

### 2c. Existing fixtures

```
Glob: src/test/resources/fixtures/**/*.json
```

If a fixture covers the payload shape (possibly via the builder mutation pattern, see `references/fixtures.md`), reuse it. Mutate via builder rather than copying the JSON file.

### 2d. Existing schemas

```
Glob: src/test/resources/schemas/**/*.json
```

If a schema already validates the response shape, reference it. Author a new schema only when the response shape genuinely doesn't exist yet — and bump the schema version (not in-place edit) per Hard Rule S4.

## 3. Composing a new step

If a Gherkin line has no `REUSE_*` candidate but can be composed from ≥ 2 existing built-in + project steps, prefer composition over authoring a new primitive. On the API side this often looks like: a feature-scoped `@When` that internally calls two built-in steps via picocontainer-injected step classes.

## 4. Last-resort new step / client / fixture / schema

Tag the appropriate `NEW_*` ONLY when:

- No built-in step matches (Tiers 1–5 exhausted).
- No existing project artifact matches.
- No composition of existing steps satisfies the Gherkin intent.
- You have surfaced this gap in the output report with justification.

### Pattern for a new Java API step

```java
package com.hellen.tests.api.stepdefs.<area>;

import com.hellen.framework.bdd.ScenarioContext;
import com.hellen.tests.api.clients.<area>.<Area>Client;
import io.cucumber.java.en.When;

public class <Area>StepDefs {

    private final ScenarioContext ctx;
    private final <Area>Client client;

    public <Area>StepDefs(ScenarioContext ctx, <Area>Client client) {
        this.ctx = ctx;
        this.client = client;
    }

    @When("I rotate the API key for user {string}")
    public void rotateApiKey(String userKey) {
        // Genuinely new primitive: no built-in step for key rotation;
        // RotateRequest builder + client method also new — see NEW_CLIENT below.
        var response = client.rotateKey(userKey);
        ctx.setLastResponse(response);
    }
}
```

Key constraints:

- Inject `ScenarioContext` and the area's typed client via the constructor (Cucumber 4.x picocontainer wires them).
- The step def calls the typed client; the client owns `RestAssured.given()` (Hard Rule 4).
- NEVER call `RestAssured.given()` inside the step def itself.
- Persist response into `ScenarioContext.lastResponse` for `Then` steps to assert on.

### Justifying NEW_* artifacts in the report

For each new step / client / fixture / schema, the output report must include a line like:

```
- NEW_STEP "I rotate the API key for user {string}": no built-in step for key
  rotation in api-builtin-steps.txt (Tier 1); closest builtin
  HttpSteps#postWithBody requires manual body construction defeating the typed-
  client pattern; composition not possible without rotate primitive.
- NEW_CLIENT KeyRotationClient: no existing client under src/test/java/**/clients/
  covers /v2/keys/rotate; AuthClient is for /auth/* only, conflating would
  violate the area-per-client convention from Hard Rule 1.
```

If a reviewer can't tell from the justification why an existing artifact wouldn't work, the PR gets bounced. Be specific and name the tier / glob you consulted.

## Bootstrapping `.bdd-step-index/` (for framework/build maintainers)

This section is for the framework/build engineer who sets up the index; the agent never runs this. The plugin lives in the build configuration so the index regenerates automatically on `mvn install` and is never touched by agents.

```xml
<plugin>
  <groupId>com.hellen.framework</groupId>
  <artifactId>step-index-maven-plugin</artifactId>
  <version>1.0.0</version>
  <executions>
    <execution>
      <id>generate-step-index</id>
      <phase>generate-test-resources</phase>
      <goals><goal>index-steps</goal></goals>
      <configuration>
        <outputDir>${project.basedir}/.bdd-step-index</outputDir>
        <includeArtifacts>
          <!-- UI layer -->
          <artifact>com.hellen.framework.bdd:core-steps</artifact>
          <artifact>com.hellen.framework.bdd:web-steps</artifact>
          <!-- API layer (same repo, separate Maven artifact) -->
          <artifact>com.hellen.framework.bdd:api-steps</artifact>
        </includeArtifacts>
        <shardByArtifact>true</shardByArtifact>
        <indexFormat>pipe</indexFormat>
      </configuration>
    </execution>
  </executions>
</plugin>
```

Why pre-materialize at build time (same rationale as UI; reinforced because API surface is larger):

- **Least privilege at runtime** — agents never need Bash / unzip / mvn permissions; tool surface stays Read / Glob / Grep only.
- **Audit trail** — `.bdd-step-index/api-builtin-steps.txt` is human-diffable; reviewers see exactly which steps the agent had access to when authoring this PR.
- **Reproducibility** — the index is keyed off the locked dependency version. Same JAR → same index → same discovery outcome across dev / CI / agent runs.
- **No `~/.m2` coupling** — agents shouldn't peek inside the user's Maven cache; build artifacts under the project root are the proper interface.

## What the discovery output looks like

The final inventory block in the output report (also see `SKILL.md § Output report`):

```
Discovery inventory:
  Discovery source: index | catalog | javadoc | user-provided | unavailable
  Built-in step library: com.hellen.framework.bdd:api-steps:2.1.0
  Index file consulted: .bdd-step-index/api-builtin-steps.txt (412 entries)
  Built-in steps matched: 4
    - "the user {string} exists"               → UserSteps#userExists
    - "I POST {string} with body {string}"     → HttpSteps#postWithBody
    - "the response status is {int}"           → AssertionSteps#statusIs
    - "the response JSON path {string} equals {string}" → AssertionSteps#jsonPathEquals
  Project step defs matched: 1
    - "I sign in as the default admin user"    → AuthStepDefs#signInDefault
  Existing clients reused: 1   (AuthClient)
  Existing fixtures reused: 2  (auth/valid-login, auth/locked-account)
  Existing schemas reused: 1   (auth/login-response.json)
  Gherkin lines unverified against built-ins (Tier 5 only): <list or "none">
```

## Common mistakes

- **Searching only `src/test/java/`.** That misses the entire built-in library. Always Tier 1 (index) before §2 (project tree).
- **Treating `.bdd-step-index/` absence as "library has no steps".** Absence = bootstrap issue. Walk Tiers 2–5; surface in report. Never silently default to `NEW_STEP`.
- **Re-implementing a client.** Two `Client` classes hitting the same endpoint is the #1 source of test-codebase rot. Always do §2b before tagging `NEW_CLIENT`.
- **In-place schema edits.** Per Hard Rule S4, breaking changes get a new schema file. If you want to "tweak" an existing schema and it'd reject existing responses, that's a NEW_SCHEMA decision, not an edit.
- **Trying to run `unzip` / `mvn` / `javap`.** Build-time concerns. If the index is missing, the fix is to wire the Maven plugin (a build-engineer task), not to escalate the agent's privileges.
- **Skipping the report.** The whole point of the discovery output is to give reviewers an audit trail. "I just wrote new everything because I didn't find anything" is not reviewable; the inventory plus `Discovery source` tier makes it reviewable.
