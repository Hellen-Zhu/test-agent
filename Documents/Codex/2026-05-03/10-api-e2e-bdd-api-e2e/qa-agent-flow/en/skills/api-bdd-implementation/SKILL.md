---
name: api-bdd-implementation
version: "1.0.0"
domain: api-testing
layer: automation
intent: >
  Map API BDD scenarios to executable automation assets (snippets, yamldata, Java steps)
  by analyzing business intent, reusing existing snippets via semantic matching,
  composing built-in REST glue, and creating custom Java steps only when glue
  is insufficient. Prefer reuse over creation.
fingerprint:
  required_inputs:
    feature_file: "Path to API .feature file with @api tags"
    glue_catalog: "REST API built-in glue step catalog (step-glue-catalog.md)"
  optional_inputs:
    contract_info: "Pre-resolved API contract (from api-contract-hint.md or api-contract-discovery skill)"
    existing_snippets: "Existing .snippet files for reuse"
    existing_yamldata: "Existing .yml test data files"
  environment:
    - "Maven/Gradle project with Cucumber + REST BDD framework"
    - "Built-in REST glue (request/build/assert) available"
    - "Java step definition classes exist or can be created"
tags:
  - api
  - bdd
  - cucumber
  - automation
  - snippet
  - yamldata
  - java
side_effects:
  - operation: "create"
    target: ".snippet files"
    description: "New snippet macros for business-level scenario steps"
  - operation: "create_or_update"
    target: ".yml test data files"
    description: "Request/response fixtures per @TC-xxx tag"
  - operation: "create_or_update"
    target: "Java step definition classes"
    description: "Custom Java steps when built-in glue is insufficient"
idempotency: >
  Re-running on the same feature file with the same inputs produces identical output.
  Duplicate snippets are detected via regex pattern comparison and skipped.
  Existing yamldata entries with matching @TC-xxx keys are preserved unless
  the request/response schema has changed.
rollback: >
  If validation fails after generation, delete newly created .snippet and .yml
  files. Do NOT delete files that existed before this skill invocation.
  Rollback scope is limited to side_effects entries with operation="create".
---

# API BDD Implementation Skill

## Overview

| Attribute | Value |
|---|---|
| **Name** | `api-bdd-implementation` |
| **Domain** | API Testing |
| **Layer** | Automation |
| **Version** | `1.0.0` |
| **Idempotency** | Yes |
| **Side Effects** | File creation/modification only |

## When to Use

- An API `.feature` file exists and needs automation assets
- Scenario steps need to be mapped to snippets, glue, or Java steps
- Test data (request/response) needs to be created or updated

## When NOT to Use

- E2E/UI scenarios → use `e2e-bdd-implementation`
- Only API test execution/debug → use `automation-stabilization`
- Traceability reporting → use `automation-traceability-reporting`

---

