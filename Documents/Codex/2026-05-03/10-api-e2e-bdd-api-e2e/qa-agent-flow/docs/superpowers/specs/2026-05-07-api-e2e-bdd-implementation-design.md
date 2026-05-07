# API + E2E BDD Implementation Skill Design

## Date: 2026-05-07

## Background

The current `bdd-feature-implementation` skill is too generic. It mentions "reuse step definitions" and "API clients" but does not address:
- Snippet reuse (the company framework supports `.snippet` files that expand into multiple built-in glue steps)
- Built-in REST API glue catalog vs custom Java steps
- Built-in Playwright glue catalog vs custom Java steps
- Yamldata for test data
- Element JSON for Playwright locators
- The constraint that **scenario steps must only reference snippets** (not glue or Java steps directly)

This design replaces the generic skill with two focused implementation skills.

---

## Architecture Overview

```
┌─────────────────────────┐     ┌─────────────────────────┐
│  api-automation-agent   │     │  e2e-automation-agent   │
│      (existing)         │     │      (existing)         │
└───────────┬─────────────┘     └───────────┬─────────────┘
            │ references                    │ references
            ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────┐
│ api-bdd-implementation  │     │ e2e-bdd-implementation  │
│      (new skill)        │     │      (new skill)        │
└─────────────────────────┘     └─────────────────────────┘
```

### Files Changed

| File | Action | Reason |
|---|---|---|
| `en/skills/api-bdd-implementation/SKILL.md` | Create | New API implementation skill |
| `en/skills/e2e-bdd-implementation/SKILL.md` | Create | New E2E implementation skill |
| `en/skills/bdd-feature-implementation/SKILL.md` | Delete/Deprecate | Replaced by the two new skills |
| `en/04-api-automation-agent.md` | Update | Change skill reference table |
| `en/05-e2e-automation-agent.md` | Update | Change skill reference table |

---

## Core Constraint

> **Feature file scenario steps must only reference snippets.**
>
> Snippets (`.snippet` files) are the only construct allowed at the scenario level. A snippet internally expands into built-in glue steps, other snippet references, or Java step definitions.

This means the implementation flow is:
```
Feature step → Snippet (exact or fuzzy match)
                 ↓
         Snippet internal expansion:
           ├─ Built-in glue steps (preferred)
           ├─ Other snippet references
           └─ Java step (last resort)
```

---

## `api-bdd-implementation` Skill

### 1. Information Sources (AI loads actively)

| Source | Purpose |
|---|---|
| `.feature` file | Scenarios and steps to implement |
| `api-contract-hint.md` | API endpoint, method, body schema (from upstream BDD Case Design Agent) |
| Swagger/OpenAPI docs | Fallback for API contract information |
| `.snippet` files (feature-specific → common) | Existing reusable snippets |
| `step-glue-catalog.md` (REST) | Built-in REST API glue step catalog |
| `.yml` test data files | Existing test data |
| Java step files | Existing custom Java step definitions |

### 2. Request Info Derivation

```
Scenario step (e.g., "When I create a trade allocation")
  ↓
Read api-contract-hint.md
  ├─ Match found → Use endpoint, method, body schema
  └─ No match → Read Swagger/OpenAPI
       ├─ Found → Use
       └─ Not found → Stop and ask user
```

### 3. Core Flow (Static Analysis Only)

```text
Parse feature → Extract scenarios
  ↓
For each scenario step:
  ├─ Level 1: Exact snippet match → Reuse
  ├─ Level 2: Fuzzy snippet match → Reuse (parameterize)
  └─ Level 3: No match → Create new snippet
       ├─ Try built-in glue combination → Snippet expands to glue steps
       └─ Glue insufficient → Create Java step → Snippet references it
  ↓
Determine test data needs → Create/update yamldata
```

### 4. Fuzzy Matching Rules

When exact regex match fails:

1. Extract semantic core from the step:
   - Action verb (create, update, delete, verify, assert...)
   - Business object (trade, user, allocation, order...)
   - Context modifier (new, existing, with X, for Y...)

2. Compare against existing snippets:
   - Read snippet `@When` patterns
   - Read snippet internal expansion (if short)
   - Use semantic similarity to rank candidates

3. Decision:
   - High similarity (>80%): Reuse snippet, parameterize if needed
   - Medium similarity (50-80%): List candidates, let AI decide
   - Low similarity (<50%): Create new snippet

### 5. Key Rules

| # | Rule |
|---|---|
| 1 | Feature scenario steps must only reference snippets |
| 2 | Snippet internal expansion prefers built-in REST glue |
| 3 | Java step is last resort (for response parsing, data passing, complex logic) |
| 4 | Each scenario must have `@TC-xxx` tag binding to yamldata key |
| 5 | Test data is isolated in `.yml` files (request/response) |

### 6. Output Format

```markdown
## API BDD Implementation Result

### 1. Feature Intake
| Feature | Scenarios | TC Tags |
|---|---|---|

### 2. Request Info
| Scenario | Method | Endpoint | Source |
|---|---|---|---|

### 3. Step Mapping
| Scenario Step | Snippet | Internal | Action |
|---|---|---|---|

### 4. Generated / Updated Files
| File | Type | Action |
|---|---|---|

### 5. Yamldata Structure
```yaml
TC-XXX-001:
  request: |
    { JSON }
  response: |
    { JSON with json-unit placeholders }
```

### 6. Java Step Draft (if needed)
```java
@Then("^...$")
public void ...() { ... }
```
```

---

## `e2e-bdd-implementation` Skill

