---
name: api-contract-discovery
version: "1.0.0"
domain: api-testing
layer: contract-discovery
intent: >
  Parse Swagger/OpenAPI documentation and match business-level descriptions
  to concrete API endpoints, methods, request schemas, and response schemas.
  Bridge business language to technical API contracts.
fingerprint:
  required_inputs:
    swagger_source: "Path or URL to Swagger JSON/YAML file"
    query: "Business description to match against API endpoints"
  optional_inputs:
    match_mode: "fuzzy (default) or exact matching strategy"
  environment:
    - "Swagger/OpenAPI JSON or YAML accessible via file path or HTTP URL"
    - "Network access if swagger_source is a URL"
tags:
  - api
  - swagger
  - openapi
  - contract
  - discovery
side_effects:
  - operation: "none"
    target: "Swagger document"
    description: "Read-only access to Swagger/OpenAPI documentation"
idempotency: >
  Same swagger_source + query produces identical output.
  Swagger document is not modified.
rollback: >
  No rollback needed. This skill performs read-only operations.
---

# API Contract Discovery Skill

## Overview

| Attribute | Value |
|---|---|
| **Name** | `api-contract-discovery` |
| **Domain** | API Testing |
| **Layer** | Contract Discovery |
| **Version** | `1.0.0` |
| **Idempotency** | Yes |
| **Side Effects** | None (read-only) |

## When to Use

- Need to map a business description to a concrete API endpoint
- BDD Case Design Agent needs to generate `api-contract-hint.md`
- `api-bdd-implementation` skill needs contract info but `api-contract-hint.md` is missing
- Any agent/skill needs to understand API schema from Swagger/OpenAPI

## When NOT to Use

- Contract info is already available in `api-contract-hint.md` → pass directly to `api-bdd-implementation`
- Only need to validate an existing contract → use contract testing tools
- Need to test the API behavior → use `api-bdd-implementation`

---

## Input Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["swagger_source", "query"],
  "properties": {
    "swagger_source": {
      "type": "string",
      "description": "File path or HTTP URL to Swagger JSON/YAML"
    },
    "query": {
      "type": "string",
      "description": "Business-level description to match (e.g., 'create trade allocation', 'user login')"
    },
    "match_mode": {
      "type": "string",
      "enum": ["fuzzy", "exact"],
      "description": "Matching strategy",
      "default": "fuzzy"
    }
  }
}
```

## Output Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["status", "matches", "observability"],
  "properties": {
    "status": {
      "type": "string",
      "enum": ["success", "partial", "failure"],
      "description": "Overall execution status"
    },
    "matches": {
      "type": "array",
      "description": "Matched API endpoints sorted by confidence",
      "items": {
        "type": "object",
        "required": ["path", "method", "confidence"],
        "properties": {
          "path": {"type": "string", "description": "API path (e.g., /api/v1/trades/allocation)"},
          "method": {"type": "string", "enum": ["GET", "POST", "PUT", "PATCH", "DELETE"] },
          "summary": {"type": "string", "description": "Operation summary from Swagger"},
          "tags": {"type": "array", "items": {"type": "string"}, "description": "Swagger tags"},
          "operationId": {"type": "string"},
          "request_schema": {
            "type": "object",
            "description": "Request body schema (ref resolved)"
          },
          "response_schema": {
            "type": "object",
            "description": "Response schema for 2xx status (ref resolved)"
          },
          "parameters": {
            "type": "array",
            "items": {"type": "object"},
            "description": "Path, query, header parameters"
          },
          "confidence": {
            "type": "number",
            "minimum": 0,
            "maximum": 1,
            "description": "Match confidence score"
          }
        }
      }
    },
    "context": {
      "type": "object",
      "description": "Execution context for downstream consumption",
      "properties": {
        "swagger_version": {"type": "string"},
        "api_title": {"type": "string"},
        "api_version": {"type": "string"},
        "base_path": {"type": "string"},
        "total_endpoints": {"type": "integer"}
      }
    },
    "side_effects": {
      "type": "array",
      "description": "Always empty for this read-only skill",
      "items": {"type": "object"}
    },
    "dependencies": {
      "type": "array",
      "description": "External dependencies discovered",
      "items": {"type": "string"}
    },
    "observability": {
      "type": "object",
      "properties": {
        "endpoints_scanned": {"type": "integer"},
        "endpoints_matched": {"type": "integer"},
        "match_mode": {"type": "string"},
        "highest_confidence": {"type": "number"},
        "parse_time_ms": {"type": "integer"}
      }
    }
  }
}
```

