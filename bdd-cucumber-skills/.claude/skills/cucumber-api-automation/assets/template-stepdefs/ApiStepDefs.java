// Template step definitions class for Cucumber 4.x + REST Assured.
//
// Copy to: src/test/java/com/<org>/tests/api/stepdefs/<area>/<Feature>StepDefs.java
// Then:
//   1. Replace <Feature>, <org>, <area> placeholders.
//   2. Import or inject the area's typed client (e.g. AuthClient).
//   3. Add @Given/@When/@Then methods matching the .feature file's steps.
//   4. Register cleanup actions on ctx for any server-side state you create.

package com.hellen.tests.api.stepdefs.<area>;

import com.hellen.tests.api.clients.<area>.<Feature>Client;
import com.hellen.tests.api.support.FixtureLoader;
import com.hellen.tests.api.support.ScenarioContext;
import com.hellen.tests.api.support.dto.*;

import io.cucumber.java.After;
import io.cucumber.java.Before;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import io.restassured.response.Response;

import static io.restassured.module.jsv.JsonSchemaValidator.matchesJsonSchemaInClasspath;
import static org.hamcrest.MatcherAssert.assertThat;
import static org.hamcrest.Matchers.*;

public class <Feature>StepDefs {

    private final ScenarioContext ctx;
    private final <Feature>Client client;

    // Cucumber 4.x picocontainer injects fresh instances per scenario.
    public <Feature>StepDefs(ScenarioContext ctx, <Feature>Client client) {
        this.ctx = ctx;
        this.client = client;
    }

    // ---------------------------------------------------------------------
    // Lifecycle
    // ---------------------------------------------------------------------

    @Before
    public void beforeScenario() {
        // Per-scenario init. Keep this minimal — most setup belongs in @Given steps.
    }

    @After
    public void afterScenario() {
        // Drain LIFO so children clean up before parents.
        ctx.drainCleanup();
    }

    // ---------------------------------------------------------------------
    // Given — preconditions
    // ---------------------------------------------------------------------

    @Given("a registered user {string} with password {string}")
    public void aRegisteredUserWithPassword(String email, String password) {
        UserSeed seed = FixtureLoader.load("<area>/users/default", UserSeed.class)
                .withEmail(email)
                .withPassword(password);
        client.createUser(seed);
        ctx.registerCleanup(() -> client.deleteUser(seed.email()));
    }

    // ---------------------------------------------------------------------
    // When — actions
    // ---------------------------------------------------------------------

    @When("I POST to {string} with body:")
    public void iPostToWithBody(String path, String body) {
        // Body arrives as the doc string immediately following this step in the feature.
        Response r = client.postRaw(path, body);
        ctx.setLastResponse(r);
    }

    // ---------------------------------------------------------------------
    // Then — assertions
    // ---------------------------------------------------------------------

    @Then("the response status is {int}")
    public void theResponseStatusIs(int expected) {
        assertThat(ctx.getLastResponse().statusCode(), equalTo(expected));
    }

    @Then("the response body matches schema {string}")
    public void theResponseBodyMatchesSchema(String schemaPath) {
        String body = ctx.getLastResponse().asString();
        assertThat(body, matchesJsonSchemaInClasspath("schemas/" + schemaPath + ".json"));
    }

    @Then("the response body has {string} equal to {string}")
    public void theResponseBodyHasEqualTo(String jsonPath, String expected) {
        String actual = ctx.getLastResponse().jsonPath().getString(jsonPath);
        assertThat(actual, equalTo(expected));
    }

    @Then("the response time is under {int} ms")
    public void theResponseTimeIsUnderMs(int threshold) {
        long ms = ctx.getLastResponse().time();
        assertThat("response was " + ms + "ms", ms, lessThan((long) threshold));
    }

    @Then("the response body does NOT contain the word {string}")
    public void theResponseBodyDoesNotContainTheWord(String word) {
        assertThat(ctx.getLastResponse().asString(),
                   not(containsStringIgnoringCase(word)));
    }
}

// ---------------------------------------------------------------------
// ScenarioContext — referenced above. Place once in:
//   src/test/java/com/<org>/tests/api/support/ScenarioContext.java
// ---------------------------------------------------------------------
//
// package com.hellen.tests.api.support;
//
// import io.restassured.response.Response;
// import java.util.ArrayDeque;
// import java.util.Deque;
//
// public class ScenarioContext {
//     private Response lastResponse;
//     private String   authToken;
//     private final Deque<Runnable> cleanup = new ArrayDeque<>();
//     private boolean schemaAssertedManually;
//
//     public Response getLastResponse()             { return lastResponse; }
//     public void setLastResponse(Response r)       { this.lastResponse = r; }
//
//     public String getAuthToken()                  { return authToken; }
//     public void setAuthToken(String t)            { this.authToken = t; }
//
//     public void registerCleanup(Runnable action)  { cleanup.push(action); }
//     public boolean isSchemaAssertedManually()     { return schemaAssertedManually; }
//
//     public void drainCleanup() {
//         while (!cleanup.isEmpty()) {
//             Runnable r = cleanup.pop();
//             try { r.run(); } catch (RuntimeException e) {
//                 // log and continue; don't let one cleanup failure block others
//                 System.err.println("[cleanup] " + e.getMessage());
//             }
//         }
//     }
// }
