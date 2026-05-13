// Template step definitions class for Cucumber 4.x + Playwright Java.
//
// Copy to: src/test/java/com/<org>/tests/e2e/stepdefs/<area>/<Feature>StepDefs.java
// Then:
//   1. Replace <Feature>, <org>, <area> placeholders.
//   2. Inject or construct the Page Objects you need (LoginPage, etc.).
//   3. Add @Given/@When/@Then methods matching the .feature file's steps.
//   4. Locators stay in Page Objects; step defs orchestrate + assert.

package com.hellen.tests.e2e.stepdefs.<area>;

import com.hellen.tests.e2e.pages.<area>.<Page>Page;
import com.hellen.tests.e2e.support.E2eScenarioContext;

import com.microsoft.playwright.Page;
import com.microsoft.playwright.Browser;
import com.microsoft.playwright.BrowserContext;
import com.microsoft.playwright.Tracing;

import io.cucumber.java.After;
import io.cucumber.java.Before;
import io.cucumber.java.Scenario;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;

import java.nio.file.Path;
import java.nio.file.Paths;

import static com.microsoft.playwright.assertions.PlaywrightAssertions.assertThat;
import static org.hamcrest.MatcherAssert.assertThat;       // disambiguate via fully-qualified at call site if both used
import static org.hamcrest.Matchers.*;

public class <Feature>StepDefs {

    private final E2eScenarioContext ctx;
    private <Page>Page <page>Page;

    public <Feature>StepDefs(E2eScenarioContext ctx) {
        this.ctx = ctx;
    }

    // ---------------------------------------------------------------------
    // Lifecycle
    // ---------------------------------------------------------------------

    @Before
    public void beforeScenario() {
        BrowserContext browserContext = ctx.browser().newContext();
        if (ctx.isCi()) {
            browserContext.tracing().start(new Tracing.StartOptions()
                    .setScreenshots(true)
                    .setSnapshots(true)
                    .setSources(true));
        }
        ctx.setContext(browserContext);
        ctx.setPage(browserContext.newPage());
    }

    @After(order = 0)   // runs FIRST — capture state before teardown
    public void onFailureCapture(Scenario scenario) {
        if (scenario.isFailed()) {
            byte[] screenshot = ctx.page().screenshot();
            scenario.attach(screenshot, "image/png", "failure-screenshot");

            if (ctx.isCi()) {
                Path trace = Paths.get("target/traces/" + scenario.getId() + ".zip");
                ctx.context().tracing().stop(new Tracing.StopOptions().setPath(trace));
            }
        } else if (ctx.isCi()) {
            ctx.context().tracing().stop();
        }
    }

    @After   // runs after onFailureCapture; tears down
    public void afterScenario() {
        if (ctx.context() != null) {
            ctx.context().close();   // fresh context every scenario (Hard Rule 6)
        }
    }

    // ---------------------------------------------------------------------
    // Given — preconditions
    // ---------------------------------------------------------------------

    @Given("I am on the {string} page")
    public void iAmOnThePage(String path) {
        ctx.page().navigate(path);
        ctx.page().waitForURL("**" + path);
        this.<page>Page = new <Page>Page(ctx.page());
    }

    // ---------------------------------------------------------------------
    // When — actions
    // ---------------------------------------------------------------------

    @When("I fill {string} with {string}")
    public void iFillWith(String field, String value) {
        // Route to the right field via POM
        switch (field) {
            case "email"    -> <page>Page.fillEmail(value);
            case "password" -> <page>Page.fillPassword(value);
            default         -> throw new IllegalArgumentException("Unknown field: " + field);
        }
    }

    @When("I click the {string} button")
    public void iClickTheButton(String name) {
        if ("Sign in".equals(name)) {
            <page>Page.submit();
        } else {
            throw new IllegalArgumentException("Unknown button: " + name);
        }
    }

    // ---------------------------------------------------------------------
    // Then — assertions (PlaywrightAssertions = retrying; Hamcrest = one-shot)
    // ---------------------------------------------------------------------

    @Then("I see the inline error {string}")
    public void iSeeInlineError(String expected) {
        assertThat(<page>Page.inlineError()).hasText(expected);   // PlaywrightAssertions, retrying
    }

    @Then("the URL is still {string}")
    public void theUrlIsStill(String path) {
        assertThat(ctx.page()).hasURL("**" + path);
    }

    @Then("the {string} button becomes disabled within {int} ms")
    public void theButtonBecomesDisabledWithin(String name, int ms) {
        assertThat(<page>Page.submitButton())
                .isDisabled(new com.microsoft.playwright.assertions.LocatorAssertions.IsDisabledOptions()
                        .setTimeout(ms));
    }

    @Then("the {string} field has type {string}")
    public void theFieldHasType(String field, String type) {
        // Use POM state method for direct attribute read
        String actual = <page>Page.passwordFieldType();
        org.hamcrest.MatcherAssert.assertThat(actual, equalTo(type));
    }
}

// ---------------------------------------------------------------------
// E2eScenarioContext — place once in:
//   src/test/java/com/<org>/tests/e2e/support/E2eScenarioContext.java
// ---------------------------------------------------------------------
//
// package com.hellen.tests.e2e.support;
//
// import com.microsoft.playwright.Browser;
// import com.microsoft.playwright.BrowserContext;
// import com.microsoft.playwright.BrowserType;
// import com.microsoft.playwright.Page;
// import com.microsoft.playwright.Playwright;
//
// public class E2eScenarioContext {
//     private static final Playwright PLAYWRIGHT = Playwright.create();
//     private static final Browser BROWSER = PLAYWRIGHT.chromium().launch(
//             new BrowserType.LaunchOptions()
//                 .setHeadless(System.getenv("CI") != null));
//
//     private BrowserContext context;
//     private Page page;
//
//     public Browser browser()                 { return BROWSER; }
//     public Page page()                       { return page; }
//     public void setPage(Page p)              { this.page = p; }
//     public BrowserContext context()          { return context; }
//     public void setContext(BrowserContext c) { this.context = c; }
//     public boolean isCi()                    { return System.getenv("CI") != null; }
// }
