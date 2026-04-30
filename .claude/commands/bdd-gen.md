---
description: Generate BDD Cucumber feature files (API + UI) from User Stories
---

Invoke the `bdd-agent` to run the full BDD pipeline for the given input.

## Input

`$ARGUMENTS` — one of:
- A local JSON file path (e.g. `./stories/login.json`)
- An ADO Work Item ID (e.g. `13424715`)
- An ADO Work Item URL (e.g. `https://dev.azure.com/org/project/_workitems/edit/13424715`)

## Execution

Use the **Agent** tool to invoke `bdd-agent` with the following context:

```
Source: $ARGUMENTS
Working Directory: {current working directory}
```

The bdd-agent will:
1. Load the User Story (from JSON file or via ado-agent MCP)
2. Run Phase 1 — Test Layering Analysis (API vs UI/E2E), then pause for human review
3. Run Phase 2 — BDD Feature Generation with Step Catalog scanning, then pause for human review
4. Write the approved .feature files to `src/test/resources/features/api/` and `features/ui/`
