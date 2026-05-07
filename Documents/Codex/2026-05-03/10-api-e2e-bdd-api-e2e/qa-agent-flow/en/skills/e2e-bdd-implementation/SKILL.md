---
name: e2e-bdd-implementation
description: Implement E2E BDD feature files as executable automated tests using a three-phase hybrid approach (static analysis + Playwright MCP exploration + validation).
---

# E2E BDD Implementation

Use this skill when implementing E2E `.feature` scenarios as executable browser-based automation.

## When to Use

- An E2E `.feature` file exists and needs automation assets
- UI element locators need to be discovered or verified
- Snippets, element.json, yamldata, or Java steps need to be created/updated

## When NOT to Use

- API-only scenarios (use `api-bdd-implementation` instead)
- Pure UI exploration without a feature file (use `playwright-mcp-e2e-generation`)
- Only E2E test execution/debug (use `automation-stabilization`)

## Core Constraint

> **Feature file scenario steps must only reference snippets.**
>
> Snippets (`.snippet` files) are the only construct allowed at the scenario level.
> A snippet internally expands into built-in glue steps, other snippet references, or Java step definitions.

## Load Phase (AI actively reads project files)

1. Read the `.feature` file
2. Scan `.snippet` files (feature-specific first, then common)
3. Read `step-glue-catalog.md` (Playwright built-in glue)
4. Scan `element.json` files
5. Scan `.yml` test data files
6. Scan Java step files

## Three-Phase Hybrid Flow

```text
┌───────────────────────────────────────────────────────────────┐
│ Phase 1: Static Analysis (Fast, Offline)                          │
│ ───────────────────────────────────────────────────────────────│
│  • Exact snippet match → KNOWN                                  │
│  • Fuzzy snippet match → KNOWN                                  │
│  • No match → UNKNOWN                                          │
│  • Generate snippets for KNOWN steps immediately                 │
└───────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌───────────────────────────────────────────────────────────────┐
│ Phase 2: MCP Exploration (Unknown Steps Only)                     │
│ ───────────────────────────────────────────────────────────────│
│  • MCP executes UNKNOWN steps via natural language                │
│  • Record: operation, element, locator, input value               │
│  • Reverse-generate:                                             │
│      - element.json (new elements, getByTestId preferred)        │
│      - snippet (glue or Java internally)                         │
│      - yamldata (test data)                                      │
│  • Merge with Phase 1, deduplicate                               │
└───────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌───────────────────────────────────────────────────────────────┐
│ Phase 3: Validation                                               │
│ ───────────────────────────────────────────────────────────────│
│  • Execute complete scenario with generated implementation       │
│  • Success → Done ✓                                            │
│  • Failure → Analyze → Fix → Retry                              │
└───────────────────────────────────────────────────────────────┘
```

## Phase 1: Static Analysis

For each scenario step:

1. **Exact snippet match**: Step text matches a `.snippet` `@When` regex exactly
2. **Fuzzy snippet match**: Extract semantic core (verb + object + context), compare against existing snippets
   - `>80%` similarity → Reuse snippet
   - `50-80%` similarity → List candidates, AI decides
   - `<50%` similarity → Mark as UNKNOWN
3. **Known steps**: Generate snippets immediately (reuse existing or compose from glue)

## Phase 2: MCP Exploration

For each UNKNOWN step:

1. Open Playwright MCP
2. Execute the step using natural language description from the feature file
3. Record the execution:
   - Operation type (click, type, navigate, select, assert...)
   - Target element (what was interacted with)
   - Locator used (how MCP found it)
   - Input value (what was typed/selected)
   - Page state (what was visible/expected)

4. Reverse-generate assets:

   **a. Element JSON**:
   ```json
   {
     "pageName": {
       "elementKey": {
         "locator": "getByTestId",
         "value": "element-test-id"
       }
     }
   }
   ```

   **b. Snippet**:
   - Map the natural language step to built-in Playwright glue
   - If mappable → Snippet expands to glue steps referencing element keys
   - If not mappable → Create Java step → Snippet references it

   **c. Yamldata**: Record input values for dynamic data management

5. Merge with Phase 1 results and deduplicate against existing snippets/elements

## Element Locator Priority

When MCP discovers an element, select the most stable locator:

```text
getByTestId > getByRole > getByLabel > getByPlaceholder > getByText
```

- **Avoid**: CSS selectors, XPath, index-based selectors
- **Avoid**: Hard waits; prefer Playwright auto-wait

## Phase 3: Validation

1. Execute the complete scenario using the generated implementation
2. If all steps pass → Implementation complete
3. If any step fails:
   - Analyze failure cause (missing element? wrong locator? undefined step? data issue?)
   - Fix the root cause (update element.json, adjust snippet, add Java step, update yamldata)
   - Re-run validation

## Snippet Creation Rules

When creating a new snippet (Phase 1 or Phase 2):

1. **Prefer built-in Playwright glue**: Search `step-glue-catalog.md`
2. **Compose multiple glue steps**: Combine if one is insufficient
3. **Reference element keys**: Use `'page.element'` notation from `element.json`
4. **Java step as last resort**: Only when glue cannot express the logic
   - Cross-step data passing via `ctx`
   - Complex conditional UI logic
   - Dynamic element handling
5. **Parameterize for reuse**: Use regex capture groups for variable parts

## Output Format

```markdown
## E2E BDD Implementation Result

### 1. Feature Intake
| Feature | Scenarios | App URL |
|---|---|---|

### 2. Phase 1: Static Analysis
| Step | Match Type | Matched To | Status |
|---|---|---|---|
| | Exact snippet | `auth.snippet` | Known |
| | Fuzzy snippet | `login.snippet` | Known |
| | — | — | Unknown |

### 3. Phase 2: MCP Exploration
| Unknown Step | MCP Action | Element Key | Locator | Value |
|---|---|---|---|---|
| | Click submit button | trade.submitButton | getByTestId | trade-submit |

### 4. Generated / Updated Files
| File | Type | Action | Purpose |
|---|---|---|---|
| `trade.snippet` | Snippet | Create | Feature-specific steps |
| `trade.element.json` | Element | Create/Update | Locator mappings |
| `trade.yml` | Yamldata | Create | Test data |
| `UiHelpers.java` | Java | Update | Custom steps |

### 5. Phase 3: Validation
| Scenario | Result | Notes |
|---|---|---|
| | Pass / Fail | |

### 6. Open Questions / Blockers
| Item | Impact | Required Action |
|---|---|---|
```

## Rules Summary

| # | Rule |
|---|---|
| 1 | Feature scenario steps must only reference snippets |
| 2 | Phase 1 known steps must NOT trigger MCP |
| 3 | Phase 2 only explores unknown steps |
| 4 | Snippet internal expansion prefers built-in Playwright glue |
| 5 | Java step is last resort (cross-step data passing, complex logic) |
| 6 | Element locator priority: `getByTestId` > `getByRole` > `getByLabel` > `getByPlaceholder` > `getByText` |
| 7 | Avoid fragile selectors (CSS/XPath/index) |
| 8 | Fuzzy match existing snippets before creating new ones |
| 9 | Parameterize snippets for reuse across scenarios |
