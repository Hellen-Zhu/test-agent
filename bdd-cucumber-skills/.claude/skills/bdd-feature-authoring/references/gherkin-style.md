# Gherkin Style Guide

Patterns and counter-patterns for writing scenarios that read like specifications, not scripts.

## Declarative vs imperative

The single biggest stylistic lever. Declarative scenarios survive UI redesigns; imperative scenarios break on every change.

### Imperative (bad)

```gherkin
Scenario: Successful login
  Given I am on "https://example.com/login"
  When I click the element with css "#email-input"
  And I type "jane@example.com"
  And I click the element with css "#password-input"
  And I type "Correct-Horse-Battery-9!"
  And I click the element with css "button.btn-primary"
  Then the URL is "https://example.com/dashboard"
```

Problems: bound to selectors, bound to a specific URL, reads as a click-by-click recording. A button rename breaks the test even though the BEHAVIOUR didn't change.

### Declarative (good)

```gherkin
Scenario: Successful login redirects to dashboard
  Given I am on the "/login" page
  When I sign in as "jane@example.com" with a correct password
  Then I land on the dashboard within 2 seconds
```

Why this works: each step is at the level of USER INTENT. The step definition (in Java) knows how to fulfil "sign in as X" — and if the form changes, only the step def changes. The feature is untouched.

### Litmus test for declarative-ness

For each step, ask: "could a product manager read this without knowing the codebase?"

- "I fill the input with id email-input" → no (technical) → too imperative
- "I fill the email field with X" → maybe (acceptable for UI)
- "I sign in as X" → yes → ideal for declarative

API features get slightly more technical because HTTP IS the user's perspective:
- "I POST to /api/v1/auth/login with body { ... }" → acceptable for api/
- "The auth service authenticates jane@example.com" → too high-level for api/

Match the level to the layer.

## When to break declarative discipline

Some UI scenarios test PRECISE interactions (focus management, masked password toggle, button-disabled-during-flight). Those scenarios necessarily reference DOM concepts:

```gherkin
Scenario: Password field is masked by default and can be toggled
  Then the "password" field has type "password"
  When I click the show/hide password toggle
  Then the "password" field has type "text"
```

This is fine — the SCENARIO IS about the DOM-level rule. The principle is: be as declarative as the scenario's intent allows, no more, no less.

## Scenario Outline patterns

Use Outline ONLY when ≥ 3 sibling scenarios differ ONLY by data values. Below 3, just write the scenarios out — readability beats cleverness.

### Good use of Outline

```gherkin
Scenario Outline: Login fails with stable error code
  When I POST to "/api/v1/auth/login" with email "<email>" and password "<password>"
  Then the response status is 401
  And the response body has "error.code" equal to "invalid_credentials"

  Examples:
    | email             | password        |
    | jane@example.com  | wrong-password  |
    | nobody@example.com| anything        |
    | jane@example.com  |                 |
    | <too-long-email>  | Correct...      |
```

### Bad use of Outline

```gherkin
Scenario Outline: Login behaviour
  When I POST with "<input>"
  Then the response is "<output>"

  Examples:
    | input                                  | output |
    | { "email": "jane@x.com", ... }         | 200    |
    | { "email": "jane@x.com", "pw": "x" }   | 401    |
    | { "email": "" }                        | 400    |
```

Problems: collapses DIFFERENT behaviours (success, auth failure, validation failure) into one outline. Each row is conceptually a different scenario. Split.

**Rule**: Outline rows should be DATA variations of THE SAME outcome. If outcomes differ qualitatively, use separate scenarios.

## Data tables vs doc strings

### Data tables — structured tabular data

```gherkin
Given the following users exist:
  | email             | role  | locked |
  | jane@example.com  | user  | false  |
  | admin@example.com | admin | false  |
```

Use when: multiple records, same fields, structured. Step def maps to `List<Map<String,String>>` or a typed record via Cucumber 4.x `@DataTableType`.

### Doc strings — opaque blob input

```gherkin
When I POST to "/api/v1/orders" with body:
  """
  {
    "items": [{"sku": "ABC-1", "qty": 2}],
    "shipTo": {"zip": "94110"}
  }
  """
```

Use when: payload is a single JSON / XML / HTML chunk. Avoid stuffing JSON into a one-liner — doc strings keep it readable AND the test machinery treats it as a single string arg.

## Background — use sparingly

`Background` runs before EVERY scenario in the file. It is NOT shorthand for "setup". Rules:

- Use it only when ALL scenarios in the file truly share the setup.
- Keep it short (≤ 4 steps). If it grows long, the feature file probably needs splitting.
- NEVER put assertions in `Background` — only `Given` steps.
- NEVER do scenario-specific setup in `Background`.

### When NOT to use Background

If two of five scenarios need a different `Given`, just inline the `Given`s into the scenarios that need them. Don't sneak conditionals into background.

## Step phrasing conventions

| Phrase pattern | Use for |
|----------------|---------|
| `Given I am on the "/path" page` | UI starting point |
| `Given a registered user "..."` | API precondition |
| `Given the following <entities>:` | data setup via table |
| `When I POST to "..." with body:` | API action |
| `When I <user-intent verb> ...` | UI declarative action |
| `Then the response status is <code>` | API outcome |
| `Then the response body has "<path>" equal to "<value>"` | API field assertion |
| `Then I see <observable>` | UI declarative outcome |
| `Then the "..." field has <attribute> "<value>"` | UI specific DOM outcome |

Stick to these so step defs are reusable across feature files.

## Numbers, quoting, and special characters

- Wrap user-facing strings in double quotes: `"jane@example.com"`.
- Bare numbers stay unquoted: `Then the response status is 401`.
- Cucumber 4.x Expressions handle `{string}`, `{int}`, `{float}`, `{word}` — match these in step defs.
- For regex-based step defs (avoid unless needed): escape `(`, `)`, `.`, `?` properly.
