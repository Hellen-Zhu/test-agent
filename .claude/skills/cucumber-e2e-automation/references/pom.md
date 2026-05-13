# Page Object Model

How to structure Page Objects so they're reusable, refactor-safe, and don't lock the test suite into UI internals.

## Anatomy of a Page Object

```java
package com.hellen.tests.e2e.pages.auth;

import com.microsoft.playwright.Locator;
import com.microsoft.playwright.Page;

public class LoginPage {

    private final Page page;

    // --- Locators (fields, not inline) ---
    private final Locator emailInput;
    private final Locator passwordInput;
    private final Locator submitButton;
    private final Locator passwordToggle;
    private final Locator inlineError;
    private final Locator emailError;

    public LoginPage(Page page) {
        this.page = page;
        this.emailInput     = page.getByTestId("login-email");
        this.passwordInput  = page.getByTestId("login-password");
        this.submitButton   = page.getByRole(com.microsoft.playwright.options.AriaRole.BUTTON,
                                 new Page.GetByRoleOptions().setName("Sign in"));
        this.passwordToggle = page.getByTestId("login-password-toggle");
        this.inlineError    = page.getByTestId("login-error");
        this.emailError     = page.getByTestId("login-email-error");
    }

    // --- Navigation ---

    public LoginPage open() {
        page.navigate("/login");
        page.waitForURL("**/login");
        return this;
    }

    // --- Actions (return this or next page) ---

    public LoginPage fillEmail(String email) {
        emailInput.fill(email);
        return this;
    }

    public LoginPage fillPassword(String password) {
        passwordInput.fill(password);
        return this;
    }

    public LoginPage submit() {
        submitButton.click();
        return this;
    }

    public DashboardPage submitExpectingSuccess() {
        submitButton.click();
        page.waitForURL("**/dashboard");
        return new DashboardPage(page);
    }

    public LoginPage togglePasswordVisibility() {
        passwordToggle.click();
        return this;
    }

    // --- State queries (no assertions!) ---

    public boolean submitIsDisabled() {
        return submitButton.isDisabled();
    }

    public String inlineErrorText() {
        return inlineError.textContent();
    }

    public String emailErrorText() {
        return emailError.textContent();
    }

    public String passwordFieldType() {
        return passwordInput.getAttribute("type");
    }

    // --- Locator exposers (for retrying assertions in step defs) ---

    public Locator submitButton()  { return submitButton; }
    public Locator inlineError()   { return inlineError; }
    public Locator emailError()    { return emailError; }
}
```

This is the canonical shape. Each section has a purpose; mixing them creates the Page Objects that turn into a maintenance burden.

## Method return-type discipline

| Action type | Return |
|-------------|--------|
| Fill / click on this page, NO navigation | `this` (the same POM, enables chaining) |
| Click that triggers navigation | NEW Page Object for the destination |
| Read state | `boolean` / `String` / `int` / `Locator` |
| Open the page | `this` (after waiting for URL) |

NEVER `void`. Even a click that doesn't navigate returns `this` so step defs can chain:

```java
loginPage.fillEmail("jane@example.com")
         .fillPassword("Correct-Horse-Battery-9!")
         .submit();
```

vs the void-return alternative:

```java
loginPage.fillEmail("jane@example.com");
loginPage.fillPassword("Correct-Horse-Battery-9!");
loginPage.submit();
```

Same number of lines, less composable. Chaining wins.

## Why no assertions in Page Objects

A Page Object that asserts couples test FACT (what the page looks like) with test JUDGEMENT (whether that's right). Consequences:

- Hard to reuse POM in a different scenario that expects a DIFFERENT outcome.
- Failure messages are generic ("assertion in LoginPage.fillEmail failed"), not specific to the scenario.
- Tests that try to verify "negative" behaviour (the inline error does NOT appear) can't reuse a POM that asserts presence.

POMs expose state. Step defs decide what's right.

## Two flavors of state methods

For non-retrying logical checks (snapshot of current state):

```java
public boolean submitIsDisabled() {
    return submitButton.isDisabled();
}
```

Step def:
```java
assertThat(loginPage.submitIsDisabled(), is(true));
```

For retrying assertions (the value will become correct soon):

```java
public Locator submitButton() {
    return submitButton;
}
```

Step def:
```java
import static com.microsoft.playwright.assertions.PlaywrightAssertions.assertThat;

assertThat(loginPage.submitButton()).isDisabled();
```

The latter retries internally (auto-wait). Use it for anything that could be in-flight.

Convention: a method returning a boolean asks "right now?". A method returning a `Locator` asks "eventually?". Step defs pick which one matches the scenario.

## Where to put NAVIGATION

Two valid patterns:

### Pattern A: source page produces destination page

```java
public DashboardPage submitExpectingSuccess() {
    submitButton.click();
    page.waitForURL("**/dashboard");
    return new DashboardPage(page);
}
```

Use when the navigation is the EXPECTED outcome. The method signature documents the flow.

### Pattern B: step def constructs the destination page

```java
@When("I submit the login form")
public void submit() {
    ctx.loginPage().submit();   // returns this
}

@Then("I land on the dashboard")
public void iLandOnDashboard() {
    ctx.page().waitForURL("**/dashboard");
    ctx.setDashboardPage(new DashboardPage(ctx.page()));
}
```

Use when the navigation is the ASSERTION (the scenario tests whether navigation happens).

Either pattern is fine. Pick one per Page Object and stick to it.

## Inheritance vs composition

Avoid `BasePage` with shared helpers — it accumulates kitchen-sink methods. Prefer COMPOSITION:

```java
public class Header {
    private final Locator menu;
    private final Locator search;
    public Header(Page page) { ... }
    public void openAccountMenu() { menu.click(); }
}

public class LoginPage {
    private final Header header;
    public LoginPage(Page page) {
        this.header = new Header(page);
        ...
    }
    public Header header() { return header; }
}
```

Step def: `loginPage.header().openAccountMenu()`. Header is reused across all pages without inheritance gymnastics.

## When to split a Page Object

Split into multiple POMs when:
- The page has TWO distinct flows (e.g. login + signup on one URL → `LoginPage`, `SignupPage`, even if they share a URL).
- The page has a modal/dialog → separate POM for the modal.
- Locators top 12+ — usually a sign of mixed responsibilities.

Don't split when:
- The page has many fields but ONE flow (a long form is still one POM).
- The split is just to "balance file sizes" — fewer, well-bounded POMs > many tiny ones.

## Anti-patterns

### Anti-pattern: setters that return void

```java
public void setEmail(String email) { emailInput.fill(email); }   // ← can't chain
```

Always return `this`.

### Anti-pattern: assertion inside POM

```java
public void fillEmail(String email) {
    emailInput.fill(email);
    assertThat(emailInput.inputValue()).isEqualTo(email);   // ← removes test agency
}
```

Trust Playwright's fill; let step defs decide what to verify.

### Anti-pattern: business logic in POM

```java
public boolean userCanCheckout() {
    return cartHasItems() && paymentValid() && shippingSet();
}
```

This is test logic, not page state. Move to step def or to a helper utility class.

### Anti-pattern: exposing `Page` from POM

```java
public Page page() { return page; }   // ← invitation to bypass the POM
```

If you find step defs calling `loginPage.page().click(...)`, the POM is missing a method. Add the method.

### Anti-pattern: locators defined inline in methods

```java
public void fillEmail(String email) {
    page.getByTestId("login-email").fill(email);   // ← undiscoverable
    // Next method needs the same locator → duplicated
}
```

Put locators in fields so they're all visible at the top of the class.
