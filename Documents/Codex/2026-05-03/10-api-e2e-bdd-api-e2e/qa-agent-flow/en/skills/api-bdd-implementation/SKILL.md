---
name: api-bdd-implementation
description: Implement API BDD feature files as executable automated tests using snippets, built-in REST glue, yamldata, and custom Java steps only when necessary.
---

# API BDD Implementation

Use this skill when implementing API `.feature` scenarios as executable automation.

## When to Use

- An API `.feature` file exists and needs automation assets
- The scenario steps need to be mapped to snippets, glue, or Java steps
- Test data (request/response) needs to be created or updated

## When NOT to Use

- E2E/UI scenarios (use `e2e-bdd-implementation` instead)
- Only API test execution/debug (use `automation-stabilization`)
- Traceability reporting (use `automation-traceability-reporting`)

## Core Constraint

> **Feature file scenario steps must only reference snippets.**
>
> Snippets (`.snippet` files) are the only construct allowed at the scenario level.
> A snippet internally expands into built-in glue steps, other snippet references, or Java step definitions.

## Load Phase (AI actively reads project files)

1. Read the `.feature` file
2. Read `api-contract-hint.md` from upstream BDD Case Design Agent
3. If no contract hint found → read Swagger/OpenAPI documentation
4. If Swagger also has no match → **stop and ask the user**
5. Scan `.snippet` files (feature-specific first, then common)
6. Read `step-glue-catalog.md` (REST API built-in glue)
7. Scan `.yml` test data files
8. Scan Java step files

## Request Info Derivation

```text
Scenario step (e.g., "When I create a trade allocation")
  ↓
Read api-contract-hint.md
  ├─ Match found → Use endpoint, method, body schema
  └─ No match → Read Swagger/OpenAPI
       ├─ Found → Use
       └─ Not found → Stop and ask user
  ↓
Determine request structure
  ↓
Create/update yamldata with concrete field values
```

## Core Flow

```text
Parse feature → Extract scenarios and steps
  ↓
For each scenario step:
  ├─ Level 1: Exact snippet match
  │    Match @When regex pattern exactly → Reuse snippet
  │
  ├─ Level 2: Fuzzy snippet match
  │    No exact match → Extract semantic core
  │    Compare against existing snippets
  │    High similarity (>80%) → Reuse snippet (parameterize if needed)
  │    Medium similarity (50-80%) → List candidates, AI decides
  │    Low similarity (<50%) → Go to Level 3
  │
  └─ Level 3: Create new snippet
       Must create a new .snippet entry
       ├─ Analyze step intent
       ├─ Search built-in REST glue catalog
       │   ├─ Can be composed from glue steps
       │   │   → Snippet expands to glue step sequence
       │   └─ Cannot be composed from glue
       │       → Create Java step definition
       │       → Snippet references the Java step
       └─ Check test data needs
           ├─ Request body required → Create yamldata request
           └─ Response assertion required → Create yamldata response
```

## Fuzzy Snippet Matching

When exact regex match fails:

1. **Extract semantic core** from the step:
   - Action verb: create, update, delete, verify, assert, send, build...
   - Business object: trade, user, allocation, order, request, response...
   - Context modifier: new, existing, with X, for Y, as Z...

2. **Compare against existing snippets**:
   - Read snippet `@When` regex patterns
   - Read snippet internal expansion (if concise)
   - Use semantic similarity to rank candidates

3. **Decision thresholds**:
   - `>80%` similarity: Reuse snippet, parameterize if needed
   - `50-80%` similarity: List candidates, let AI judge
   - `<50%` similarity: Create new snippet

## Snippet Creation Rules

When creating a new snippet:

1. **Prefer built-in glue**: Search `step-glue-catalog.md` for matching glue steps
2. **Compose multiple glue steps**: If one glue step is insufficient, combine multiple
3. **Java step as last resort**: Only when glue cannot express the logic
   - Response parsing and extraction
   - Cross-step data sharing via `ctx`
   - Complex conditional logic
   - Dynamic value generation
4. **Parameterize for reuse**: Use regex capture groups for variable parts

## Yamldata Rules

1. Each scenario MUST have a `@TC-xxx` tag
2. The tag maps to a top-level key in the `.yml` file
3. Structure:
   ```yaml
   TC-TRADE-ALLOCATION-001:
     request: |
       { JSON request body }
     response: |
       { JSON expected response }
   ```
4. Response JSON MAY use `json-unit` placeholders:
   - `${json-unit.ignore}` — ignore field value
   - `${json-unit.any-string}` — accept any string
   - `${json-unit.any-number}` — accept any number
5. Dynamic values (like IDs generated at runtime) use `"PLACEHOLDER"` in request

## Output Format

```markdown
## API BDD Implementation Result

### 1. Feature Intake
| Feature | Scenarios | TC Tags |
|---|---|---|

### 2. Request Info
| Scenario | Method | Endpoint | Source |
|---|---|---|---|

### 3. Step Mapping
| Scenario | Step | Snippet | Internal | Action |
|---|---|---|---|---|

### 4. Files to Create/Update
| File | Type | Action | Purpose |
|---|---|---|---|

### 5. Yamldata Structure
```yaml
TC-XXX-001:
  request: |
    { ... }
  response: |
    { ... }
```

### 6. Java Step Draft (if needed)
```java
@Then("^...$")
public void ...() { ... }
```

### 7. Open Questions / Blockers
| Item | Impact | Required Action |
|---|---|---|
```

## Rules Summary

| # | Rule |
|---|---|
| 1 | Feature scenario steps must only reference snippets |
| 2 | Snippet internal expansion prefers built-in REST glue |
| 3 | Java step is last resort (response parsing, data passing, complex logic) |
| 4 | Each scenario must have `@TC-xxx` tag binding to yamldata key |
| 5 | Test data is isolated in `.yml` files (request/response) |
| 6 | Request info from `api-contract-hint.md` → Swagger → ask user |
| 7 | Fuzzy match existing snippets before creating new ones |
| 8 | Parameterize snippets for reuse across scenarios |
