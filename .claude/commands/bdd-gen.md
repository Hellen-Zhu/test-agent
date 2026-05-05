---
description: Generate BDD Cucumber feature files (API + UI) from confirmed or design-ready Story Contracts
---

# BDD Feature Generation Pipeline

You are the orchestrator for the BDD feature generation pipeline. You consume a confirmed or design-ready Story Contract, handle BDD review gates, and write approved feature files. Upstream story normalization and story approval belong to `/writeuserstories`; test-relevant design enrichment belongs to `/enrichstorydesign`.

This command implements the BDD segment of `~/.claude/docs/user-story-to-feature-file-flow.md`.

**Input:** `$ARGUMENTS`

---

## BDD Pipeline Input Contract

`/bdd-gen` owns the single BDD pipeline input contract definition. This does not mean Phase 1 and Phase 2 receive the same input shape. They have different input views because Phase 2 depends on the human-approved Phase 1 report and path context.

Build this contract after the Story Contract is loaded. Invoke each agent with only its own phase view.

```yaml
bddPipelineInput:
  common:
    sourcePayload: <loaded Story Contract JSON object, unchanged>
    sourceReference: <source JSON path or ADO work item reference>
    pathHints:
      explicitProjectPath: <optional --projectPath value>
      explicitE2eDir: <optional --e2eDir value>
      cwd: <current working directory>
      sourceReference: <source JSON path or ADO work item reference>

  phase1:
    stage: test_layering_analysis
    targetAgent: qa-test-analysis-agent
    input:
      sourcePayload: <bddPipelineInput.common.sourcePayload>
      reinvokeContext: <optional Phase 1 reinvoke context; only for revision runs>
    instruction: "Read and follow ~/.claude/agents/qa-test-analysis-agent.md."

  phase2:
    stage: bdd_feature_generation
    targetAgent: bdd-case-design-agent
    input:
      sourcePayload: <bddPipelineInput.common.sourcePayload>
      confirmedPhase1Report: <full human-approved Phase 1 markdown report>
      pathHints: <bddPipelineInput.common.pathHints, plus any retry hint>
      reinvokeContext: <optional Phase 2 reinvoke context; only for revision runs>
    instruction: "Read and follow ~/.claude/agents/bdd-case-design-agent.md."
```

Field rules:

| Field | Required for | Rule |
|-------|--------------|------|
| `common.sourcePayload` | Both phases | The loaded confirmed or design-ready Story Contract. It must stay unchanged. |
| `phase1.input.sourcePayload` | Phase 1 | The only business input for test layering analysis. |
| `phase2.input.sourcePayload` | Phase 2 | Naming, wording, and approved design context only. It must not add validation intent beyond Phase 1. |
| `phase2.input.confirmedPhase1Report` | Phase 2 | The human-approved Phase 1 output and the source of truth for validation intent, layer, tags, AC mapping, validation target, and observable evidence. |
| `phase2.input.pathHints` | Phase 2 | Hints only. `/bdd-gen` collects them; `bdd-case-design-agent` resolves `{E2E_DIR}`. |
| `reinvokeContext` | Revision runs only | Previous final checked output, user delta, immutable input hashes, reference snapshots, and phase-appropriate reusable discovery context. |
| `instruction` | Both phases | Points the invoked agent to its agent definition. |

Contract rules:
- Keep one contract definition with two phase-specific input views.
- Do not force Phase 1 and Phase 2 into the same input shape.
- Do not pass Phase 2-only fields such as `confirmedPhase1Report` or `pathHints` to Phase 1.
- Do not mutate, normalize, split, or repair `sourcePayload` in `/bdd-gen`.
- Do not put derived feature names, feature tags, file paths, TC IDs, or scenario grouping decisions into the input contract.
- Do not pass automation implementation context such as step catalogs, snippets, Java glue, page objects, API clients, fixtures, or helpers.

### Reinvoke Context

When the user chooses `revise`, do not manually patch the agent output in `/bdd-gen`. Re-invoke the same phase agent with a `reinvokeContext`.

Use this shape:

```yaml
reinvokeContext:
  mode: revision
  reason: user_revision | missing_context_retry
  userRevisionRequest: <exact user requested change>
  previousOutput: <previous final checked markdown output from the same phase>
  previousOutputHash: <hash if available>
  immutableInputHashes:
    sourcePayloadHash: <hash if available>
    confirmedPhase1ReportHash: <Phase 2 only; hash if available>
  referenceSnapshot:
    - path: ~/.claude/docs/{required-doc}.md
      hash: <hash if available>
      status: verified
      appliedChecks: <short list of checks already applied in the previous final output>
  reusableDiscoverySnapshot:
    e2eDir: <Phase 2 only; resolved path if previously resolved>
    featureFilesScanned: <Phase 2 only; feature files used for style/file-mode evidence>
    tcSequenceEvidence: <Phase 2 only; TC IDs observed during previous scan>
    generationContext: <Phase 2 only; previous Generation Context section>
```

Reinvoke rules:
- `previousOutput` is a candidate for delta repair, not a source of truth.
- `sourcePayload`, and the approved Phase 1 report where applicable, remain the source of truth.
- Required methodology and standards references may skip full reread only when the reference path and hash are unchanged and the previous run recorded the applied checks. If the snapshot is missing, unreadable, or changed, the agent must read the required docs again.
- Phase 1 must not reuse Phase 2 discovery context.
- Phase 2 may reuse project discovery context such as `{E2E_DIR}`, feature file style evidence, file mode evidence, and TC sequence evidence when the immutable inputs and discovery scope are unchanged.
- If the user revision changes scope, layer, naming basis, path hints, or any input hash, invalidate the affected snapshot and let the agent re-resolve that context.
- Every reinvoke must rerun the phase agent's internal quality loop and required output checks before returning.

---

## Step 1: Parse Arguments

Determine the confirmed Story Contract source from `$ARGUMENTS`.

- **Confirmed JSON contract mode:** argument starts with `/`, `./`, `~`, or ends with `.json`
- **Confirmed ADO mode:** argument is a pure number, starts with `ado:`, or contains `dev.azure.com`
- **Optional path hint:** `--projectPath {path}` or `--e2eDir {path}` provides an automation project path hint for `bdd-case-design-agent` to resolve
- **Empty / invalid:** ask the user:
  > "Please provide a confirmed or design-ready Story Contract JSON file, for example `.claude/story-contracts/{storyId}-{titleSlug}.story.json`."

---

## Step 2: Load Confirmed Story Contract

`/bdd-gen` consumes the normalized Story Contract produced by `/writeuserstories`, preferably enriched by `/enrichstorydesign`.
It does not own raw story parsing, Story Contract validation, acceptance criteria splitting, story confirmation, or solution design.

### BDD ownership boundary

- `/writeuserstories` owns Story Contract quality, schema, story readiness, AC normalization, and story approval.
- `/enrichstorydesign` owns API/UI/data/security/NFR/observability/rollout design enrichment.
- `/bdd-gen` trusts the confirmed Story Contract and does not repair, normalize, split, or rewrite story content.
- Do not derive feature tags, feature names, feature modules, business domains, or target feature paths during intake.
- `bdd-case-design-agent` owns those decisions after Phase 1 test points are confirmed.
- `/bdd-gen` owns orchestration, review gates, writing approved files, and updating source state.

### If confirmed JSON contract mode:

Use the **Read** tool to read the JSON file generated by `/writeuserstories` or `/enrichstorydesign`. Do not validate the full story schema here; preserve the loaded content as the source payload for downstream BDD agents.

### If confirmed ADO mode:

Extract the Work Item ID:
- Pure number → use directly
- `ado:{id}` → extract number after `ado:`
- Full URL → extract the ID from the URL path

Use the **ado-agent** MCP tool to fetch the Work Item. The preferred handoff is still the local design-ready Story Contract JSON file written by `/enrichstorydesign`.

ADO mode is allowed only when the Work Item contains the full Story Contract JSON as an attachment or a clearly titled comment `Story Contract JSON` or `Design-Ready Story Contract JSON`. ADO-formatted title/description/AC text alone is not enough for `/bdd-gen`; stop and ask the user to rerun `/writeuserstories` and, when design context is needed, `/enrichstorydesign`.