### 1. Information Sources (AI loads actively)

| Source | Purpose |
|---|---|
| `.feature` file | Scenarios and steps to implement |
| `.snippet` files (feature-specific → common) | Existing reusable snippets |
| `step-glue-catalog.md` (Playwright) | Built-in Playwright glue step catalog |
| `element.json` files | UI element locator mappings |
| `.yml` test data files | Existing test data |
| Java step files | Existing custom Java step definitions |

### 2. Core Flow (Three-Phase Hybrid)

#### Phase 1: Static Analysis (Fast, Offline)

```text
Parse feature → Extract scenarios
  ↓
For each scenario step:
  ├─ Exact snippet match → Mark as KNOWN
  ├─ Fuzzy snippet match → Mark as KNOWN
  └─ No match → Mark as UNKNOWN

For KNOWN steps: Generate snippets immediately (reuse or glue combination)
```

#### Phase 2: MCP Exploration (Unknown Steps Only)

```text
For each UNKNOWN step:
  ├─ Use Playwright MCP to execute the step via natural language
  ├─ Record: operation type, element, locator, input value
  └─ Reverse-generate assets:
       ├─ element.json: New elements (getByTestId preferred)
       ├─ snippet: New snippet (glue or Java internally)
       └─ yamldata: New test data

Merge with Phase 1 results, deduplicate
```

#### Phase 3: Validation

```text
Execute complete scenario with generated implementation
  ├─ Success → Done
  └─ Failure → Analyze cause → Fix → Retry
```

### 3. Element Discovery via Playwright MCP

When a step needs an element not in `element.json`:

1. Skill instructs AI to open Playwright MCP
2. Execute the UI action described by the BDD step
3. MCP identifies the target element
4. Select locator with priority:
   ```
   getByTestId > getByRole > getByLabel > getByPlaceholder > getByText
   ```
5. Write to `element.json`:
   ```json
   {
     "trade": {
       "submitButton": {
         "locator": "getByTestId",
         "value": "trade-submit-btn"
       }
     }
   }
   ```

### 4. Key Rules

| # | Rule |
|---|---|
| 1 | Feature scenario steps must only reference snippets |
| 2 | Phase 1 known steps must NOT trigger MCP |
| 3 | Phase 2 only explores UNKNOWN steps |
| 4 | Snippet internal expansion prefers built-in Playwright glue |
| 5 | Java step is last resort (for cross-step data passing) |
| 6 | Element locator priority: `getByTestId` > `getByRole` > `getByLabel` > `getByPlaceholder` > `getByText` |
| 7 | Avoid fragile selectors (CSS/XPath/index) |

### 5. Output Format

```markdown
## E2E BDD Implementation Result

### 1. Feature Intake
| Feature | Scenarios | App URL |
|---|---|---|

### 2. Phase 1: Static Analysis
| Step | Match Type | Matched To | Status |
|---|---|---|---|

### 3. Phase 2: MCP Exploration
| Unknown Step | MCP Action | Element | Locator |
|---|---|---|---|

### 4. Generated / Updated Files
| File | Type | Action |
|---|---|---|

### 5. Phase 3: Validation
| Scenario | Result | Notes |
|---|---|---|
```

---

## Comparison: API vs E2E Skill

| Dimension | API Skill | E2E Skill |
|---|---|---|
| **Execution mode** | Static analysis only | Three-phase hybrid (static + MCP explore + MCP validate) |
| **Glue type** | REST API (request/build/assert) | Playwright (element/UI interaction) |
| **Additional assets** | None | `element.json` (element locators) |
| **MCP dependency** | None | Phase 2 & 3 require Playwright MCP |
| **Locator strategy** | N/A | `getByTestId` preferred |
| **Information sources** | Feature, contract hint, Swagger, snippets, glue catalog, yamldata, Java | Feature, snippets, glue catalog, element.json, yamldata, Java |
| **Test data** | Request/response JSON | UI test data |
| **Shared rules** | Snippet-only at scenario level; Glue preferred internally; Java as last resort; Fuzzy matching for reuse |

---

## BDD Case Design Agent Enhancement

To support the API skill, the upstream BDD Case Design Agent should output an additional file alongside `.feature`:

**`api-contract-hint.md`**:
```markdown
## API Contract Hints for trade_allocation.feature

| Scenario Tag | Method | Endpoint | Body Schema Key |
|---|---|---|---|
| @TC-001 | POST | /api/v1/trades/allocation | trade.allocation.request |

## Body Schema
```json
{
  "eventType": "Allocation",
  "data": [...],
  "tradeIds": ["PLACEHOLDER"]
}
```
```

If the contract hint is missing, the API skill falls back to reading the project's Swagger/OpenAPI documentation.

---

## Quality Gates

### API Skill

| Check | Standard |
|---|---|
| All scenario steps have snippet match | Pass |
| Snippet internals prefer built-in glue | Pass |
| Java steps have documented reason | Pass |
| Each scenario has `@TC-xxx` tag | Pass |
| Yamldata `request` aligns with Swagger schema | Pass |
| Yamldata `response` uses `json-unit` placeholders | Pass |

### E2E Skill

| Check | Standard |
|---|---|
| All scenario steps have snippet match | Pass |
| Phase 1 known steps did not trigger unnecessary MCP | Pass |
| Phase 2 unknown steps have MCP exploration record | Pass |
| All element.json keys have corresponding locators | Pass |
| Locator priority follows `getByTestId` first rule | Pass |
| No fragile CSS/XPath/index selectors | Pass |
| Phase 3 validation passes | Pass |
