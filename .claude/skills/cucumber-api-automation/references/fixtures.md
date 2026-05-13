# Fixtures

How test data is stored, loaded, mutated, and torn down. Goal: scenarios are isolated, fixtures are reusable, and there is no `new User(...)` clutter in step defs.

## File layout

```
src/test/resources/fixtures/
├── auth/
│   ├── valid-login.json
│   ├── locked-account.json
│   └── users/
│       ├── jane.json
│       └── admin.json
├── orders/
│   ├── simple-order.json
│   └── empty-cart.json
└── _common/
    └── geo/
        └── us-zip.json
```

Rules:
- Path mirrors the `<area>` of the feature: `features/api/auth/*.feature` ↔ `fixtures/auth/*.json`.
- `_common/` for cross-area shared data; underscore prefix prevents accidental glob matches.
- File names are descriptive nouns (`valid-login`, not `test1`).

## FixtureLoader (single entry point)

```java
package com.hellen.tests.api.support;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.io.InputStream;
import java.util.Objects;

public final class FixtureLoader {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    private FixtureLoader() {}

    public static <T> T load(String relativePath, Class<T> type) {
        String full = "/fixtures/" + relativePath + ".json";
        try (InputStream in = Objects.requireNonNull(
                FixtureLoader.class.getResourceAsStream(full),
                "Fixture not found: " + full)) {
            return MAPPER.readValue(in, type);
        } catch (IOException e) {
            throw new IllegalStateException("Failed to load fixture " + full, e);
        }
    }

    public static String loadRaw(String relativePath) {
        // returns the raw JSON string — for doc-string parity scenarios
        ...
    }
}
```

Usage:
```java
LoginRequest req = FixtureLoader.load("auth/valid-login", LoginRequest.class);
```

ONE loader, ONE path convention, ONE error message format. If a fixture is missing, the test fails fast with a clear message.

## Immutability + builders

Fixtures loaded from JSON should be IMMUTABLE. Mutations create new instances via builders:

```java
public final class LoginRequest {
    private final String email;
    private final String password;

    public LoginRequest(String email, String password) {
        this.email = email;
        this.password = password;
    }

    public String email() { return email; }
    public String password() { return password; }

    public LoginRequest withPassword(String newPassword) {
        return new LoginRequest(email, newPassword);
    }

    public LoginRequest withEmail(String newEmail) {
        return new LoginRequest(newEmail, password);
    }
}
```

Step def:
```java
LoginRequest base = FixtureLoader.load("auth/valid-login", LoginRequest.class);
LoginRequest wrong = base.withPassword("wrong-password");
authClient.login(wrong);
```

This pattern avoids hidden mutation that surfaces across scenarios.

## Use records (Java 16+) if available

```java
public record LoginRequest(String email, String password) {
    public LoginRequest withPassword(String p) { return new LoginRequest(email, p); }
    public LoginRequest withEmail(String e)    { return new LoginRequest(e, password); }
}
```

Records give immutability for free. Add the `withX` helpers explicitly only where mutation is needed.

## Fluent builders for complex objects

For payloads with > 4 fields or nested structures, use a builder:

```java
OrderRequest order = OrderRequest.builder()
        .customer("jane@example.com")
        .item("SKU-1", 2)
        .item("SKU-2", 1)
        .shipTo("94110", "US")
        .build();
```

Implementation: standard immutable-builder pattern. Don't reach for Lombok unless it's already in the codebase.

## Parameterized fixtures via Scenario Outline

If `valid-login.json` is the happy-path fixture and you want variations:

```gherkin
Scenario Outline: Login fails with stable error code
  When I login with email "<email>" and password "<password>"
  Then the response status is 401

  Examples:
    | email             | password        |
    | jane@example.com  | wrong-password  |
    | nobody@example.com| anything        |
```

```java
@When("I login with email {string} and password {string}")
public void iLoginWith(String email, String password) {
    LoginRequest base = FixtureLoader.load("auth/valid-login", LoginRequest.class);
    Response r = authClient.login(base.withEmail(email).withPassword(password));
    ctx.setLastResponse(r);
}
```

Fixture provides DEFAULTS; Examples table provides DIFFERENCES. Don't duplicate the fixture in the Examples table.

## Cleanup discipline

Every fixture-driven creation registers cleanup:

```java
@Given("a registered user {string}")
public void aRegisteredUser(String email) {
    UserSeed seed = FixtureLoader.load("auth/users/" + emailToFile(email), UserSeed.class);
    userClient.create(seed);
    ctx.registerCleanup(() -> userClient.delete(seed.email()));
}
```

`ScenarioContext.registerCleanup` accumulates `Runnable`s; `@After` drains them LIFO so children are cleaned before parents.

## Generated data (when shared fixtures don't fit)

For uniqueness-sensitive scenarios (e.g. each scenario needs a different email), generate inside the step def:

```java
String uniqueEmail = "user-" + UUID.randomUUID() + "@example.test";
```

Use:
- `@example.test` TLD or your project's reserved test domain — NEVER `@gmail.com` etc.
- `UUID.randomUUID()` for collision-free uniqueness.
- A deterministic seed via `Random(scenario.getName().hashCode())` ONLY when reproducibility is needed.

## Anti-patterns

### Anti-pattern: inline JSON in step defs

```java
String body = "{\"email\":\"jane@example.com\",\"password\":\"x\"}";  // ← no
```

Move to a fixture. Inline JSON is brittle (escaping), uncomposable, and untyped.

### Anti-pattern: mutable static fixture

```java
public static final LoginRequest LOGIN = new LoginRequest("jane", "x");

@When("I do bad thing")
public void doBadThing() {
    LOGIN.setPassword("wrong");   // ← mutates shared state, breaks parallel & later scenarios
}
```

Always create new instances via builders/withers.

### Anti-pattern: fixture-per-scenario explosion

If you find yourself creating `valid-login-wrong-pw.json`, `valid-login-empty-pw.json`, `valid-login-too-long.json` ... the fixture is being misused. ONE base fixture; vary via builders or Scenario Outlines.

### Anti-pattern: fixtures that contain assertions

```json
{
  "email": "jane@example.com",
  "expectedStatusCode": 401   ← no
}
```

Fixtures are INPUT only. Expected values live in the feature file (Scenario Outline Examples or step text).
