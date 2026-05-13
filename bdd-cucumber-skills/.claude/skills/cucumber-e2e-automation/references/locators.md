# Locator Strategy

Picking the right locator is the single biggest determinant of test stability. Hard Rule 8 in SKILL.md sets a strict priority order — this document explains why and shows how to apply it.

## Priority order (mandatory)

```
1. getByTestId          ← preferred (decoupled from UI text & structure)
2. getByRole            ← preferred when no testid (accessible & resilient)
3. getByLabel           ← for form fields with associated <label>
4. getByText            ← for unique buttons/links by display text
5. getByPlaceholder     ← weak, but acceptable for inputs without labels
6. CSS                  ← only when none of the above work
7. XPath                ← LAST resort; requires comment + issue link
```

Going BELOW position 2 (i.e. dropping from testid/role to text or lower) requires a comment in the Page Object explaining why:

```java
// FALLBACK: no data-testid on the legacy footer link; targeting by text.
// Tracked in issue #1234 — add data-testid="footer-privacy" then upgrade.
private final Locator privacyLink = page.getByText("Privacy Policy");
```

## Why this order

| Locator | Survives... | Breaks on... |
|---------|------------|--------------|
| testid  | text changes, restyling, refactors of DOM | testid removal (we own this) |
| role + name | text changes within reason, restyling | accessibility regressions (which we want to catch) |
| label   | restyling | label rewording |
| text    | restyling | any copy change |
| placeholder | restyling, label changes | placeholder change |
| CSS     | nothing reliable | class renaming, restructuring |
| XPath   | absolutely nothing | any DOM tweak |

The priority is sorted by RESILIENCE against benign UI changes. Tests that fail because someone changed a button color don't catch bugs — they erode trust.

## Examples by element type

### Buttons

```java
// 1. Best: testid
page.getByTestId("login-submit");

// 2. Acceptable: role + accessible name
page.getByRole(BUTTON, new Page.GetByRoleOptions().setName("Sign in"));

// 3. Fallback: text
page.getByText("Sign in", new Page.GetByTextOptions().setExact(true));

// ❌ Avoid
page.locator(".btn.btn-primary[type=submit]");
page.locator("//button[contains(@class,'primary') and text()='Sign in']");
```

### Form inputs

```java
// 1. Best: testid
page.getByTestId("login-email");

// 2. Acceptable: label association (<label for="email">)
page.getByLabel("Email");

// 3. Weak: placeholder
page.getByPlaceholder("you@example.com");

// ❌ Avoid
page.locator("input#email");
page.locator("//input[@name='email']");
```

### Links

```java
// 1. Best: testid
page.getByTestId("nav-orders");

// 2. Acceptable: role
page.getByRole(LINK, new Page.GetByRoleOptions().setName("Orders"));

// 3. Fallback: text within a scope
page.locator("nav").getByText("Orders");
```

### Lists and tables

For "the 3rd row in the orders table":

```java
// Bad: positional CSS — breaks on any reorder
page.locator("table.orders tr:nth-child(3)");

// Good: locate by content, then chain
page.getByRole(ROW, new Page.GetByRoleOptions().setName("Order #1234"));

// Acceptable: testid on rows
page.getByTestId("order-row-1234");
```

Never rely on N-th-child unless the order is part of the test (e.g. "newest first").

## Scoping (chained locators)

Use `.locator(within)` to limit scope to a region:

```java
Locator orderRow = page.getByTestId("order-row-1234");
orderRow.getByRole(BUTTON, new Page.GetByRoleOptions().setName("Cancel")).click();
```

Reads as: "in the row for order 1234, click the Cancel button". This survives table redesigns.

## Strict mode and unique locators

Playwright's `Locator` is "strict" by default — if it matches multiple elements, the operation fails. This is a FEATURE, not a bug. It surfaces ambiguity at test-write time, not at run time.

If a locator matches multiple intentionally (e.g. all "Delete" buttons), use `.nth(i)` or filter:

```java
page.getByRole(BUTTON, new Page.GetByRoleOptions().setName("Delete")).first().click();

// Better: filter to a specific row
page.getByRole(ROW)
    .filter(new Locator.FilterOptions().setHasText("ABC-1"))
    .getByRole(BUTTON, new Page.GetByRoleOptions().setName("Delete"))
    .click();
```

`.first()` is OK when there's truly no need to distinguish; filtered chain is BETTER when you mean a specific row.

## Locator over `page.locator(css)`

Always prefer the typed methods over raw CSS:

```java
// ❌ raw CSS — bypasses all the niceties
page.locator(".sign-in-button").click();

// ✅ typed method — auto-waits, retries, strict mode
page.getByRole(BUTTON, new Page.GetByRoleOptions().setName("Sign in")).click();
```

The typed methods are not just sugar — they enable Playwright's auto-wait and assertions.

## Asking for testids

If the app doesn't have data-testid attributes, the BEST first step is to ask the frontend team to add them. A typical day-1 contribution to a UI repo from the test team is a `data-testid` PR.

While waiting, use role + name. Avoid CSS entirely unless absolutely necessary.

## Anti-patterns

### Anti-pattern: smart selectors

```java
page.locator("xpath=//button[contains(@class, 'primary') and not(@disabled) and ancestor::form[@id='login']]");
```

Long, brittle, impossible to debug. Decompose into chained locators or push for a testid.

### Anti-pattern: comment papering over a fragile locator

```java
// This is fragile but works for now
page.locator("body > div > div.modal-overlay > div:nth-child(2) > button").click();
```

The "for now" comment is a deferred liability. Either upgrade to a stable locator or accept that this test will be flaky.

### Anti-pattern: scoping with non-semantic CSS

```java
page.locator(".container").locator(".inner").locator(".target").click();
```

Three brittle locators chained = three brittle test failures waiting to happen. Find ONE semantic anchor and scope from there.

## Quick grep

To audit locator usage:

```bash
# Find non-preferred locators
grep -rn "page.locator(" src/test/java/com/hellen/tests/e2e/
grep -rn "xpath=" src/test/java/com/hellen/tests/e2e/

# Find inline locators (should be in fields)
grep -rn "getByTestId\|getByRole" src/test/java/com/hellen/tests/e2e/stepdefs/
# ← if results found, locators are in step defs instead of POMs (violates Hard Rule 5)
```
