---
description: Normalize raw requirements into confirmed Story Contract JSON files or ADO-ready user stories
---

# Write User Stories

You are the orchestrator for requirement intake and story normalization. Your output is either a confirmed Story Contract JSON file or an ADO-ready User Story payload. In both modes, acceptance criteria must use Given/When/Then.

**Input:** `$ARGUMENTS`

---

## Step 1: Parse Arguments

Determine the source type from `$ARGUMENTS`:

- **Free-form mode:** plain text requirement, notes, or pasted draft story.
- **JSON file mode:** argument starts with `/`, `./`, `~`, or ends with `.json`.
- **ADO mode:** argument is a pure number, starts with `ado:`, or contains `dev.azure.com`.
- **Empty / invalid:** ask the user for a raw requirement, JSON file path, or ADO Work Item ID/URL.

Optional flags:
- `--target json`: write a local Story Contract JSON file. This is the default.
- `--target ado`: prepare or update an ADO User Story using ADO-ready formatting and attach/comment the full Story Contract JSON.
- `--target both`: write the local JSON file and update/prepare the ADO payload.
- `--out {dir}`: write the Story Contract JSON under `{dir}`.
- `--id {storyId}`: override or provide a local story ID when the source has none.

Default output directory:

```text
{WORKSPACE}/.claude/story-contracts/
```

---

## Step 2: Load Raw Requirement

Read these documents before normalization:
- `~/.claude/docs/requirement-to-story-methodology.md`
- `~/.claude/docs/story-contract.md`
- `~/.claude/docs/fullstack-delivery-lifecycle.md`

### Free-form mode

Use the user's text as the raw requirement. Infer missing fields only when there is enough evidence; otherwise mark them as `null` and ask during review.

### JSON file mode

Use the **Read** tool to read the source JSON.

Supported input shapes:
- Confirmed Story Contract JSON.
- Legacy OREO schema with `offlineStoryData`.
- Generic story JSON with `storyId`, `title`, `description`, and `acceptanceCriteria`.

### ADO mode

Extract the Work Item ID:
- Pure number -> use directly.
- `ado:{id}` -> extract number after `ado:`.
- Full URL -> extract the ID from the URL path.

Use the **ado-agent** MCP tool when available to fetch the Work Item. Do not use curl/PAT unless the user explicitly asks for that fallback.

---

## Step 3: Analyze Requirement And Normalize

Follow the iterative analysis loop in `~/.claude/docs/requirement-to-story-methodology.md`:

```text
Business intent -> Behavior model -> Observable evidence -> Given/When/Then ACs -> Challenge and refine
```

Required analysis activities:
1. Classify the requirement type.
2. Extract raw facts, technical notes, assumptions, and open questions.
3. Identify actor, goal, trigger, and business value.
4. Define in scope, out of scope, dependencies, constraints, and non-functional needs.
5. Model the domain entity, state transitions, actor handoffs, rules, exceptions, and observable outcomes.
6. Identify observable evidence, including business-meaningful UI evidence such as visible buttons, disabled actions, dialogs, warnings, status labels, and validation messages.
7. Use Rule and Example Mapping to derive Given/When/Then ACs.
8. Challenge and refine the draft for missing rules, missing states, missing evidence, over-specific implementation detail, and story split risk.
9. Run INVEST and testability checks.
10. Produce a Story Contract draft.

Normalize the result to the Story Contract shape:

```json
{
  "storyId": "{storyId}",
  "title": "{business-facing title}",
  "description": "{As a ..., I want ..., so that ...}",
  "persona": "{primary actor or null}",
  "storyModule": "{technical module or null}",
  "requirementAnalysis": {
    "requirementType": "{capability | workflow | rule | visibility | technical | bug-like}",
    "inScope": [],
    "outOfScope": [],
    "assumptions": [],
    "openQuestions": [],
    "dependencies": [],
    "constraints": [],
    "nonFunctionalNeeds": [],
    "readiness": "{ready | needs clarification | split recommended}"
  },
  "acceptanceCriteria": [
    {
      "id": "AC-001",
      "given": "{precondition or starting context}",
      "when": "{business action or event}",
      "then": "{expected observable outcome}",
      "observableEvidence": []
    }
  ],
  "technicalNotes": {
    "endpoint": "{endpoint or null}",
    "keyClasses": [],
    "constraints": [],
    "testLayer": "{hint only or null}"
  },
  "storyStatus": "draft",
  "lastCompletedStage": null
}
```

