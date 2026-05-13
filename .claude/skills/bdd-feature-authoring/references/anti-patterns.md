# Anti-Patterns Checklist

Common Gherkin smells with concrete fixes. Run through this list before declaring a feature file "done".

## AP-1: The script

```gherkin
Scenario: Login
  When I click "Sign in"
  And I type "jane@example.com"
  And I tab to the password field
  And I type "Correct-Horse-Battery-9!"
  And I press Enter
  And I wait 2 seconds
  Then I am logged in
```

**Smell**: reads like a Selenium recorder dump. Bound to keystrokes. The `wait 2 seconds` is a code smell on top of a code smell.

**Fix**: Replace with intent.

```gherkin
Scenario: Valid credentials log the user in
  When I sign in as "jane@example.com" with a correct password
  Then I am logged in within 2 seconds
```

The step def now owns HOW to sign in (clicks, types, network), and includes its own wait predicate.

## AP-2: The bus station (`And`-chain runaway)

```gherkin
Scenario: Checkout
  Given I have an account
  And I have items in my cart
  And my payment method is on file
  And my shipping address is set
  And I have a valid coupon
  When I click checkout
  And I confirm
  And I wait
  Then I see "Order placed"
  And the cart is empty
  And I receive an email
  And the inventory is decremented
  And the analytics event fires
```

**Smell**: 13 steps; mixes setup, action, and 4 different outcomes.

**Fix**: Move shared `Given`s to `Background`. Split the `Then` block — each scenario asserts ONE outcome.

```gherkin
Background:
  Given a customer with a cart of items, payment, address, and a valid coupon

Scenario: Successful checkout shows confirmation
  When I confirm checkout
  Then I see "Order placed"

Scenario: Successful checkout empties the cart
  When I confirm checkout
  Then the cart is empty

Scenario: Successful checkout decrements inventory
  When I confirm checkout
  Then the inventory for each item decreases by the ordered quantity
```

Three small scenarios > one mega-scenario. Each fails for a clear, distinct reason.

## AP-3: The conjoined twin

```gherkin
Scenario: User can sign up and log in
  When I register a new account
  And I sign in with that account
  Then I see the dashboard
```

**Smell**: scenario title contains "and". Two distinct flows fused.

**Fix**: Split into two scenarios. If "log in immediately after registration" is itself a feature, give it its own scenario with a clear name like "Newly registered user can immediately sign in".

## AP-4: Hidden assertion in setup

```gherkin
Background:
  Given I create a user "jane@example.com"
  And the API returns 200
```

**Smell**: an assertion (`returns 200`) inside `Background`. Background is for PRECONDITIONS, not verification.

**Fix**: Move the assertion out, OR encapsulate the precondition's success in the step verb itself:

```gherkin
Background:
  Given a registered user "jane@example.com"  # step def fails internally if creation didn't succeed
```

The step def can still assert internally — but the FEATURE FILE should not show assertions in Given.

## AP-5: Time-of-day in `When`

```gherkin
When I click the button
And I wait 5 seconds
Then the loading spinner is gone
```

**Smell**: arbitrary sleep. Tests becomes both slow and flaky.

**Fix**: Express the wait as a semantic condition.

```gherkin
When I click the button
Then the loading spinner disappears
```

The step def for "disappears" uses Playwright `waitFor` or REST Assured's response-completion. NEVER `Thread.sleep`.

## AP-6: Selector pollution

```gherkin
When I click the element with locator "div.header > nav > ul > li:nth-child(3) > a"
```

**Smell**: feature file knows CSS internals. The next UI redesign breaks every scenario.

**Fix**: Push selectors into Page Objects (E2E) or use accessible role/text in the feature.

```gherkin
When I open the "Account" menu
```

See `cucumber-e2e-automation/references/locators.md` for the priority order.

## AP-7: Outline abuse

```gherkin
Scenario Outline: <whatever>
  When I do "<x>"
  Then "<y>" happens

  Examples:
    | x                | y               |
    | valid login      | dashboard       |
    | invalid login    | error message   |
    | locked account   | 423 response    |
```

**Smell**: outline rows are conceptually DIFFERENT scenarios. They behave differently, have different outcomes, hit different code paths.

**Fix**: Three separate scenarios. Outline is for DATA variation of the SAME outcome.

## AP-8: Shared state between scenarios

```gherkin
Scenario: Create order
  When I POST a new order
  Then I get an order id

Scenario: Cancel the order   # ← which order?
  When I DELETE /orders/<id>  # ← <id> from where?
  Then the order is cancelled
```

**Smell**: scenario 2 silently depends on scenario 1's side effect.

**Fix**: Either (a) merge into one scenario, or (b) give scenario 2 its own setup.

```gherkin
Scenario: An existing order can be cancelled
  Given an order "ABC-1" exists
  When I DELETE "/orders/ABC-1"
  Then the order is cancelled
```

Scenarios MUST be independently runnable. Cucumber's parallel execution will reorder them.

## AP-9: Comment instead of structure

```gherkin
# This test verifies the 5-attempt lockout including the time window
# Make sure to clean the rate-limiter cache before running
# Note: requires SMTP fake to be up
Scenario: Lockout after 5 failures
  ...
```

**Smell**: comments carrying setup info / dependencies. The information rots and is invisible to tooling.

**Fix**:
- Setup → `Background:` or `@Before` hook in step defs.
- Dependencies → CI job config or skip-condition.
- Description of the scenario → put it in the SCENARIO TITLE.

```gherkin
Scenario: Account locks after 5 failed attempts in a 10-minute window
  ...
```

## AP-10: Magical step verbs

```gherkin
When everything works
Then it succeeds
```

**Smell**: vague step text. Either the step def is doing too much, or the scenario itself has no concrete claim.

**Fix**: Be specific. If the scenario can't be made specific, it doesn't belong in the suite.

## Pre-commit checklist

Run through these before saving a `.feature` file:

- [ ] Title is outcome, not action.
- [ ] No "and" in scenario titles.
- [ ] Each scenario has `@story-<id>` and `@<area>`.
- [ ] No `Thread.sleep` / `wait <N> seconds` step text.
- [ ] No CSS selectors or HTML attribute strings (unless an explicit UI DOM test).
- [ ] No `Then` step in Background.
- [ ] Background ≤ 4 steps OR omitted.
- [ ] No `And` chain > 5 in any single scenario block.
- [ ] No scenario references state created by another scenario.
- [ ] Outline only used when ≥ 3 sibling scenarios differ purely by data.
- [ ] Doc strings used for JSON; data tables for tabular inputs.
