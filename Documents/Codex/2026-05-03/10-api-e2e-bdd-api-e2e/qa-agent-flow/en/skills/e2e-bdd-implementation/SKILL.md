---
name: e2e-bdd-implementation
version: "1.0.0"
domain: e2e-testing
layer: automation
intent: >
  Implement E2E BDD scenarios as executable browser-based automation using a
  three-phase hybrid approach: static analysis for known steps, Playwright MCP
  exploration for unknown steps, and end-to-end validation. Map business-level
  scenario steps to reusable snippets, built-in Playwright glue, element.json
  locators, and custom Java steps. Prefer reuse over creation.
fingerprint:
  required_inputs:
    feature_file: "Path to E2E .feature file with @e2e or @ui tags"
    glue_catalog: "Playwright built-in glue step catalog (step-glue-catalog.md)"
    app_url: "URL of the running application under test"
  optional_inputs:
    existing_snippets: "Existing .snippet files for reuse"
    existing_elements: "Existing element.json locator files"
    existing_yamldata: "Existing .yml test data files"
  environment:
    - "Running web application accessible at app_url"
    - "Playwright MCP available for UI exploration"
    - "Maven/Gradle project with Cucumber + Playwright BDD framework"
    - "Built-in Playwright glue (element/UI/assert) available"
    - "Java step definition classes exist or can be created"
tags:
  - e2e
  - ui
  - bdd
  - cucumber
  - automation
  - playwright
  - snippet
  - element
  - yamldata
side_effects:
  - operation: "create"
    target: ".snippet files"
    description: "New snippet macros for business-level scenario steps"
  - operation: "create_or_update"
    target: "element.json files"
    description: "Element locator mappings discovered via Playwright MCP"
  - operation: "create_or_update"
    target: ".yml test data files"
    description: "UI test data fixtures"
  - operation: "create_or_update"
    target: "Java step definition classes"
    description: "Custom Java steps when built-in glue is insufficient"
  - operation: "read_only"
    target: "Application UI via Playwright MCP"
    description: "UI exploration for unknown steps; no state mutation"
idempotency: >
  Re-running on the same feature file with the same inputs produces identical output.
  Duplicate snippets are detected via regex pattern comparison and skipped.
  Existing element.json entries are preserved unless the locator strategy changes.
  Existing yamldata entries with matching keys are preserved unless data schema changes.
rollback: >
  If validation fails after generation, delete newly created .snippet, .element.json,
  and .yml files. Do NOT delete files that existed before this skill invocation.
  MCP exploration state is ephemeral and requires no rollback.
---

# E2E BDD Implementation Skill

## Overview

| Attribute | Value |
|---|---|
| **Name** | `e2e-bdd-implementation` |
| **Domain** | E2E Testing |
| **Layer** | Automation |
| **Version** | `1.0.0` |
| **Idempotency** | Yes |
| **Side Effects** | File creation/modification + Playwright MCP read-only exploration |

## When to Use

- An E2E `.feature` file exists and needs automation assets
- UI element locators need to be discovered or verified
- Snippets, element.json, yamldata, or Java steps need to be created/updated

## When NOT to Use

- API-only scenarios → use `api-bdd-implementation`
- Pure UI exploration without a feature file → use `playwright-mcp-e2e-generation`
- Only E2E test execution/debug → use `automation-stabilization`

---

