# Locator JSON Catalog

Locators live in `src/test/resources/locators/<page-or-module>.json` — one file per page or module. Java step code looks them up by key via the framework's locator-loader; no locator string ever appears in Java source. This document covers the file schema, naming convention, locator-priority discipline, and the MCP-probe workflow that produces these entries.

## Why JSON instead of Java fields

| Concern | POM (rejected) | JSON catalog (this codebase) |
|---------|----------------|------------------------------|
| Selector change requires | recompile + redeploy test JAR | edit JSON, no rebuild |
| Non-Java contributors edit selectors | no — Java + IDE required | yes — JSON edit in any tool |
| Inspecting "what does this test touch" | read N Page Object files | grep one JSON tree |
| Locator stability over UI refactor | locked to whoever owned the POM | one team owns the catalog |

The JSON layer also means the **selector strategy** (testid vs role vs text) is the catalog maintainer's call, while **step authors** just consume keys. This separation is the whole point.

## File location & naming

```
src/test/resources/locators/
├── loginPage.json
├── checkoutPage.json
├── productList.json
└── common/
    └── header.json     ← shared cross-page elements (nav, footer)
```

Rules:

- One JSON per page OR per logical module (not per feature; not per scenario).
- Filename = `lowerCamelCase` matching the conceptual page key.
- Cross-page elements (nav, footer, modal frames) go under `common/`.
- **Verify the existing convention by Glob'ing `src/test/resources/locators/**/*.json` before creating a new file.** If existing files use a different convention (e.g. `kebab-case.json`), follow that — don't introduce a second style.

## Schema

Match the schema used by sibling JSON files exactly. The expected shape in this codebase is:

```json
{
  "_page": "loginPage",
  "_baseUrl": "/login",
  "locators": {
    "emailInput":     { "strategy": "testId",  "value": "login-email" },
    "passwordInput":  { "strategy": "testId",  "value": "login-password" },
    "submitButton":   { "strategy": "role",    "value": "button", "name": "Sign in" },
    "passwordToggle": { "strategy": "label",   "value": "Show password" },
    "inlineError":    { "strategy": "testId",  "value": "login-error" },
    "rememberMe":     { "strategy": "label",   "value": "Remember me" }
  }
}
```

Fields:

- `_page`: human-readable page key. Should match filename.
- `_baseUrl`: relative path or full URL the page is normally reached at. Used by snippets that navigate before interacting.
- `locators.<key>.strategy`: one of `testId | role | label | text | placeholder | css | xpath` — corresponding to Playwright's `getByX` methods. The framework's locator-loader maps strategy → Playwright API call.
- `locators.<key>.value`: the primary selector value.
- `locators.<key>.name`: required ONLY when strategy is `role`, gives the accessible name.
- `locators.<key>._comment`: REQUIRED when strategy is `text | placeholder | css | xpath` (priority < 3). Explain why and link an issue.
- `locators.<key>._todo`: present if entry was authored via fallback (app unreachable). Value is the verification reminder string.

**Confirm the actual schema by reading one existing JSON before adding entries.** If the project uses a flat `{"emailInput": "[data-testid=login-email]"}` form (raw string values), follow that form — DO NOT impose this schema on top.

## Locator priority (Hard Rule 7 in SKILL.md)

```
1. testId        ← preferred (decoupled from UI text & structure)
2. role + name   ← preferred when no testid (accessible & resilient)
3. label         ← form fields with associated <label>
4. text          ← unique buttons/links by display text
5. placeholder   ← weak, but acceptable for inputs without labels
6. css           ← only when nothing above works
7. xpath         ← LAST resort; requires comment + issue link
```

| Strategy | Survives... | Breaks on... |
|---------|------------|--------------|
| testId  | text changes, restyling, DOM refactors | testid removal (we own this) |
| role + name | text changes within reason, restyling | accessibility regressions (which we WANT to catch) |
| label   | restyling | label rewording |
| text    | restyling | any copy change |
| placeholder | restyling, label changes | placeholder change |
| css     | nothing reliable | class renaming, restructuring |
| xpath   | absolutely nothing | any DOM tweak |

Going below position 2 requires `_comment` in the JSON entry:

```json
"footerPrivacyLink": {
  "strategy": "text",
  "value": "Privacy Policy",
  "_comment": "Legacy footer link has no data-testid. Issue: PLAT-1234. Upgrade to testId once added."
}
```

## MCP probe workflow

This is the **preferred** path for populating JSON entries (Hard Rule 8 in SKILL.md). Do this BEFORE hand-authoring locator entries.

```
1. Identify target URL from .feature file or environment config.
2. mcp__playwright__browser_navigate { url: "<staging-or-dev-url>" }
3. mcp__playwright__browser_snapshot
   → returns accessibility tree
4. For each element your snippet/step needs:
   a. Search snapshot for the element by visible text or label.
   b. Find the highest-priority stable identifier on the node:
      - data-testid → use strategy: "testId"
      - role + accessible name → use strategy: "role"
      - associated label → use strategy: "label"
      - … per priority table.
   c. If only text/css available — record under "Elements missing data-testid (dev follow-up)" in the output report.
5. Write entries into src/test/resources/locators/<page>.json.
```

### When MCP probe is not possible

App not deployed yet, staging down, feature flag off — record fallback inference and tag entries with `_todo`:

```json
"newFeatureToggle": {
  "strategy": "testId",
  "value": "new-feature-toggle",
  "_todo": "verify via MCP when staging-eu reachable; testId assumed from naming convention"
}
```

A later cleanup task can `grep -r '_todo' src/test/resources/locators/` to find all unverified entries.

## What goes in the catalog — and what doesn't

| Goes in the catalog | Stays out |
|---------------------|-----------|
| Element selectors | Test data (emails, passwords, IDs) — those go to fixtures |
| Page base URLs (`_baseUrl`) | Full deployment URLs — those are env config |
| Locators for static page chrome | Locators dynamically computed per-run (use parameterized locator API instead) |
| Cross-page shared elements under `common/` | Selectors used in exactly one snippet — still goes in the catalog; locators are NEVER inline |

## Editing existing entries

When upgrading a locator's priority (e.g., text → role → testId):

1. Re-probe via MCP to confirm the higher-priority option actually exists.
2. Edit ONLY the `strategy`, `value`, and optionally `name` fields.
3. Remove the `_comment` field if it's no longer accurate.
4. Run the affected tests via `mvn test -Dcucumber.options="--tags '@<area>'"` to confirm.
5. Record the upgrade in the output report ("Entries upgraded (priority bumped)").

Do NOT delete entries when a page is removed — first Grep `src/test/java/**/*.java` to confirm no snippet/step still references the key. Stale references would compile but fail at runtime with confusing messages.
