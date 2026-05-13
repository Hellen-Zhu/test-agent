# JSON Schema Validation

How to assert response SHAPE separately from response VALUES. Catches accidental shape regressions that field-by-field assertions miss.

## Why schema validation matters

Hard Rule 8 (in SKILL.md): every non-trivial response body assertion must include a schema check.

Reason: field-equality assertions only catch field-specific bugs. A typo in the API renaming `token` to `tkn` will pass `assertThat(json.getString("token"), notNullValue())` if you also have a fallback path that reads `tkn`. Schema validation catches "this field disappeared / this field's type changed" regardless of which fields you happen to assert on.

## Schema file location

```
src/test/resources/schemas/
├── auth/
│   ├── login-success-v1.json
│   ├── login-error-v1.json
│   └── locked-account-v1.json
├── orders/
│   └── order-created-v1.json
└── _common/
    └── error-envelope-v1.json
```

Rules:
- Mirror feature areas: `features/api/<area>/` ↔ `schemas/<area>/`.
- `-v1`, `-v2` version suffix for schemas; never edit in place when shape changes.
- One schema per response variant (success vs error vs partial-success).

## Schema content (JSON Schema Draft 7)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "login-success-v1",
  "type": "object",
  "required": ["token", "userId"],
  "additionalProperties": false,
  "properties": {
    "token": {
      "type": "string",
      "pattern": "^eyJ[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+$"
    },
    "userId": {
      "type": "string",
      "format": "uuid"
    },
    "issuedAt": {
      "type": "string",
      "format": "date-time"
    }
  }
}
```

Key choices:

| Choice | When | Why |
|--------|------|-----|
| `"additionalProperties": false` | Default | Catches accidental new fields; you decide what's intentional. |
| `"additionalProperties": true` | When server may add fields freely (e.g. metadata, debug info) | Avoids false-positives on forward-compatible changes. |
| `"required": [...]` listing all stable fields | Always | Distinguishes "missing" from "null". |
| `"type": ["string", "null"]` | For nullable fields | Schema is stricter than the prose docs; nullable must be explicit. |
| Patterns for IDs / formats | For tokens, UUIDs, dates | Catches type-correct but format-wrong values. |

## Step def integration

```java
import io.restassured.module.jsv.JsonSchemaValidator;

import static org.hamcrest.MatcherAssert.assertThat;
import static io.restassured.module.jsv.JsonSchemaValidator.matchesJsonSchemaInClasspath;

@Then("the response body matches schema {string}")
public void theResponseBodyMatchesSchema(String schemaPath) {
    String body = ctx.getLastResponse().asString();
    assertThat(body, matchesJsonSchemaInClasspath("schemas/" + schemaPath + ".json"));
}
```

Usage in feature:
```gherkin
Then the response status is 200
And the response body matches schema "auth/login-success-v1"
And the response body has "userId" matching the user's id
```

Order: status check → schema check → specific field check. Schema gives you a HUGE assertion in one line; field check then targets specific values.

## Branching on status

A successful and error response have different schemas:

```java
@Then("the response status is {int}")
public void theResponseStatusIs(int expected) {
    Response r = ctx.getLastResponse();
    assertThat(r.statusCode(), equalTo(expected));
    // Auto-pick schema by status for convenience:
    String schema = (expected >= 200 && expected < 300)
            ? "auth/login-success-v1"
            : "_common/error-envelope-v1";
    // BUT only auto-assert when the feature didn't specify one explicitly.
    if (!ctx.isSchemaAssertedManually()) {
        assertThat(r.asString(), matchesJsonSchemaInClasspath("schemas/" + schema + ".json"));
    }
}
```

This makes "implicit shape check" the default: every status assertion also asserts shape unless overridden.

## Common error envelope

Most APIs share an error response shape. One schema, used across all error scenarios:

```json
// schemas/_common/error-envelope-v1.json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["error"],
  "additionalProperties": false,
  "properties": {
    "error": {
      "type": "object",
      "required": ["code", "message"],
      "additionalProperties": false,
      "properties": {
        "code": { "type": "string" },
        "message": { "type": "string" },
        "details": { "type": "object" }
      }
    },
    "requestId": { "type": "string" }
  }
}
```

ANY 4xx / 5xx response from your API should match this. If it doesn't, that's a server bug — let the test fail loudly.

## Schema evolution

When the API legitimately changes shape:

1. **Add a new schema file**: `login-success-v2.json` (don't edit `-v1`).
2. **Update step def or feature** to reference v2.
3. **Keep v1 schema** until all features using it are migrated.
4. **Delete v1** in a separate PR once unused.

Reason: a schema in-place edit silently changes what every test asserts. New file makes the change reviewable and reversible.

## Anti-patterns

### Anti-pattern: schema as documentation

```json
{
  "description": "This is the login success response. The token is a JWT.",
  "type": "object"
}
```

If `properties` is missing, the schema validates ANYTHING. Always specify shape, not just intent.

### Anti-pattern: schema generated from a single response sample

Tools like quicktype generate schemas from one sample. The resulting schema usually has `additionalProperties: true` everywhere and weak types. Generated schemas are a STARTING POINT; tighten them by hand.

### Anti-pattern: schema check skipped for "trivial" responses

A 204 No Content has no body — fine, no schema. A 200 with `{"ok": true}` STILL needs a schema (the `ok` field could become `success: true` next sprint). The bar is "non-trivial body" = "any body with at least one field".

### Anti-pattern: validation only on the happy path

The error response from `POST /login` with wrong password ALSO has a schema. Both should be validated. Error-path schema drift is more common than success-path drift.

## Quick grep

To find all schema usage:

```bash
grep -rn "matchesJsonSchemaInClasspath" src/test/java/
grep -rn "matches schema" features/
```

If you find features that say `Then the response status is 200` without a follow-up schema assertion, that's a coverage gap.
