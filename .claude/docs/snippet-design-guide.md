# Snippet Design Guide

A design guide for creating and reusing genie snippets — both UI (genie-playwright) and API (genie-rest) layers.

---

## Agent Boundary

This guide is implementation-oriented and should be read by automation agents only.

| Agent | Allowed use |
|-------|-------------|
| `automation-agent` | Use the implementation guidance: existing snippet reuse, Cucumber binding checks, snippet files, Java steps, page objects, API clients, fixtures, and helpers. |

`bdd-case-design-agent` must not read this guide. Its business step-pattern design methodology lives in `~/.claude/docs/bdd-case-design-methodology.md`; exact feature generation standards live in `~/.claude/docs/bdd-feature-generation-standards.md`.

Feature design must never be distorted to fit existing automation code. If implementation reuse would require technical or awkward Gherkin wording, keep the approved business step pattern and let `automation-agent` adapt the implementation.

---

## What is a Snippet

A snippet is a **reusable gherkin step** defined in a `.snippet` file. It looks like gherkin but acts like a method — encapsulating multiple low-level genie glue steps into a single business-behavior step.

```
# trade-create.snippet
@Given "the maker creates a new FX TRF trade"
  Given user is on the 'trading-portal' page
  When user clicks the 'create-trade-button' element
  When user fills 'FX TRF' into 'product-type'
  When user fills '1000000' into 'notional-amount'
  When user clicks the 'save-button' element
  Then the 'success-toast' should be visible
```

The calling feature file only sees:
```gherkin
Given the maker creates a new FX TRF trade
```

---

## BDD Step Authoring Principles

Feature files should read like business behavior, while snippets and step definitions hide implementation mechanics.

Rules:
- Use domain language in feature-level steps. Avoid selectors, page element IDs, Java class names, endpoint names, and request-builder wording in reusable business steps.
- Use a consistent voice. Prefer third-person role language such as `maker`, `checker`, `admin`, and `the user`; do not mix it with first-person `I`.
- Keep scenarios short by composing a few intent-level steps. If a scenario needs more than 8 executable steps, split the behavior or extract stable setup into reusable snippets.
- Keep step definitions thin. Step definitions should delegate to page objects, service clients, fixtures, or helper classes; they should not accumulate workflow logic.
- Create snippets as reusable business capabilities, not story-specific test code.

---

## Part 1: UI Snippet Design

### 1.1 Granularity — One Snippet = One User Intent

The core rule: **a snippet encapsulates what the user wants to accomplish, not the UI steps they take to get there.**

| Level | Example | Correct? |
|-------|---------|----------|
| Too fine (UI operation) | `user clicks the create button` | No — keep raw glue inside a snippet, not in feature files |
| Too fine (UI operation) | `user fills 'FX TRF' into product type field` | No — keep raw glue inside a snippet, not in feature files |
| Correct (user intent) | `maker creates a new FX TRF trade` | Yes |
| Correct (user intent) | `checker approves the pending trade` | Yes |
| Correct (user intent) | `user verifies trade status is 'Pending Approval' in blotter` | Yes |
| Too coarse (multi-intent) | `user completes full trade lifecycle` | No — split into create + approve + verify |

**How to decide**: ask "can this step represent a single sentence in a business requirement?" If yes → correct granularity. If it requires "and" to describe → too coarse. If it describes a button click → too fine.

### 1.2 Naming Convention

Pattern: `{actor} {verb} {business object} [with {qualifier}]`

| Component | Rule | Examples |
|-----------|------|---------|
| Actor | Role name from the story (maker, checker, admin, user) | `maker`, `checker` |
| Verb | Business action, not UI action | `creates`, `approves`, `rejects`, `amends` |
| Business Object | Domain entity + product type if relevant | `a new FX TRF trade`, `the pending trade` |
| Qualifier | Optional — distinguishes variants of same action | `with StepIn Full`, `with invalid payload` |

Use the same voice across one feature file. Prefer role-based wording (`maker creates`, `checker approves`) over first-person wording (`I create`, `I approve`).

**Examples:**
```
✓ maker creates a new FX TRF trade
✓ maker creates a FX TRF StepIn Full trade
✓ checker approves the pending trade
✓ user verifies trade status is '$1' in blotter
✓ maker amends trade details for trade '$1'

✗ user clicks the Create button                     → UI operation
✗ user navigates to trading portal and logs in       → compound (navigate + login)
✗ user does FX TRF                                   → too vague
```

### 1.3 When to Create a New Snippet vs Reuse

```
Is there an existing snippet that matches the target layer?
├── NO → Do not reuse across layers.
└── YES
    ├── Exact text or regex match? → Reuse.
    ├── Same actor + verb + business object + outcome? → Reword generated step to reuse.
    ├── Same intent, only values differ? → Reuse existing parameterized snippet or propose parameterization.
    ├── Same verb but different business outcome? → Create a new snippet.
    └── Different intent? → Create a new snippet.
```

### 1.3.1 Reuse Decision Matrix

