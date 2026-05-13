# Maven Profiles for Cucumber 4.x

Profile-driven execution: each profile fixes glue path, default tag expression, plugins, and parallelism. Callers add scope via `--tags`.

## Recommended pom.xml structure

```xml
<project>
  <properties>
    <cucumber.version>4.8.0</cucumber.version>
    <restassured.version>4.5.1</restassured.version>
    <hamcrest.version>2.2</hamcrest.version>
    <playwright.version>1.40.0</playwright.version>
    <junit.version>4.13.2</junit.version>
  </properties>

  <dependencies>
    <dependency>
      <groupId>io.cucumber</groupId>
      <artifactId>cucumber-java</artifactId>
      <version>${cucumber.version}</version>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>io.cucumber</groupId>
      <artifactId>cucumber-junit</artifactId>
      <version>${cucumber.version}</version>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>io.cucumber</groupId>
      <artifactId>cucumber-picocontainer</artifactId>
      <version>${cucumber.version}</version>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>io.rest-assured</groupId>
      <artifactId>rest-assured</artifactId>
      <version>${restassured.version}</version>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>io.rest-assured</groupId>
      <artifactId>json-schema-validator</artifactId>
      <version>${restassured.version}</version>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>com.microsoft.playwright</groupId>
      <artifactId>playwright</artifactId>
      <version>${playwright.version}</version>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>org.hamcrest</groupId>
      <artifactId>hamcrest</artifactId>
      <version>${hamcrest.version}</version>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>junit</groupId>
      <artifactId>junit</artifactId>
      <version>${junit.version}</version>
      <scope>test</scope>
    </dependency>
  </dependencies>

  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-surefire-plugin</artifactId>
        <version>3.0.0</version>
        <configuration>
          <includes>
            <include>**/RunCucumberTests.java</include>
          </includes>
          <!-- Do NOT add <testFailureIgnore>true</testFailureIgnore> — Hard Rule 7 -->
        </configuration>
      </plugin>
    </plugins>
  </build>

  <profiles>
    <!-- API only -->
    <profile>
      <id>api</id>
      <properties>
        <cucumber.options>
          --glue com.hellen.tests.api
          --plugin pretty
          --plugin html:target/cucumber-reports/api.html
          --plugin json:target/cucumber-reports/api.json
        </cucumber.options>
      </properties>
    </profile>

    <!-- E2E only -->
    <profile>
      <id>e2e</id>
      <properties>
        <cucumber.options>
          --glue com.hellen.tests.e2e
          --plugin pretty
          --plugin html:target/cucumber-reports/e2e.html
          --plugin json:target/cucumber-reports/e2e.json
        </cucumber.options>
      </properties>
    </profile>

    <!-- Everything -->
    <profile>
      <id>all</id>
      <properties>
        <cucumber.options>
          --glue com.hellen.tests
          --plugin pretty
          --plugin html:target/cucumber-reports/all.html
          --plugin json:target/cucumber-reports/all.json
        </cucumber.options>
      </properties>
    </profile>

    <!-- Smoke (intended for PR check) -->
    <profile>
      <id>smoke</id>
      <properties>
        <cucumber.options>
          --glue com.hellen.tests
          --tags "@smoke and not @wip and not @flaky"
          --plugin pretty
          --plugin html:target/cucumber-reports/smoke.html
          --plugin json:target/cucumber-reports/smoke.json
        </cucumber.options>
      </properties>
    </profile>

    <!-- CI nightly (full regression including flakes for visibility) -->
    <profile>
      <id>nightly</id>
      <properties>
        <cucumber.options>
          --glue com.hellen.tests
          --tags "(@smoke or @regression) and not @wip"
          --threads 4
          --plugin pretty
          --plugin html:target/cucumber-reports/nightly-${env.BUILD_ID}.html
          --plugin json:target/cucumber-reports/nightly-${env.BUILD_ID}.json
        </cucumber.options>
      </properties>
    </profile>
  </profiles>
</project>
```

## Runner class

ONE runner class per top-level glue, in `src/test/java/com/hellen/tests/RunCucumberTests.java`:

```java
package com.hellen.tests;

import io.cucumber.junit.Cucumber;
import io.cucumber.junit.CucumberOptions;
import org.junit.runner.RunWith;

@RunWith(Cucumber.class)
@CucumberOptions(
    features = "features",                       // top-level features dir
    glue = { "com.hellen.tests" },               // overridden by profile if needed
    plugin = { "pretty" }                        // overridden by profile
)
public class RunCucumberTests {
}
```

The pom profile's `cucumber.options` augments / overrides the annotation. Both must point to the same glue space.

## Common invocations

```bash
# API tests for one story
mvn test -Papi -Dcucumber.options="--tags '@story-48217'"

# Smoke before PR
mvn test -Psmoke

# Everything, parallel
mvn test -Pall -Dcucumber.options="--tags 'not @wip' --threads 4"

# One feature file (path-based, no tag needed)
mvn test -Pall -Dcucumber.options="features/api/auth/login.feature"

# Dry run — what WOULD match this filter?
mvn test -Pall -Dcucumber.options="--dry-run --tags '@smoke'"

# Nightly with retry of failures (CI uses this)
mvn test -Pnightly -Dcucumber.options="--retry 1"

# Pass an env-driven baseUrl
mvn test -Papi \
  -Dcucumber.options="--tags '@smoke'" \
  -Dtest.api.baseUrl=https://staging.example.com
```

## Shell-quoting reminder

Cucumber 4.x tag expressions use `or`, `and`, `not` — words that are also shell tokens in some forms. Always quote:

```bash
# ✅ Right (single quotes inside double quotes)
mvn test -Dcucumber.options="--tags '@smoke or @regression'"

# ❌ Wrong — shell may eat `or`
mvn test -Dcucumber.options="--tags @smoke or @regression"

# ❌ Wrong — Cucumber 4.x doesn't parse commas
mvn test -Dcucumber.options="--tags @smoke,@regression"
```

On Windows CMD, escape double quotes:
```cmd
mvn test -Dcucumber.options="--tags \"@smoke or @regression\""
```

## Why profiles, not just CLI args

A long `-Dcucumber.options="..."` is unreadable, unreusable, and prone to drift. Profiles:
- Encode the team's standard scopes in pom.xml.
- Make CI configs short (just `mvn -Psmoke test`).
- Let new contributors discover what scopes exist via `mvn help:all-profiles`.

Add a new profile when:
- A scope is invoked > 3 times across CI / docs / Makefile.
- The scope's tag expression is non-trivial (≥ 3 tag operators).

Don't add a profile for a one-off run; use `-Dcucumber.options` directly.

## Verifying profile correctness

```bash
# Show effective POM with profile applied
mvn help:effective-pom -Pall | grep -A 1 'cucumber.options'

# List all profiles
mvn help:all-profiles
```

After editing profiles, run `mvn test -Pall -Dcucumber.options="--dry-run"` to ensure the suite still resolves all glue.
