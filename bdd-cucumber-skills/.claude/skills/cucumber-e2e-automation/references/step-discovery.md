# Step Discovery

Before authoring any new Java code for a feature, you MUST search three sources in this order and record the findings. This is the Discovery phase from `SKILL.md § Core Procedure § 2`. Skipping it is the most common review-rejection cause.

## The reuse hierarchy

```
1. Built-in step (Maven dependency)        ← search first
2. Existing project step or snippet         ← then this
3. Compose into a new snippet               ← then this
4. Author a new Java step                   ← last resort, justify
```

Each downward step requires evidence the upper tiers don't satisfy the need. Recording that evidence in the output report is what makes the discipline reviewable.

## 1. Discovering built-in steps

The built-in BDD framework ships as a Maven dependency.

### 1a. Identify the artifact

Read `pom.xml`. Look for `<dependency>` entries with `groupId` matching your org's internal namespace (e.g. `com.hellen.framework.*`, `com.<org>.bdd.*`). Common artifact name patterns:

- `*-bdd-core`
- `*-bdd-steps`
- `*-test-framework`
- `*-cucumber-steps`

Note the exact `groupId:artifactId:version` triple — you'll need it in the inventory report.

### 1b. Read step source code

Option A — sources JAR (preferred):

```
~/.m2/repository/<groupId-as-path>/<artifactId>/<version>/<artifactId>-<version>-sources.jar
```

Replace dots in `groupId` with `/`. Example: `com.hellen.framework.bdd:core-steps:2.1.0` lives at:

```
~/.m2/repository/com/hellen/framework/bdd/core-steps/2.1.0/core-steps-2.1.0-sources.jar
```

Use Bash to extract & grep:

```bash
SOURCES_JAR=~/.m2/repository/com/hellen/framework/bdd/core-steps/2.1.0/core-steps-2.1.0-sources.jar
TMPDIR=$(mktemp -d)
unzip -q "$SOURCES_JAR" -d "$TMPDIR"
grep -rE '@(Given|When|Then)\(' "$TMPDIR" | head -50
```

Then Read individual `.java` files for ones that look relevant. Pay attention to the regex inside the annotation — that's what matches Gherkin lines.

Option B — sources JAR absent:

The dependency may not publish sources. Fallbacks:

1. **Ask the user for the step catalog URL** — many internal BDD frameworks publish a generated docs site or Confluence page listing all available steps.
2. **`javap -p` the class JAR** for method signatures only (won't show the annotation regex though, so this is rarely sufficient).
3. **Surface the gap in your output report.** Don't silently degrade to "I'll just author a new step" — that's how duplication accumulates.

### 1c. Match Gherkin lines to built-in steps

For each Gherkin line in your feature, build a candidate list from 1b. The match can be exact-string or via parameter regex — e.g. a built-in step `@When("I click {string}")` matches the Gherkin line `When I click "Submit"`.

Record matches in the inventory:

```
REUSE_BUILTIN candidates:
  "When I navigate to {string}"
    → com.hellen.framework.bdd.steps.NavigationSteps.navigateTo
  "When I fill {string} with {string}"
    → com.hellen.framework.bdd.steps.FormSteps.fillField
  ...
```

## 2. Discovering existing project steps

```bash
# All step-def files
find src/test/java -path '*/steps/*' -o -path '*/stepdefs/*' -o -path '*/snippets/*' | grep -E '\.java$'

# All step annotations
grep -rE '@(Given|When|Then)\(' src/test/java/ | head -100
```

For each Gherkin line still unmatched after Discovery phase 1, check whether any project step or snippet matches.

### Distinguishing snippets from primitives

A hit from `grep -rE '@When\(' src/test/java/` could be:

- A **primitive step** (touches `Page`/`Locator` directly — should have stayed in the built-in library, but lives here for project-specific reasons).
- A **snippet** (calls other steps; the team's preferred pattern).

Open the file and read the method body. If the body is `≥ 2` calls to other step classes injected via the constructor, it's a snippet. If the body uses `Page` / `Locator` / framework primitives directly, it's a primitive step.

Both are reuse candidates — tag the inventory accordingly:

```
REUSE_PROJECT candidates:
  "When I sign in as the default admin user"
    → com.hellen.tests.e2e.snippets.auth.AuthSnippets.signInAsDefaultAdmin  [snippet]
  "When I dismiss the cookie banner"
    → com.hellen.tests.e2e.stepdefs.common.CommonSteps.dismissCookieBanner  [primitive]
```

## 3. Composing a new snippet

If a Gherkin line has no `REUSE_*` candidate but can be composed from ≥ 2 existing steps, tag it `NEW_SNIPPET` and author a snippet per `references/snippets.md`.

## 4. Last-resort new step

Tag `NEW_STEP` ONLY when:

- No built-in step matches.
- No existing project step matches.
- No composition of existing steps satisfies the Gherkin intent (composition needs an atomic action that genuinely doesn't exist).
- You have surfaced this gap in the output report with justification.

### Pattern for a new Java step

```java
package com.hellen.tests.e2e.stepdefs.<area>;

import com.hellen.framework.bdd.LocatorLoader;
import com.hellen.framework.bdd.ScenarioContext;
import com.microsoft.playwright.Locator;
import io.cucumber.java.en.When;

public class <Area>Steps {

    private final ScenarioContext ctx;       // framework-provided; holds Page, BrowserContext
    private final LocatorLoader locators;    // framework-provided; resolves JSON catalog keys

    public <Area>Steps(ScenarioContext ctx, LocatorLoader locators) {
        this.ctx = ctx;
        this.locators = locators;
    }

    @When("I drag the {string} slider to {int}")
    public void dragSliderTo(String locatorKey, int targetValue) {
        // Genuinely new primitive: no built-in step for slider drag.
        Locator slider = locators.resolve(locatorKey, ctx.page());
        // …drag logic using Playwright's Locator.dragTo(...)
    }
}
```

Key constraints:

- Inject framework services via the constructor (Cucumber 4.x picocontainer wires them).
- Use `LocatorLoader.resolve(key, page)` to fetch from the JSON catalog — NEVER a raw selector string.
- Keep the step truly primitive: one user-perceptible action per step. If you find yourself chaining 3 things, you wanted a snippet, not a step.

### Justifying NEW_STEP in the report

For each new step, the output report must include a line like:

```
- "I drag the {string} slider to {int}": no built-in step for slider drag;
  closest built-in (FormSteps.fillField) only handles text inputs; composition
  via @AndStep chain not possible without slider primitive.
```

If a reviewer can't tell from the justification why a built-in or snippet wouldn't work, the PR gets bounced. Be specific.

## What the discovery output looks like

The final inventory block in the output report (also see `SKILL.md § Output report`):

```
Discovery inventory:
  Built-in step library: com.hellen.framework.bdd:core-steps:2.1.0
  Sources JAR available: yes (~/.m2/.../core-steps-2.1.0-sources.jar)
  Built-in steps matched: 6
    - "I navigate to {string}"     → NavigationSteps.navigateTo
    - "I click {string}"           → FormSteps.click
    - "I fill {string} with {string}" → FormSteps.fillField
    - "I should see {string}"      → AssertionSteps.shouldSeeText
    - "the page URL contains {string}" → AssertionSteps.urlContains
    - "I am on the {string} page"  → NavigationSteps.openPage
  Project steps matched: 2
    - "I sign in as the default admin user"
        → AuthSnippets.signInAsDefaultAdmin  [snippet]
    - "I dismiss the cookie banner"
        → CommonSteps.dismissCookieBanner    [primitive]
  Gherkin lines unmatched: 1
    - "I drag the {string} slider to {int}"  → NEW_STEP (see justification below)
```

## Common mistakes

- **Searching only `src/test/java/`.** That misses the entire built-in library. Always Discovery 1 before Discovery 2.
- **Grepping for the Gherkin line literally.** Built-in steps use parameter regex (`@When("I click {string}")`). A grep for `"I click "Submit""` returns nothing — grep for `"@When("I click "` or use a broader regex.
- **Treating snippet hits as primitives.** Opens the door to layering violations later. Always read the body of a project-step match to classify it correctly.
- **Skipping the report.** The whole point of the discovery output is to give reviewers an audit trail. "I just wrote new steps because I didn't find anything" is not reviewable; the inventory makes it reviewable.