---

## Step 3: Handoff Sanity Check

Perform only interface-level checks required to call the downstream BDD agents:
- The source must be a loaded Story Contract JSON object from `/writeuserstories` or `/enrichstorydesign`.
- The payload must contain enough envelope fields to route the pipeline: story identity/title context, acceptance criteria payload, and source path or ADO work item reference.
- If the source is raw notes, legacy raw OREO data, ADO-formatted text without `Story Contract JSON`, or an unreadable file, stop with:
  > "This source is not a confirmed Story Contract handoff. Run `/writeuserstories` first, then rerun `/bdd-gen` with the confirmed contract."
- If `solutionDesign` is missing or not approved, display a Design Context Gap. For simple low-risk stories, the user may explicitly proceed with reduced design context. For API, UI workflow, permission, data, integration, or release-risk stories, recommend `/enrichstorydesign` before continuing.

Do not validate AC shape, requirement analysis completeness, story readiness, business scope, or solution design quality. Those checks belong to `/writeuserstories` and `/enrichstorydesign`.

---

## Step 4: BDD Source Summary And Path Hints

Do not resolve `projectPath` / `{E2E_DIR}` in `/bdd-gen`. Collect path hints only and let `bdd-case-design-agent` resolve the automation project path.

Path hints may include:

- Explicit `--projectPath {path}` or `--e2eDir {path}` from `$ARGUMENTS`
- Current working directory
- Source JSON path or ADO work item reference
- Any project/repo hints present in the loaded Story Contract

Display a short non-blocking summary for traceability only. Do not ask the user to approve, revise, or stop here; story approval belongs to `/writeuserstories`.

> ### BDD Source Contract
>
> | Field | Value |
> |-------|-------|
> | Story | {storyId} — {title} |
> | Persona | {persona or "not provided"} |
> | Story Module | {storyModule or "not provided"} |
> | Acceptance Criteria | {count from source payload} |
> | Requirement Analysis | {present / not provided} |
> | Solution Design | {approved / draft / missing} |
> | Technical Notes | {present / not provided} |
> | Path Hints | {explicit path hint / cwd / source reference / none} |
>
> Proceeding to BDD test layering.

If approved `solutionDesign` exists, treat `technicalNotes` as fallback trace context only. Do not let `technicalNotes` override `solutionDesign`.

---

## Step 5: Generate And Review Phase 1 Layering

**Agent:** `qa-test-analysis-agent`
**Phase:** Phase 1 — Test Layering Analysis
**Role:** Senior QA Test Analyst with FX Structured Products Domain Experience
**Purpose:** Produce the approved-test-point candidate plan. This phase decides validation intent, test layer, traceability, risk tags, and observable evidence. It must not design feature files, scenario grouping, or automation steps.

Use the **Agent** tool to invoke `qa-test-analysis-agent` with `bddPipelineInput.phase1`:
- `stage`: `test_layering_analysis`
- `targetAgent`: `qa-test-analysis-agent`
- `input.sourcePayload`: loaded Story Contract JSON object, unchanged
- `instruction`: `Read and follow ~/.claude/agents/qa-test-analysis-agent.md.`

Accept only the final markdown report defined by the Output Contract in `~/.claude/docs/test-layering-standards.md` after `qa-test-analysis-agent` has completed its methodology checks and standards checks.

If `qa-test-analysis-agent` returns a `PROCESS_GAP`, display the Process Gap Report exactly, stop the pipeline, and ask the user to restore or provide the missing reference before rerunning `/bdd-gen`. Do not ask for Phase 1 approval and do not continue to Phase 2.

Display the **complete** agent output to the user, followed by review guidance:

> {Insert the complete qa-test-analysis-agent output here, unmodified.}
>
> ---
>
> **Review Checklist:**
> - Is every acceptance criterion and observable evidence item represented by an approved validation intent?
> - Are API vs UI/E2E layer assignments correct for the validation targets?
> - Are FX TRF / derivatives domain gaps surfaced instead of guessed?
> - Are test point IDs, tags, validation targets, and observable evidence acceptable for Phase 2 generation?
> - Are there missing, duplicated, or wrong-layer validation points?
>
> **Action:**
> - **approve** — Layering plan is correct, proceed to generate Feature files
> - **revise** — Adjustments needed (e.g., move test points between layers, change test point IDs/tags, add/remove test points — please specify)
> - **stop** — Cancel this generation

