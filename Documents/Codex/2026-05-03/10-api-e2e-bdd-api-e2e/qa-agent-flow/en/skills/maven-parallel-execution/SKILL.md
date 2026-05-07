---
name: maven-parallel-execution
description: Plan safe Maven execution when API and E2E agents may run in parallel by isolating workspaces, target directories, local Maven repositories, and reports.
---

# Maven Parallel Execution

Use this skill before any API or E2E agent runs Maven while another agent may run tests at the same time.

## Policy

```text
Never let two agents write the same target/ directory in parallel.
Never run mvn clean in a shared workspace while another agent is running Maven.
If Maven output cannot be isolated, run Maven serially.
```

## Preferred Strategy

Use separate workspaces:

```bash
git worktree add ../repo-api-agent HEAD
git worktree add ../repo-e2e-agent HEAD
```

Run each agent in its own worktree:

```bash
mvn test -Dgroups=api
mvn verify -Dgroups=e2e
```

## Shared Workspace Fallback

If agents must share one workspace, require a parameterized build directory in `pom.xml`:

```xml
<properties>
  <agent.id>local</agent.id>
</properties>

<build>
  <directory>${project.basedir}/target-${agent.id}</directory>
</build>
```

Then run:

```bash
mvn test -Dagent.id=api-agent -Dmaven.repo.local=.m2/api-agent
mvn verify -Dagent.id=e2e-agent -Dmaven.repo.local=.m2/e2e-agent
```

## Report Rule

All reports and artifacts must be under `${project.build.directory}`, not hard-coded `target/`:

- Surefire reports
- Failsafe reports
- Allure results
- Cucumber JSON
- Screenshots
- Playwright traces

## Output

```md
## Maven Parallel Execution Plan

| Item | Decision |
| --- | --- |
| Strategy | isolated worktree / isolated target / serialized |
| Agent ID | |
| Maven command | |
| Build output directory | |
| Local Maven repository | |
| Reports directory | |
| Parallel-safe | Yes / No |
```