## Input Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["feature_file", "glue_catalog", "app_url"],
  "properties": {
    "feature_file": {
      "type": "string",
      "description": "Absolute or relative path to the E2E .feature file"
    },
    "app_url": {
      "type": "string",
      "description": "URL of the running application under test"
    },
    "glue_catalog": {
      "type": "string",
      "description": "Path to Playwright step-glue-catalog.md"
    },
    "snippet_dirs": {
      "type": "array",
      "items": {"type": "string"},
      "description": "Directories to scan for existing .snippet files",
      "default": ["."]
    },
    "element_dirs": {
      "type": "array",
      "items": {"type": "string"},
      "description": "Directories to scan for existing element.json files",
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
        "app_url": {"type": "string"},
        "phase1_result": {
          "type": "object",
          "properties": {
            "known_steps": {"type": "array"},
            "unknown_steps": {"type": "array"}
          }
        },
        "phase2_result": {
          "type": "object",
          "properties": {
            "explored_steps": {"type": "array"},
            "discovered_elements": {"type": "array"}
          }
        },
        "phase3_result": {
          "type": "object",
          "properties": {
            "validation_passed": {"type": "boolean"},
            "failed_steps": {"type": "array"}
          }
        },
        "step_mappings": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "scenario": {"type": "string"},
              "step": {"type": "string"},
              "snippet": {"type": "string"},
              "phase_discovered": {"type": "string", "enum": ["static", "mcp"]},
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
              "type": {"type": "string", "enum": ["snippet", "element_json", "yamldata", "java"]},
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
              "type": {"type": "string", "enum": ["snippet", "element_json", "yamldata", "java"]},
              "match_type": {"type": "string", "enum": ["exact", "fuzzy"]}
            }
          }
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
            "enum": ["create", "update", "none", "mcp_explore"],
            "description": "mcp_explore = read-only UI exploration via Playwright MCP"
          },
          "file_path": {"type": "string"},
          "file_type": {
            "type": "string",
            "enum": ["snippet", "element_json", "yamldata", "java", "feature"]
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
        "steps_known_static": {"type": "integer"},
        "steps_unknown": {"type": "integer"},
        "steps_explored_mcp": {"type": "integer"},
        "snippets_created": {"type": "integer"},
        "snippets_reused": {"type": "integer"},
        "elements_discovered": {"type": "integer"},
        "elements_reused": {"type": "integer"},
        "glue_steps_composed": {"type": "integer"},
        "java_steps_created": {"type": "integer"},
        "yamldata_entries_created": {"type": "integer"},
        "yamldata_entries_updated": {"type": "integer"},
        "phase3_passed": {"type": "integer"},
        "phase3_failed": {"type": "integer"}
      }
    }
  }
}
```

---

## Execution Flow (Business Semantic Layer)

This skill uses a three-phase hybrid approach. Each phase is stateless —
it consumes the previous phase's context and produces a new context.
The agent (not the skill) persists context between phases.

```text
PHASE 1: RECOGNIZE
  ├─ Load feature + existing snippets + glue catalog + element.json
  ├─ Exact snippet match → KNOWN
  ├─ Fuzzy snippet match → KNOWN
  └─ No match → UNKNOWN
     Output: known_steps + unknown_steps inventory

PHASE 2: EXPLORE (Playwright MCP, unknown steps only)
  ├─ MCP executes unknown steps via natural language
  ├─ Record: operation, element, locator, input value
  ├─ Reverse-generate:
  │   ├─ element.json (new elements, getByTestId preferred)
  │   ├─ snippet (glue or Java internally)
  │   └─ yamldata (test data)
  └─ Merge with Phase 1, deduplicate
     Output: enriched asset inventory

PHASE 3: VALIDATE
  ├─ Execute complete scenario with generated implementation
  ├─ Success → Done
  └─ Failure → Analyze → Fix → Retry
     Output: validation result + final context
