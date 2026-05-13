---
description: From an ADO user story, dispatch api-test-agent and/or e2e-test-agent in parallel based on bddFeatureFiles paths
argument-hint: <ADO user story id or url>
---

You are running `/parallel-tdd` for ADO user story: **$ARGUMENTS**

## Phase 1 — Load and normalize the ADO user story

Fetch the user story via the ADO MCP server using the id/url in `$ARGUMENTS`.

<!--
  TODO (one-time config): replace `mcp__ado__get_work_item` below with the
  actual tool name exposed by your configured ADO MCP server (check the
  available tools list or `.mcp.json`).
-->

Call the ADO MCP tool (e.g. `mcp__ado__get_work_item`) with the parsed id.
The response is the standard ADO work-item shape: `{ id, rev, fields: {...} }`.

Extract THREE values from `fields`. This phase owns all data cleaning so
downstream phases receive plain, ready-to-use values.

### 1.1 — Story id

Use `System.Id`, falling back to the top-level `id`.

### 1.2 — Feature paths (`bddFeatureFiles`)

Read the field, trying these keys in order (case-insensitive after the first
miss): `Custom.BddFeatureFiles`, `Custom.BDDFeatureFiles`, `Custom.FeatureFiles`.

The value is typically a STRING, not a native array. Parse it like so:

- If the string starts with `[` → `JSON.parse(value)`
- Else if it contains `;` → split on `;`, trim each
- Else split on newlines, trim each
- Drop empty entries

If parsing yields an empty array, or the field itself is missing, STOP and
report the raw value to the user. Do not guess.

### 1.3 — Acceptance criteria text

Read the AC, trying these keys in order; use the first non-empty value:

1. `Microsoft.VSTS.Common.AcceptanceCriteria` (canonical ADO field)
2. `acceptanceCriteria` (friendly name some MCP servers expose)
3. `Custom.AcceptanceCriteria` (custom template variant)

The value is HTML. Strip it to plain text BEFORE passing it on:

- Drop wrapping tags (`<div>`, `<p>`, `<br>`, …)
- Convert `<ol><li>…</li></ol>` to a numbered list (`1.`, `2.`, …)
- Convert `<ul><li>…</li></ul>` to a `- ` bulleted list
- Decode HTML entities (`&quot;` → `"`, `&amp;` → `&`, `&#39;` → `'`)

Pass `id`, the parsed `feature paths`, and the cleaned `AC text` to Phase 2.

## Phase 2 — Classify each feature file path (STRICT)

For each path in `bddFeatureFiles`:

- contains `/api` → put in **api bucket**
- contains `/ui`  → put in **ui bucket**
- contains BOTH   → put in BOTH buckets
- contains NEITHER → STOP. List the offending path(s) and ask the user
  to fix the path or the classification rule. Do NOT default-route.

Also verify each path exists on disk. If any file is missing, list the
missing paths and ask the user how to proceed before dispatching.

## Phase 3 — Dispatch agents

Dispatch ONE agent per non-empty bucket:

- api bucket non-empty → dispatch **api-test-agent** (`.claude/agents/api-test-agent.md`)
- ui bucket non-empty  → dispatch **e2e-test-agent** (`.claude/agents/e2e-test-agent.md`)
- BOTH non-empty → send a SINGLE message containing BOTH Agent tool calls
  so they run concurrently. Do not await one before launching the other.

Framework conventions, naming, and layer discipline live inside the agent
files — do not duplicate them here. Each agent receives only:

1. Its bucket's feature file paths (one path per line).
2. The cleaned AC text from Phase 1.

Dispatch template:

    Agent call A — api bucket (only if api bucket non-empty):
      subagent_type: api-test-agent
      description:   "Generate API tests from BDD features"
      prompt: |
        Feature files (api bucket):
        <one path per line>

        Acceptance criteria from ADO user story <id>:
        <cleaned AC text from Phase 1>

    Agent call B — ui bucket (only if ui bucket non-empty):
      subagent_type: e2e-test-agent
      description:   "Generate E2E UI tests from BDD features"
      prompt: |
        Feature files (ui bucket):
        <one path per line>

        Acceptance criteria from ADO user story <id>:
        <cleaned AC text from Phase 1>

## Phase 4 — Reconcile

After all dispatched agents return:

- List the test files each agent created/modified, grouped by agent.
- Surface any features the agents reported skipping.
- Buckets are usually disjoint, but if a path was in BOTH buckets and both
  agents touched the same file, read it and resolve duplicate test names
  or syntactic conflicts in place.

## Phase 5 — Execute

Invoke the `run-tests` skill via the Skill tool. Report its output verbatim.

If tests fail, do NOT auto-fix. Surface the failures and ask the user how
to proceed — they may want to fix the tests or the implementation.