| Existing snippet | New need | Decision |
|------------------|----------|----------|
| `maker creates a new (.*) trade` | Maker creates FX TRF trade | Reuse |
| `user verifies trade status is '(.*)' in blotter` | Verify `Live` status | Reuse |
| `maker creates a new FX TRF trade` | Maker creates FX NDF trade | Propose parameterizing product: `maker creates a new (.*) trade` |
| `checker approves the pending trade` | Checker rejects pending trade | New snippet; different outcome |
| UI login snippet | API auth precondition | Do not reuse; different layer |
| `user clicks save button` | Create trade workflow | Do not expose in feature; use inside a higher-level snippet |

### 1.3.2 Reuse Heuristics

Reuse or parameterize when:
- The business intent and outcome are the same.
- Only product, status, role, ID, date, currency, or amount differs.
- The existing snippet can be called with clearer generated wording.
- The snippet remains understandable with 1-3 parameters.

Create a new snippet when:
- The actor performs a different business action.
- The final business state differs.
- The existing snippet would need conditional branches for unrelated workflows.
- More than 3 unrelated parameters are needed.
- Reuse would cross API/UI boundaries.

Do not create story-specific, TC-specific, or endpoint-specific snippets. Snippets should survive future stories.

### 1.4 UI Snippet Internal Structure

A well-structured snippet follows this pattern inside:

```
@Given "maker creates a new FX TRF trade"
  # Navigate to correct page (if not already there)
  Given user is on the 'trade-create' page

  # Fill required fields
  When user fills 'FX TRF' into 'product-type'
  When user fills '1000000' into 'notional-amount'
  When user fills 'USD' into 'currency'

  # Execute action
  When user clicks the 'save-button' element

  # Verify action completed
  Then the 'success-notification' should be visible
```

Sections: **Navigate → Fill → Execute → Verify**

Each section uses genie-playwright built-in glue (click, fill, navigate, assert). The snippet hides all of this behind a single business-behavior step.

### 1.5 Snippet Decomposition for Complex Flows

For complete lifecycle flows (create → verify → approve → verify), decompose into a chain of snippets in the feature file:

```gherkin
Scenario: [TC-TRADE-CREATE-UI-001] Maker creates trade and Checker approves
  Given maker is logged in to the trade portal
  When maker creates a new FX TRF trade
  Then user verifies trade status is 'Pending Approval' in blotter
  Given checker is logged in to the trade portal
  When checker approves the pending trade
  Then user verifies trade status is 'Live' in blotter
  And user verifies event status is 'New' in blotter
```

Each line = one snippet call. The feature tells a business story. The snippets handle the UI plumbing underneath.

---

## Part 2: API Snippet Design

### 2.1 When API Snippets Are Needed

API scenarios test endpoints directly using inline genie-rest glue. API snippets are used for **one purpose only: preconditions** — setting up data that another API scenario depends on.

| Situation | Use Snippet? | Why |
|-----------|-------------|-----|
| Testing the API endpoint itself (request + response) | No — inline glue | This IS the test, don't hide it |
| Setting up data another scenario depends on (e.g. "a trade must exist before I can approve it") | Yes — precondition snippet | Reusable data setup, hides multi-step API calls |
| Shared request headers/auth across scenarios | No — inline glue | Keep it visible; not complex enough to encapsulate |

### 2.2 API Precondition Snippet Pattern

Wrap a multi-step API call into a single precondition that puts the system into a known state:

```
# trade-precondition.snippet
@Given "a (.*) trade exists in (.*) status"
  Given start building a new request
  And set header 'X-User-Id' to 'maker01'
  And attach the multi-part dat file for product '$1'
  When post to path '/trades/create'
  Then response status code is '200'
  And new trade is persisted in database successfully
```

This lets other scenarios start from a known state:
```gherkin
# [REUSE] snippets/api/trade-precondition.snippet
Given a FX TRF trade exists in Pending Approval status
When put to path '/trades/{id}/approve'
Then response matches current scenario
```

The scenario endpoint under test uses `response matches current scenario` as its contract assertion. That assertion validates the expected status code, JSON schema, and YAML-defined response body for the current scenario. Do not add a separate status-code assertion for the endpoint under test unless the framework contract assertion does not validate status.

### 2.3 API Precondition Snippet Naming Convention

Pattern: `a/an {entity} exists in {state} status [for/with {qualifier}]`

The name describes the **resulting state**, not the steps to get there.

**Standard patterns:**

```
✓ a FX TRF trade exists in Pending Approval status
✓ a FX NDF trade exists in Live status
✓ an approved trade exists for product 'FX_TRF'
✓ a trade exists with event status 'StepInFull'

✗ create trade via API                    → describes action, not resulting state
✗ set up headers and body for FX TRF      → describes implementation
✗ prepare trade for approval test         → describes test intent, not system state
```

**Parameterization for reuse:**