## Input Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["feature_file", "glue_catalog"],
  "properties": {
    "feature_file": {
      "type": "string",
      "description": "Absolute or relative path to the API .feature file"
    },
    "contract_info": {
      "type": "object",
      "description": "Pre-resolved API contract info (endpoint, method, request/response schema). Supplied by agent from api-contract-hint.md or api-contract-discovery skill output.",
      "properties": {
        "endpoint": {"type": "string"},
        "method": {"type": "string"},
        "request_schema": {"type": "object"},
        "response_schema": {"type": "object"}
      },
      "default": null
    },
    "glue_catalog": {
      "type": "string",
      "description": "Path to REST API step-glue-catalog.md"
    },
    "snippet_dirs": {
      "type": "array",
      "items": {"type": "string"},
      "description": "Directories to scan for existing .snippet files",
      "default": ["."]
    },
    "yamldata_dir": {
      "type": "string",
      "description": "Directory for .yml test data files",
      "default": "."
    },
    "java_step_dirs": {
      "type": "array",
      "items": {"type": "string"},
      "description": "Directories to scan for existing Java step definition classes",
      "default": ["src/test/java"]
    }
  }
}
```

## Output Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["status", "context", "side_effects", "observability"],
  "properties": {
    "status": {
      "type": "string",
      "enum": ["success", "partial", "failure"],
      "description": "Overall execution status"
    },
    "context": {
      "type": "object",
      "description": "Complete execution context for downstream consumption. Agent maps this to the next skill's input.",
      "properties": {
        "feature_name": {"type": "string"},
        "scenarios_count": {"type": "integer"},
        "step_mappings": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "scenario": {"type": "string"},
              "step": {"type": "string"},
              "snippet": {"type": "string"},
              "action": {"type": "string", "enum": ["reuse", "create"]},
              "match_confidence": {"type": "number"}
            }
          }
        },
        "generated_assets": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "path": {"type": "string"},
              "type": {"type": "string", "enum": ["snippet", "yamldata", "java"]},
              "action": {"type": "string", "enum": ["create", "update"]}
            }
          }
        },
        "reused_assets": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "path": {"type": "string"},
              "type": {"type": "string", "enum": ["snippet", "yamldata", "java"]},
              "match_type": {"type": "string", "enum": ["exact", "fuzzy"]}
            }
          }
        },
        "missing_contract_info": {
          "type": "array",
          "items": {"type": "string"},
          "description": "Scenarios where endpoint/method could not be determined"
        }
      }
    },
    "side_effects": {
      "type": "array",
      "description": "System state changes performed by this skill execution",
      "items": {
        "type": "object",
        "required": ["operation", "file_path", "file_type"],
        "properties": {
          "operation": {
            "type": "string",
            "enum": ["create", "update", "none"],
            "description": "create = new file; update = modified existing; none = read-only"
          },
          "file_path": {"type": "string"},
          "file_type": {
            "type": "string",
            "enum": ["snippet", "yamldata", "java", "feature"]
          },
          "reason": {"type": "string"},
          "rollback_action": {
            "type": "string",
            "enum": ["delete", "revert", "none"],
            "description": "Action to take if rollback is triggered"
          }
        }
      }
    },
    "dependencies": {
      "type": "array",
      "description": "External dependencies discovered during execution",
      "items": {"type": "string"}
    },
    "observability": {
      "type": "object",
      "description": "Execution metrics for monitoring and debugging",
      "properties": {
        "steps_total": {"type": "integer"},
        "steps_exact_match": {"type": "integer"},
        "steps_fuzzy_match": {"type": "integer"},
        "steps_unknown": {"type": "integer"},
        "snippets_created": {"type": "integer"},
        "snippets_reused": {"type": "integer"},
        "glue_steps_composed": {"type": "integer"},
        "java_steps_created": {"type": "integer"},
        "yamldata_entries_created": {"type": "integer"},
        "yamldata_entries_updated": {"type": "integer"},
        "contract_source": {
          "type": "string",
          "enum": ["contract_hint", "swagger", "user_input", "unknown"]
        }
      }
    }
  }
}
```

---

## Execution Flow (Business Semantic Layer)

This skill abstracts implementation into six business-semantic phases.
Each phase is stateless — it consumes the previous phase's context and
produces a new context. The agent (not the skill) persists context between
phases.

```text
INTAKE    → Load feature. Receive API contract info from agent input
            (endpoint, method, request/response schema).
            If contract info is missing, agent must call api-contract-discovery
            first and pass the result as input.
            Output: enriched feature context with contract info

ANALYZE   → Extract business scenarios and steps.
            Classify each step: exact-match / fuzzy-match / unknown
            Output: classified step inventory

MATCH     → Semantic matching against existing snippets.
            Extract [verb, object, context] from each step.
            Compare against snippet @When patterns.
            Output: matched snippets + remaining unknown steps

COMPOSE   → Create new snippets from built-in REST glue.
            Compose glue steps to express business action.
            If glue insufficient → create Java step.
            Output: new snippet definitions

MATERIALIZE → Generate yamldata fixtures.
              Map @TC-xxx tags to request/response pairs.
              Apply json-unit placeholders for dynamic values.
              Output: yamldata entries

VALIDATE  → Verify all steps have snippet coverage.
            Verify contract info is complete.
            Produce structured output context.
            Output: final execution context
```

---

## Core Constraint

> **Feature file scenario steps must only reference snippets.**
>
> Snippets (`.snippet` files) are the only construct allowed at the scenario level.
> A snippet internally expands into built-in glue steps, other snippet references, or Java step definitions.

---

## Phase Details

### INTAKE — API Contract Derivation

```text
Scenario step (e.g., "When I create a trade allocation")
  ↓
Receive contract_info from agent input
  ├─ Present → Extract endpoint, method, request/response schema
  └─ Missing → Return status: "failure", ask agent to call api-contract-discovery
  ↓
Determine request structure
  ↓
Record in context.contract_info
```

**Side effects**: None (read-only phase)

### ANALYZE — Step Classification

For each scenario step:

| Classification | Criteria | Next Phase |
|---|---|---|
| **Exact match** | Step text matches a `.snippet` `@When` regex exactly | MATCH → Reuse |
| **Fuzzy match** | Semantic similarity ≥ 80% against existing snippets | MATCH → Reuse with parameterization |
| **Unknown** | No match above 50% threshold | COMPOSE → Create new snippet |

**Observability metrics**: `steps_exact_match`, `steps_fuzzy_match`, `steps_unknown`

### MATCH — Semantic Snippet Reuse

When exact regex match fails, perform semantic analysis:

1. **Extract business intent** from the step:
   - Action verb: create, update, delete, verify, assert, send, build...
   - Business object: trade, user, allocation, order, request, response...
   - Context modifier: new, existing, with X, for Y, as Z...

2. **Compare against existing snippets**:
   - Read snippet `@When` regex patterns
   - Read snippet internal expansion
   - Rank by semantic similarity

3. **Decision thresholds**:
   - `>80%` similarity: Reuse snippet, parameterize if needed
   - `50-80%` similarity: List candidates, let AI judge
   - `<50%` similarity: Mark as unknown, proceed to COMPOSE

**Side effects**: None (read-only phase)

### COMPOSE — Snippet Creation

When creating a new snippet:

1. **Prefer built-in REST glue**: Search `step-glue-catalog.md` for matching glue steps
2. **Compose multiple glue steps**: If one is insufficient, combine multiple
3. **Java step as last resort**: Only when glue cannot express the logic
   - Response parsing and extraction
   - Cross-step data sharing via `ctx`
   - Complex conditional logic
   - Dynamic value generation
4. **Parameterize for reuse**: Use regex capture groups for variable parts

**Side effects**:
```json
{
  "operation": "create",
  "file_path": "<feature_name>.snippet",
  "file_type": "snippet",
  "reason": "No existing snippet matched business intent of step",
  "rollback_action": "delete"
}
```

### MATERIALIZE — Test Data Generation

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
5. Dynamic values use `"PLACEHOLDER"` in request

**Side effects**:
```json
{
  "operation": "create_or_update",
  "file_path": "<feature_name>.yml",
  "file_type": "yamldata",
  "reason": "Test data for @TC-xxx scenarios",
  "rollback_action": "revert"
}
```

### VALIDATE — Quality Gate

Before producing final output, verify:

| Check | Failure Action |
|---|---|
| All steps have snippet coverage | Return `status: "partial"`, list uncovered steps |
| Contract info (endpoint, method) is complete | Return `status: "partial"`, list missing in `missing_contract_info` |
| No duplicate snippet patterns | Merge duplicates, increment `snippets_reused` |
| Yamldata keys match @TC-xxx tags | Flag mismatches in output |

**Side effects**: None (read-only validation)

---

## Rollback Strategy

If `status` is `"failure"` or `"partial"` and the caller requests rollback:

1. Iterate through `side_effects` array
2. For entries with `operation: "create"` and `rollback_action: "delete"`:
   - Delete the file
3. For entries with `operation: "update"` and `rollback_action: "revert"`:
   - Revert to pre-execution state (requires agent to have saved backup)
4. Do NOT touch files that existed before this skill invocation

**Note**: Rollback is a best-effort operation. The agent (not this skill) is
responsible for backing up existing files before invoking this skill.

---

## Rules Summary

| # | Rule | Enforced By |
|---|---|---|
| 1 | Feature scenario steps must only reference snippets | VALIDATE phase |
| 2 | Snippet internal expansion prefers built-in REST glue | COMPOSE phase |
| 3 | Java step is last resort | COMPOSE phase |
| 4 | Each scenario must have `@TC-xxx` tag binding to yamldata key | MATERIALIZE phase |
| 5 | Test data is isolated in `.yml` files | MATERIALIZE phase |
| 6 | Contract info received from agent (from api-contract-discovery or api-contract-hint.md) | INTAKE phase |
| 7 | Fuzzy match existing snippets before creating new ones | MATCH phase |
| 8 | Parameterize snippets for reuse across scenarios | COMPOSE phase |
| 9 | Skill produces self-contained output context | Output schema |
| 10 | Skill records all side effects for observability and rollback | Side effects array |

---

## Version History

| Version | Date | Changes |
|---|---|---|
| `1.0.0` | 2026-05-08 | Initial release. Enterprise architecture with input/output schema, side effects, idempotency, rollback, and business-semantic execution phases. |