---

## Execution Flow

```text
LOAD     → Read Swagger JSON/YAML from file path or URL
           Tools: Read (file) or Bash curl (URL)

PARSE    → Extract paths, operations, schemas, parameters
           Build indexed catalog: [path, method, summary, tags, operationId]

MATCH    → Semantic matching against query
           Extract keywords from query (verbs, nouns)
           Score against each endpoint:
             - path match (e.g., "trade" in /api/v1/trades)
             - summary match (e.g., "allocation" in summary)
             - tag match (e.g., "trade" tag)
             - operationId match
           Sort by confidence descending

OUTPUT   → Return top N matches with full schema
           If no match above threshold → status: "failure", suggest manual input
```

---

## Matching Algorithm

For each endpoint in Swagger:

1. **Extract searchable text**:
   - `path` (e.g., `/api/v1/trades/allocation`)
   - `method` (e.g., `POST`)
   - `summary` (e.g., "Create a trade allocation")
   - `tags` (e.g., `["trade", "allocation"]`)
   - `operationId` (e.g., "createTradeAllocation")

2. **Score the query against the endpoint**:
   | Signal | Weight | Example |
   |---|---|---|
   | Verb in summary matches query verb | 0.30 | "create" ↔ "create" |
   | Noun in path matches query noun | 0.25 | "trade" in `/api/v1/trades` |
   | Noun in summary matches query noun | 0.20 | "allocation" ↔ "allocation" |
   | Tag matches query noun | 0.15 | "trade" tag |
   | Method aligns with verb semantics | 0.10 | POST ↔ "create" |

3. **Confidence thresholds**:
   - `≥ 0.80`: High confidence — likely correct match
   - `0.50–0.80`: Medium confidence — present as candidate
   - `< 0.50`: Low confidence — likely incorrect

4. **Return top 3 matches** (or fewer if confidence drops below 0.50)

---

## Example

**Input:**
```json
{
  "swagger_source": "src/main/resources/swagger.json",
  "query": "create trade allocation",
  "match_mode": "fuzzy"
}
```

**Output:**
```json
{
  "status": "success",
  "matches": [
    {
      "path": "/api/v1/trades/allocation",
      "method": "POST",
      "summary": "Create a trade allocation",
      "tags": ["trade"],
      "operationId": "createTradeAllocation",
      "request_schema": {
        "type": "object",
        "properties": {
          "eventType": {"type": "string"},
          "data": {"type": "array"},
          "tradeIds": {"type": "array"}
        }
      },
      "response_schema": {
        "type": "object",
        "properties": {
          "code": {"type": "integer"},
          "status": {"type": "string"},
          "data": {"type": "object"}
        }
      },
      "confidence": 0.95
    }
  ],
  "context": {
    "swagger_version": "3.0.1",
    "api_title": "Trade API",
    "api_version": "1.0.0",
    "base_path": "/api/v1",
    "total_endpoints": 45
  },
  "observability": {
    "endpoints_scanned": 45,
    "endpoints_matched": 1,
    "match_mode": "fuzzy",
    "highest_confidence": 0.95
  }
}
```

---

## Integration with api-bdd-implementation

```text
api-automation-agent
  ├─ Has api-contract-hint.md?
  │   ├─ Yes → Pass directly to api-bdd-implementation
  │   └─ No  → Call api-contract-discovery
  │            ├─ Input: swagger_source + business query from feature
  │            └─ Output: contract info (endpoint, method, schema)
  │                 ↓
  │            Pass contract info to api-bdd-implementation
  │                 ↓
  │            api-bdd-implementation receives contract in input
  └─ api-bdd-implementation executes (no Swagger parsing inside)
```

**Key principle**: `api-bdd-implementation` never parses Swagger directly.
It receives pre-resolved contract info either from:
- `api-contract-hint.md` (upstream BDD Case Design Agent), or
- `api-contract-discovery` output (agent-mediated fallback)

---

## Rules Summary

| # | Rule |
|---|---|
| 1 | This skill is read-only — never modifies Swagger document |
| 2 | Always return multiple matches if confidence is similar |
| 3 | Resolve `$ref` references in schemas before returning |
| 4 | If no match above 0.50 threshold → status: "failure" |
| 5 | Agent (not this skill) decides which match to use |
| 6 | Skill produces self-contained output context |

---

## Version History

| Version | Date | Changes |
|---|---|---|
| `1.0.0` | 2026-05-08 | Initial release. Atomic skill for Swagger/OpenAPI contract discovery with semantic matching. |