| Parameter | Captures | Example |
|-----------|----------|---------|
| Product type | `(.*)` in entity position | `a (.*) trade exists in ...` → matches FX TRF, FX NDF, etc. |
| Target state | `(.*)` in state position | `... exists in (.*) status` → matches Pending Approval, Live, etc. |
| User/role | `'(.*)'` as qualifier | `... for user '(.*)'` → matches maker01, checker01, etc. |

**Maximize reuse by parameterizing early.** A snippet named `a (.*) trade exists in (.*) status` covers all product/status combinations with a single snippet file, rather than creating `trade-exists-pending.snippet`, `trade-exists-live.snippet`, etc.

### 2.4 Deciding: Inline Glue vs Precondition Snippet

```
Is this API call the thing I'm testing in this scenario?
├── YES → Use inline genie-rest glue. No snippet.
└── NO (this API call sets up data for the actual test)
    ├── Is the setup ≥3 glue steps?
    │   ├── YES → Precondition snippet (worth encapsulating)
    │   └── NO (1-2 steps) → Inline glue (too simple to encapsulate)
    └── (proceed)
```

---

## Part 3: Snippet Parameters

### 3.1 Positional Parameters ($1, $2)

Use when the snippet has 1-2 parameters and the meaning is obvious from context:

```
@When "user creates a new (.*) trade"
  ...fill '$1' into 'product-type'...
```

Calling: `When user creates a new FX TRF trade`

`$1` = `FX TRF` (first capture group)

### 3.2 Multiple Parameters

For 2+ parameters, order matters — put the most domain-significant first:

```
@Given "a (.*) trade request is prepared for user '(.*)'"
```

`$1` = product type (domain entity), `$2` = user ID (context)

### 3.3 When to Parameterize vs Create Separate Snippets

| Scenario | Approach |
|----------|----------|
| Same flow, different product type | Parameterize: `creates a new (.*) trade` |
| Same flow, different user role | Parameterize: `(.*) is logged in to the trade portal` |
| Fundamentally different flows that share a verb | Separate snippets: `creates a StepIn Full trade` vs `creates a standard trade` |
| >3 parameters needed | Split into smaller snippets or use Scenario Outline + Examples table |

---

## Part 4: Snippet Organization

### 4.1 File Structure

```
src/test/resources/features/
├── snippets/
│   ├── common/
│   │   ├── login.snippet           # shared login snippets (UI)
│   │   └── navigation.snippet      # shared page navigation (UI)
│   ├── api/
│   │   └── trade-precondition.snippet   # API precondition snippets (parameterized)
│   └── ui/
│       ├── trade-create.snippet    # UI trade creation flows
│       ├── trade-approve.snippet   # UI approval flows
│       └── trade-verify.snippet    # UI blotter verification
```

Note: API directory only contains **precondition** snippets. There are no API request-setup or API verify snippets.

### 4.2 Snippet in Step Catalog

In `step-catalog.md`, custom snippets (Part B) should be documented with a `Layer` column so the agent can filter by layer:

```markdown
## Part B: Custom Snippet Steps

| Step Pattern | Layer | Source File |
|---|---|---|
| `maker is logged in to the trade portal` | UI | snippets/common/login.snippet |
| `maker creates a new FX TRF trade` | UI | snippets/ui/trade-create.snippet |
| `checker approves the pending trade` | UI | snippets/ui/trade-approve.snippet |
| `a (.*) trade exists in (.*) status` | API-precondition | snippets/api/trade-precondition.snippet |
```

The `Layer` column values:
- `UI` — used only in UI feature files
- `API-precondition` — used only as data setup in API feature files (not in UI files)

This allows `automation-agent` to build layer-specific catalogs without scanning file contents.

---

## Part 5: Agent Decision Flow for Snippet Usage

When `automation-agent` implements approved feature content, it should follow this decision flow for each step pattern:

```
For each step in the scenario:

1. Is there an existing same-layer snippet or step definition with matching business intent?
   ├── YES → Reuse it without changing the approved business Gherkin.
   └── NO → continue

2. Can multiple genie built-in glue steps accomplish this?
   ├── YES
   │   ├── Is this a UI scenario?
   │   │   ├── YES → Implement or reuse a snippet behind the approved business step.
   │   │   │     Record the new/changed snippet in the Automation Implementation Report.
   │   │   └── NO (API scenario)
   │   │       ├── Is this the endpoint under test? → Use inline genie-rest glue
   │   │       ├── Is this precondition setup with ≥3 glue steps? → Implement or reuse a precondition snippet.
   │   │       └── Is this simple precondition setup with 1-2 glue steps? → Use inline genie-rest glue
   │   └── (proceed)
   └── NO (genie built-in can't do it)
       → Implement or reuse a Java step definition and record the binding decision.
```

### Key Rule

**UI feature files must NEVER contain raw genie-playwright glue steps.** Every UI step must stay as approved business Gherkin. `automation-agent` decides whether the implementation uses an existing snippet, a new snippet, a Java step definition, page objects, or helpers.

**API feature files must stay at business step-pattern level in the BDD case design stage.** `automation-agent` may implement those steps with genie-rest glue, Java step definitions, API clients, fixtures, YAML contracts, or helpers according to framework conventions.
