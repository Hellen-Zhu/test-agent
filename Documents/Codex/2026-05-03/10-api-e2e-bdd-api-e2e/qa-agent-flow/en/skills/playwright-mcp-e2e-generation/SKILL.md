---
name: playwright-mcp-e2e-generation
description: Generate Playwright E2E tests from user stories, acceptance criteria, and a runnable application by using Playwright MCP to explore real UI behavior and stable locators.
---

# Playwright MCP E2E Generation

Use this skill when E2E tests need to be generated from requirements and a runnable app.

## Flow

```text
Derive E2E scenarios
  ↓
Open app with Playwright MCP
  ↓
Explore user flow
  ↓
Capture page model and UI states
  ↓
Identify stable locators
  ↓
Generate E2E test cases
  ↓
Generate Playwright specs
  ↓
Run and return result
```

## Use Playwright MCP To

- Open and navigate the real app.
- Login and prepare user state.
- Click, type, select, submit, and verify UI behavior.
- Confirm real validation messages.
- Discover reliable locators.
- Verify generated tests against the running app.

## Locator Priority

```text
getByRole > getByLabel > getByPlaceholder > getByText > getByTestId
```

Avoid fragile CSS, XPath, index-based selectors, and hard waits.

## Output

```md
## Playwright E2E Generation Result

| Scenario | User Flow | Priority | Assertions |
| --- | --- | --- | --- |

| Page | Element | Locator |
| --- | --- | --- |

| Generated / Updated File | Purpose |
| --- | --- |
```