Wait for user response:
- **approve** → proceed to Step 6 with the confirmed layering plan
- **revise** → build `bddPipelineInput.phase1.input.reinvokeContext` with the previous final Phase 1 output and the exact user revision request, re-invoke `qa-test-analysis-agent`, re-display this Step 5 review prompt, wait for confirmation
- **stop** → end pipeline: "Pipeline terminated."

---

## Step 6: Generate And Review Phase 2 Feature Content

**Agent:** `bdd-case-design-agent`
**Phase:** Phase 2 — BDD Feature Generation
**Role:** Senior BDD + Case Design Specialist
**Purpose:** Convert the approved Phase 1 report into business-readable API/UI feature content. This phase owns Gherkin structure, feature file naming, TC IDs, run-command guidance, and self-repair of BDD/case-design defects. It must not change Phase 1 validation intent or make automation implementation reuse decisions.

Do not load step catalogs, scan snippets/Java steps, scan feature files, or derive TC sequences in `/bdd-gen`.
Existing `.feature` style/file-mode/TC-sequence context is owned by `bdd-case-design-agent`. Step definition/snippet/Java/helper implementation reuse is owned by `automation-agent`, not by `/bdd-gen` or `bdd-case-design-agent`.

If Phase 2 reports `E2E_DIR` as `CONTEXT_GAP`, ask the user for an explicit path hint and re-run Phase 2 with that hint.

Use the **Agent** tool to invoke `bdd-case-design-agent` with `bddPipelineInput.phase2`:
- `stage`: `bdd_feature_generation`
- `targetAgent`: `bdd-case-design-agent`
- `input.sourcePayload`: same loaded Story Contract JSON object, unchanged
- `input.confirmedPhase1Report`: full human-approved Phase 1 markdown report from Step 5
- `input.pathHints`: collected hints from Step 4, plus any user-provided retry hint if Phase 2 previously reported `E2E_DIR` as `CONTEXT_GAP`
- `instruction`: `Read and follow ~/.claude/agents/bdd-case-design-agent.md.`

Accept only the final markdown result defined by the Output Contract in `~/.claude/docs/bdd-feature-generation-standards.md` after `bdd-case-design-agent` has completed its methodology design loop, standards Design Integrity Rules, internal quality loop, and self-check. Do not accept candidate drafts or partially checked output.

If `bdd-case-design-agent` returns a `PROCESS_GAP`, display the Process Gap Report exactly, stop the pipeline, and ask the user to restore or provide the missing reference before rerunning Phase 2. Do not ask for feature-content approval and do not write files.

Display the **complete** agent output to the user, followed by review guidance:

> {Insert the complete bdd-case-design-agent output here, unmodified.}
>
> ---
>
> **Review Checklist:**
> - Are there any `CONTEXT_GAP` items that block safe feature generation?
> - Do feature file names, top-level tags, and Feature descriptions follow the API/UI layer conventions?
> - Are compatible test points grouped into the fewest readable scenarios without losing TP traceability?
> - Does each generated scenario assert the approved validation target and observable evidence?
> - Does create-mode feature content include a Feature Annotation comment block?
> - Does every generated scenario include a Scenario Annotation comment block with TP, AC, validation target, observable evidence, and business test data intent?
> - Are annotations free of step definitions, snippets, Java methods, page objects, API clients, fixtures, helpers, selectors, endpoints, payload files, and implementation commands?
> - Does the same business meaning use one consistent step pattern across scenarios?
> - Do API/UI scenarios stay in business language without request builders, endpoints, selectors, clicks, fills, page objects, API clients, fixtures, or helper names?
> - Does every Scenario have a complete Given/When/Then structure?
> - Do tags, TC IDs, and scenario summaries follow naming conventions (`@TC-{FEATURE_MODULE}-API-{NNN}`, `@TC-{FEATURE_MODULE}-{SUBTYPE}-UI-{NNN}`, `Scenario: [TC-...] Should ...`)?
> - Is the AC Coverage Matrix complete? Are there any uncovered ACs?
>
> **Action:**
> - **approve** — Feature content is correct, write to files
> - **revise** — Adjustments needed (e.g., modify scenario steps, change parameters, add/remove scenarios — please specify)
> - **stop** — Cancel this generation