```

---

## Core Constraint

> **Feature file scenario steps must only reference snippets.**
>
> Snippets (`.snippet` files) are the only construct allowed at the scenario level.
> A snippet internally expands into built-in glue steps, other snippet references, or Java step definitions.

---

## Phase Details

### PHASE 1: RECOGNIZE — Static Analysis

For each scenario step:

| Classification | Criteria | Next Phase |
|---|---|---|
| **Exact match** | Step text matches a `.snippet` `@When` regex exactly | Reuse snippet |
| **Fuzzy match** | Semantic similarity ≥ 80% against existing snippets | Reuse with parameterization |
| **Unknown** | No match above 50% threshold | Phase 2: EXPLORE |

**Key rule**: Phase 1 known steps must NOT trigger MCP.

**Side effects**: None (read-only phase)

**Observability**: `steps_known_static`, `steps_unknown`

### PHASE 2: EXPLORE — Playwright MCP Discovery

For each UNKNOWN step:

1. **Open Playwright MCP**
2. **Execute the step using natural language** from the feature file
3. **Record the execution**:
   - Operation type: click, type, navigate, select, assert, scroll...
   - Target element: what was interacted with
   - Locator used: how MCP found it
   - Input value: what was typed/selected
   - Page state: what was visible/expected

4. **Reverse-generate assets**:

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
   - Map natural language step to built-in Playwright glue
   - If mappable → Snippet expands to glue steps referencing element keys
   - If not mappable → Create Java step → Snippet references it

   **c. Yamldata**: Record input values for dynamic data management

5. **Merge with Phase 1 results and deduplicate**

**Element Locator Priority** (when MCP discovers an element):

```text
getByTestId > getByRole > getByLabel > getByPlaceholder > getByText
```

- **Avoid**: CSS selectors, XPath, index-based selectors
- **Avoid**: Hard waits; prefer Playwright auto-wait

**Side effects**:
```json
{
  "operation": "mcp_explore",
  "file_path": "n/a",
  "file_type": "feature",
  "reason": "UI exploration for unknown scenario steps",
  "rollback_action": "none"
}
```

```json
{
  "operation": "create",
  "file_path": "<feature_name>.element.json",
  "file_type": "element_json",
  "reason": "Element locators discovered via Playwright MCP",
  "rollback_action": "delete"
}
```

**Observability**: `steps_explored_mcp`, `elements_discovered`, `elements_reused`

### PHASE 3: VALIDATE — End-to-End Verification

1. Execute the complete scenario using the generated implementation
2. If all steps pass → `status: "success"`
3. If any step fails:
   - Analyze failure cause:
     - Missing element? → Update element.json, re-explore
     - Undefined step? → Create/adjust snippet
     - Data issue? → Update yamldata
     - Locator wrong? → Re-run MCP exploration
   - Fix root cause
   - Re-run validation

**Side effects**: None (read-only validation, unless fixes trigger file updates)

**Observability**: `phase3_passed`, `phase3_failed`

---

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

---

## Rollback Strategy

If `status` is `"failure"` or `"partial"` and the caller requests rollback:

1. Iterate through `side_effects` array
2. For entries with `operation: "create"` and `rollback_action: "delete"`:
   - Delete the file
3. For entries with `operation: "update"` and `rollback_action: "revert"`:
   - Revert to pre-execution state (requires agent to have saved backup)
4. Do NOT touch files that existed before this skill invocation
5. MCP exploration is ephemeral — no rollback needed for `mcp_explore` entries

**Note**: Rollback is a best-effort operation. The agent (not this skill) is
responsible for backing up existing files before invoking this skill.

---

## Rules Summary

| # | Rule | Enforced By |
|---|---|---|
| 1 | Feature scenario steps must only reference snippets | Phase 3 validation |
| 2 | Phase 1 known steps must NOT trigger MCP | Phase 1 logic |
| 3 | Phase 2 only explores unknown steps | Phase 2 logic |
| 4 | Snippet internal expansion prefers built-in Playwright glue | Snippet creation rules |
| 5 | Java step is last resort | Snippet creation rules |
| 6 | Element locator priority: `getByTestId` first | Phase 2 MCP discovery |
| 7 | Avoid fragile selectors (CSS/XPath/index) | Phase 2 MCP discovery |
| 8 | Fuzzy match existing snippets before creating new ones | Phase 1 RECOGNIZE |
| 9 | Parameterize snippets for reuse across scenarios | Snippet creation rules |
| 10 | Skill produces self-contained output context | Output schema |
| 11 | Skill records all side effects for observability and rollback | Side effects array |

---

## Version History

| Version | Date | Changes |
|---|---|---|
| `1.0.0` | 2026-05-08 | Initial release. Enterprise architecture with input/output schema, three-phase hybrid execution (static + MCP explore + validate), side effects, idempotency, rollback, and business-semantic phases. |
