# REST Assured Patterns

Concrete patterns for building requests, extracting responses, and asserting in step definitions. Java + REST Assured 4.x + Hamcrest 2.x.

## Typed client (mandatory)

Step defs MUST go through a typed client. This is non-negotiable (Hard Rule 4). Pattern:

```java
package com.hellen.tests.api.clients.auth;

import com.hellen.tests.api.support.RestAssuredConfig;
import com.hellen.tests.api.support.dto.LoginRequest;
import io.restassured.response.Response;
import io.restassured.specification.RequestSpecification;

import static io.restassured.RestAssured.given;

public class AuthClient {

    private final RequestSpecification spec;

    public AuthClient() {
        this.spec = RestAssuredConfig.baseSpec()  // base URL, content type, logging
                                     .basePath("/api/v1/auth");
    }

    public Response login(LoginRequest payload) {
        return given().spec(spec)
                      .body(payload)
                      .when().post("/login");
    }

    public Response loginRaw(String rawJson) {
        return given().spec(spec)
                      .body(rawJson)
                      .when().post("/login");
    }
}
```

Two `login` methods because:
- Typed payload (`LoginRequest`) for normal scenarios — gives compile-time safety + Jackson serialization.
- `loginRaw` for malformed-payload scenarios — you can't express invalid JSON via a typed DTO.

## Base spec (one place to configure)

```java
package com.hellen.tests.api.support;

import io.restassured.builder.RequestSpecBuilder;
import io.restassured.filter.log.LogDetail;
import io.restassured.http.ContentType;
import io.restassured.specification.RequestSpecification;

public class RestAssuredConfig {

    public static RequestSpecification baseSpec() {
        return new RequestSpecBuilder()
                .setBaseUri(System.getProperty("test.api.baseUrl", "http://localhost:8080"))
                .setContentType(ContentType.JSON)
                .setAccept(ContentType.JSON)
                .log(LogDetail.URI)                    // log request URI; full body only on failure
                .build();
    }
}
```

ALL clients build from `baseSpec()`. Never call `RestAssured.given()` from a step def.

## Step def → client → assertion

```java
@When("I POST to {string} with body:")
public void iPostToWithBody(String path, String body) {
    Response response;
    if ("/api/v1/auth/login".equals(path)) {
        response = authClient.loginRaw(body);
    } else {
        throw new IllegalStateException("Unknown path: " + path);
    }
    ctx.setLastResponse(response);
}

@Then("the response status is {int}")
public void theResponseStatusIs(int expected) {
    assertThat(ctx.getLastResponse().statusCode(), equalTo(expected));
}

@Then("the response body has {string} equal to {string}")
public void theResponseBodyHasEqualTo(String path, String expected) {
    String actual = ctx.getLastResponse().jsonPath().getString(path);
    assertThat(actual, equalTo(expected));
}
```

Three responsibilities, three methods. Don't fuse "do action + check status + check body" into one step def.

## Authenticated requests

Pattern: a step like `Given I am authenticated as "jane@example.com"` populates `ScenarioContext.authToken`. Subsequent requests pick it up automatically via the client.

```java
public Response createOrder(OrderRequest payload) {
    RequestSpecification s = given().spec(spec);
    if (ctx.getAuthToken() != null) {
        s = s.header("Authorization", "Bearer " + ctx.getAuthToken());
    }
    return s.body(payload).when().post("/orders");
}
```

Never make every step def add headers manually. The client owns auth wiring.

## Response extraction patterns

| Goal | Pattern |
|------|---------|
| Status code | `response.statusCode()` |
| Single field by path | `response.jsonPath().getString("error.code")` |
| Whole body to DTO | `response.as(LoginResponse.class)` |
| Header | `response.header("Retry-After")` |
| Response time (ms) | `response.time()` |
| Raw body string | `response.asString()` |
| List of field values | `response.jsonPath().getList("items.sku")` |

## Assertion idioms (Hamcrest)

Prefer Hamcrest over JUnit's `assertEquals`:

```java
import static org.hamcrest.MatcherAssert.assertThat;
import static org.hamcrest.Matchers.*;

assertThat(response.statusCode(), equalTo(200));
assertThat(response.time(), lessThan(500L));
assertThat(response.jsonPath().getString("token"), matchesPattern("^eyJ[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+$"));
assertThat(response.jsonPath().getList("errors"), hasSize(greaterThan(0)));
assertThat(response.asString(), not(containsStringIgnoringCase("user")));   // no-enumeration assertion
```

Hamcrest matchers compose, give better failure messages, and integrate cleanly with REST Assured.

## Doc strings → JSON body

Feature file:
```gherkin
When I POST to "/api/v1/auth/login" with body:
  """
  { "email": "jane@example.com", "password": "Correct-Horse-Battery-9!" }
  """
```

Step def:
```java
@When("I POST to {string} with body:")
public void iPostWithBody(String path, String body) {  // body = the doc string
    Response r = authClient.loginRaw(body);
    ctx.setLastResponse(r);
}
```

The doc string arrives as a `String`. Cucumber 4.x treats it as the last argument when present.

## Data tables → DTOs

Feature file:
```gherkin
Given the following users exist:
  | email             | role  |
  | jane@example.com  | user  |
  | admin@example.com | admin |
```

Step def — recommended: register a `@DataTableType` once in a `support/CommonTypes.java`:

```java
@DataTableType
public UserSeed userSeedEntry(Map<String, String> row) {
    return new UserSeed(row.get("email"), row.get("role"));
}
```

Then in your step def:
```java
@Given("the following users exist:")
public void theFollowingUsersExist(List<UserSeed> users) {
    users.forEach(u -> {
        userClient.create(u);
        ctx.registerCleanup(() -> userClient.delete(u.email()));
    });
}
```

Avoid `List<Map<String,String>>` in step defs — pushes parsing into the test logic. Convert at the boundary.

## Response timing assertions

For `Then the response time is under 500 ms`:

```java
@Then("the response time is under {int} ms")
public void theResponseTimeIsUnderMs(int threshold) {
    long ms = ctx.getLastResponse().time();
    assertThat("response was " + ms + "ms",
               ms, lessThan((long) threshold));
}
```

Don't rely on wall-clock external timing — REST Assured tracks it per request.

## Retry & flakiness control

For idempotent endpoints, single-shot is fine. For known-flaky setup endpoints, use REST Assured's filter pattern or `Awaitility`:

```java
await().atMost(5, SECONDS)
       .pollInterval(200, MILLIS)
       .until(() -> authClient.healthCheck().statusCode() == 200);
```

NEVER `Thread.sleep` in step defs or clients.

## Logging on failure only

Default to `LogDetail.URI`. On failure, use REST Assured's `.log().ifValidationFails()`:

```java
given().spec(spec)
       .body(payload)
       .when().post("/login")
       .then()
       .log().ifValidationFails()    // full request/response only when assertion fails
       .statusCode(200);
```

Keeps green-test output clean; gives full diagnostics when something breaks.
