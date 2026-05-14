# Snippets

A **snippet** in this codebase is a custom Cucumber step (`@Given/@When/@Then`) whose body composes other steps — built-in framework steps and/or other snippets — into a higher-level business flow. Snippets are the team's chosen abstraction for reuse; they replace the Page Object Model used by other projects.

## What a snippet is — and isn't

| A snippet IS | A snippet IS NOT |
|--------------|------------------|
| A high-level `@When`/`@Given` annotated method | A Java helper method outside a step class |
| Body that calls other step methods via picocontainer injection or `executeStep` | Body that touches `Page` / `Locator` / `BrowserContext` directly |
| Reusable across multiple `.feature` files | Inline-only logic used once in one feature |
| Named after a business action ("sign in as admin") | Named after a UI mechanic ("click submit button") |

If the body of your candidate method calls `page.locator(...)` or `framework.click(...)` directly, it's a **primitive step**, not a snippet. Primitives belong in the built-in step library (or, last resort, a new Java step) — never in `snippets/`.

## File location

```
src/test/java/com/<org>/tests/e2e/snippets/<area>/<Area>Snippets.java
```

Where `<area>` matches the feature folder structure (auth, checkout, productList, etc.). One `<Area>Snippets.java` class per area; multiple snippet methods inside.

**Verify the existing convention first.** Glob `src/test/java/**/snippets/**/*.java`. If the project uses a different layout (e.g., `flows/` instead of `snippets/`, or one class per snippet), follow that. Do not introduce a parallel convention.

## Anatomy

```java
package com.hellen.tests.e2e.snippets.auth;

import com.hellen.framework.bdd.steps.NavigationSteps;
import com.hellen.framework.bdd.steps.FormSteps;
import com.hellen.framework.bdd.steps.AssertionSteps;
import io.cucumber.java.en.When;

public class AuthSnippets {

    private final NavigationSteps navigation;
    private final FormSteps form;
    private final AssertionSteps assertions;

    // Cucumber picocontainer injects these per-scenario
    public AuthSnippets(NavigationSteps navigation,
                        FormSteps form,
                        AssertionSteps assertions) {
        this.navigation = navigation;
        this.form = form;
        this.assertions = assertions;
    }

    @When("I sign in as the default admin user")
    public void signInAsDefaultAdmin() {
        navigation.openPage("loginPage");           // built-in: navigates to _baseUrl from locator JSON
        form.fillByKey("loginPage.emailInput", "admin@example.com");
        form.fillByKey("loginPage.passwordInput", "<from-fixture>");
        form.clickByKey("loginPage.submitButton");
        assertions.urlContains("/dashboard");        // wait until navigated
    }

    @When("I sign in as user {string}")
    public void signInAs(String userKey) {
        UserFixture user = UserFixture.load(userKey);
        navigation.openPage("loginPage");
        form.fillByKey("loginPage.emailInput", user.email());
        form.fillByKey("loginPage.passwordInput", user.password());
        form.clickByKey("loginPage.submitButton");
        assertions.urlContains("/dashboard");
    }
}
```

What's happening here:

- The class is a step-def class (it has `@When`-annotated methods Cucumber will discover).
- The constructor receives built-in step classes via picocontainer DI — Cucumber 4.x creates a fresh instance per scenario.
- Each snippet method's body calls **only** other step methods. No `Page`, no `Locator`, no raw selectors.
- Locators are passed by KEY (`"loginPage.emailInput"`) — the built-in `form.fillByKey` looks them up in the JSON catalog. Snippets DO NOT touch the catalog directly.
- Test data (`UserFixture`) comes from fixtures, not hardcoded — fixtures are documented in `cucumber-api-automation`.

## When to author a new snippet

Author a new snippet when, during Mapping phase (SKILL.md § 3), you tag a Gherkin line `NEW_SNIPPET`. Concretely:

- The line describes a multi-action business flow ("complete checkout", "sign in as X", "add 3 items to cart").
- You can construct the body from ≥ 2 calls to existing steps (built-in or project).
- The flow is or will be reused across multiple features.

If only one feature uses the flow, still author the snippet — single-feature reuse is also valid. Inline composition inside a one-off step def is what creates the duplication you'll regret in 6 months.

## When NOT to author a snippet

- The Gherkin line maps 1:1 to a built-in step → tag `REUSE_BUILTIN`, do nothing.
- The Gherkin line maps 1:1 to an existing project step → tag `REUSE_PROJECT`, do nothing.
- The flow needs a primitive action that doesn't exist in the built-in library → tag `NEW_STEP`, see `step-discovery.md` § "Last-resort new step". Composing primitives into snippets is the whole reason snippets exist; if the primitives don't exist yet, fix that first.

## Composition discipline

A snippet that has grown to ≥ 8 step calls is a sign of one of:

- The Gherkin line itself is too coarse — split it into two scenarios.
- The body contains hidden sub-flows that deserve their own snippets — extract them and call them by name.
- The built-in library is missing a primitive that would collapse multiple lines — raise upstream.

Long snippets aren't forbidden by a hard rule, but they're a code-smell worth flagging in the output report.

## Snippets calling snippets

Allowed and encouraged for genuinely nested flows:

```java
@When("I complete checkout as the default admin user")
public void completeCheckoutAsDefaultAdmin() {
    authSnippets.signInAsDefaultAdmin();         // snippet → snippet
    cartSnippets.addItemFromCatalog("SKU-001");
    checkoutSnippets.completeWithDefaultCard();
}
```

Guard against circular calls (A → B → A). Cucumber doesn't detect them; you'll get a stack overflow at runtime in the worst case.

## Failure modes

- **Symptom**: Snippet body has `page.locator(...)`. → **Cause**: Drifted into primitive territory. → **Fix**: Move the locator interaction into the built-in `FormSteps` (or equivalent); call that from the snippet.
- **Symptom**: Two snippets do nearly the same thing with one parameter differing. → **Cause**: Forgot Cucumber parameter substitution. → **Fix**: Combine into one snippet with a `{string}` parameter; delete the duplicate.
- **Symptom**: Snippet "works in isolation, fails when called by another snippet". → **Cause**: Assuming starting page state instead of navigating explicitly. → **Fix**: Every snippet should begin with explicit navigation or state assertion; never assume the caller left you on the right page.
- **Symptom**: Picocontainer injection error at scenario start. → **Cause**: Constructor parameter is a class Cucumber can't construct (concrete class with non-trivial constructor, abstract class, etc.). → **Fix**: Snippets should only inject other step-def classes or framework-provided services that Cucumber 4.x's picocontainer can wire — verify by checking what existing snippets inject.