Normalization rules:
- Preserve business meaning. Do not add scope that is not present in the source.
- Do not invent product behavior. Put uncertain behavior in `assumptions` or `openQuestions`.
- If the source contains multiple independent outcomes, set readiness to `split recommended` and explain the proposed split.
- Split acceptance criteria into stable, testable `AC-###` Given/When/Then objects.
- Keep compound ACs readable, but split separate behaviors when they would need different verification.
- Each AC must include exactly one `given`, one `when`, and one `then` field.
- Add `observableEvidence` when a specific visible, persisted, API, audit, notification, validation, button, menu item, or dialog signal is needed to prove the business outcome.
- Store GWT field values without the leading `Given`, `When`, or `Then` keyword; add the keywords only when displaying or uploading.
- Use business-facing observable wording. UI-visible evidence such as a visible action button, disabled action, status label, or confirmation dialog is allowed when it is the business evidence.
- Do not write low-level UI operations, endpoint calls, class names, selectors, request builders, or implementation details unless the source requirement explicitly requires them.
- Preserve raw technical notes under `technicalNotes`; do not turn them into BDD naming, tags, or feature paths.
- If a required field is missing, keep it visible as `null` and ask the user to revise during the review gate.

---

## Step 4: Review Draft Contract

Display the normalized contract summary and ask the user to approve, revise, or stop.

> ### Story Contract Draft
>
> | Field | Value |
> |-------|-------|
> | Story ID | {storyId} |
> | Title | {title} |
> | Persona | {persona or "missing"} |
> | Story Module | {storyModule or "missing"} |
> | AC Count | {N} |
> | Readiness | {ready / needs clarification / split recommended} |
>
> **Description:**
> {description}
>
> **Scope:**
> - In scope: {items}
> - Out of scope: {items}
> - Dependencies: {items or "None"}
> - Constraints: {items or "None"}
> - Non-functional needs: {items or "None"}
>
> **Assumptions:**
> - {assumption or "None"}
>
> **Open Questions:**
> - {question or "None"}
>
> **Readiness Checks:**
> - INVEST: {pass / concerns}
> - Testability: {pass / concerns}
> - Split recommendation: {none or proposed split}
>
> **Acceptance Criteria:**
> 1. **AC-001**
>    - Given {given}
>    - When {when}
>    - Then {then}
>    - Evidence: {observableEvidence or "business outcome only"}
> 2. **AC-002**
>    - Given {given}
>    - When {when}
>    - Then {then}
>    - Evidence: {observableEvidence or "business outcome only"}
>
> **Technical Notes:**
> - Endpoint: {endpoint or "not provided"}
> - Key Classes: {classes or "not provided"}
> - Constraints: {constraints or "not provided"}
> - Layer Hint: {testLayer or "not provided"}
>
> **Action:**
> - **approve** - write the selected output target
> - **revise** - modify fields or ACs, then show the draft again
> - **stop** - cancel without writing a file

Wait for user response:
- **approve** -> proceed to Step 5.
- **revise** -> apply the requested changes, keep `storyStatus: "draft"`, and repeat Step 4.
- **stop** -> end with "User Story generation cancelled."

---

## Step 5: Write Output

Before writing:
- Set `storyStatus` to `"confirmed"`.
- Set `lastCompletedStage` to `"writeuserstories"`.
- Add `source` metadata when available.
- Add `generatedAt` using ISO-8601 local time when available.

### Target: JSON

Output file naming:

```text
{outputDir}/{storyId}-{titleSlug}.story.json
```

Rules:
- `titleSlug` is lowercase kebab-case.
- Remove characters outside `a-z`, `0-9`, and `-`.
- Collapse repeated dashes.
- Limit `titleSlug` to 60 characters.
- If `storyId` is missing, use `local-{YYYYMMDD-HHMMSS}`.

Create the output directory if needed, then write formatted JSON with 2-space indentation.

If the target file already exists:
- Ask before overwriting.
- If the user does not approve overwrite, write `{storyId}-{titleSlug}-{YYYYMMDD-HHMMSS}.story.json`.

### Target: ADO

Prepare an ADO-ready User Story payload:

| ADO Field | Value |
|-----------|-------|
| Title | `{title}` |
| Description | `{description}` |
| Acceptance Criteria | Numbered Given/When/Then blocks |
| Tags | `story-contract-ready` |
| Story Contract | Full normalized Story Contract JSON as an attachment or comment |

Acceptance Criteria formatting:

```text
AC-001
Given {given}
When {when}
Then {then}
Evidence:
- {observableEvidence item}

AC-002
Given {given}
When {when}
Then {then}
Evidence:
- {observableEvidence item}
```

If an ADO Work Item ID was provided, use the **ado-agent** MCP tool to update the item when available:
- update title, description, acceptance criteria, and tag `story-contract-ready`
- add the full normalized Story Contract JSON as an attachment or a clearly titled comment: `Story Contract JSON`

If no ADO target exists, output the ADO payload and the full Story Contract JSON block for upload. Do not write a local JSON file unless the user requested `--target json` or `--target both`.

---

## Step 6: Summary

Report:

> ### Story Contract Written
>
> **Output:** `{outputPath or ADO Work Item ID}`
> **Story:** `{storyId} - {title}`
> **Acceptance Criteria:** `{N}`
>
> Recommended next command for JSON output:
>
> ```bash
> /enrichstorydesign {outputPath}
> ```
>
> Use `/bdd-gen {outputPath}` directly only for simple stories where solution design enrichment is intentionally skipped.