Wait for user response:
- **approve** → proceed to Step 7
- **revise** → build `bddPipelineInput.phase2.input.reinvokeContext` with the previous final Phase 2 output, reusable Phase 2 discovery snapshot, and the exact user revision request, re-invoke `bdd-case-design-agent`, re-display this Step 6 review prompt, wait for confirmation
- **stop** → end pipeline: "Pipeline terminated."

---

## Step 7: Write Feature Files

Extract the gherkin content from the confirmed Phase 2 output.

Determine the target paths:
- Use the API/UI file paths reported in the approved Phase 2 output.
- Use the API/UI file modes reported in the approved Phase 2 output.
- Do not re-derive feature names, domains, or feature paths in the orchestrator.
- If a layer has zero scenarios in the approved Phase 2 output, do not create a file for that layer.

### For each feature file with scenarios (API and/or UI):

1. **Create directory if needed:**
   ```bash
   mkdir -p $(dirname {targetPath})
   ```

2. **Apply the approved file mode:**
   - **create** → Write the complete feature content as a new file. If the file already exists unexpectedly, stop and ask for review.
   - **append** → Read the existing file and append ONLY the approved new Scenario Annotation + Scenario/Scenario Outline blocks. Do not append top-level tags, `Feature:`, descriptions, Feature Annotation, or `Background:`.
   - **not generated** → Skip this layer.

3. **Write** using Write tool (new) or Edit tool (append)

---

## Step 8: Update Story State

After feature files are written, persist the generation results back to the source.

### If ADO mode:

Use **ado-agent** MCP tool to perform two operations:

1. **ADD_COMMENT** — Post the full coverage summary as a comment on the Work Item, with the following content body (include the Scenario Breakdown and AC Coverage Matrix from Step 6):

   > **BDD Feature file generated.**
   >
   > **Files:** {target API feature file path and/or target UI feature file path}
   >
   > **Feature tags:** `@api @{featureTag}` / `@playwright @{featureTag}`
   > **Total scenarios:** {N}
   >
   > **Scenario Breakdown:**
   >
   > {Scenario Breakdown table from Phase 2 output}
   >
   > **AC Coverage Matrix:**
   >
   > {AC Coverage Matrix table from Phase 2 output}
   >
   > **Uncovered ACs:** {list or "None"}
   >
   > **Cucumber Run Commands:**
   >
   > {Cucumber run commands from Phase 2 output}

2. **UPDATE_TAGS** — Add tag `bdd-ready` to the Work Item's `System.Tags`.

### If JSON file mode:

Use the **Edit** tool to update the source JSON file with:

- `lastCompletedStage`: `"writebddfeatures"`
- `apiFeatureFile`: written API feature file path, if generated
- `uiFeatureFile`: written UI feature file path, if generated
- `bddFeatureFile`: legacy field; set only when exactly one feature file was generated
- `bddType`: `"api"` / `"ui"` / `"api+ui"` based on generated layers
- `tcTags`: array of TC tag strings (e.g. `["@TC-TRADE-API-001", "@TC-TRADE-CREATE-UI-001"]`)

---

## Step 9: Summary

Report final completion:

> ### BDD Generation Complete
>
> **Story:** {storyId} — {title}
>
> **Files written:**
> - {list only files that were created or appended, with scenario counts}
>
> **State updated:**
> - {ADO: "Comment posted + `bdd-ready` tag added to Work Item #{id}" / JSON: "Source file updated with `lastCompletedStage: writebddfeatures`"}
>
> **Cucumber Run Commands:**
> ```bash
> {commands from the approved Phase 2 output}
> ```
>
> **Next steps:**
> - Review the generated feature files
> - Invoke `automation-agent` with the approved feature files as the golden source to implement or reuse step definitions/snippets/helpers
> - Run `cucumber --dry-run` after automation implementation to verify step bindings
