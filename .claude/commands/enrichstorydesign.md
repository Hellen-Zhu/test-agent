---
description: Enrich a confirmed Story Contract with test-relevant solution design before BDD test design
---

# Enrich Story Design

You are the orchestrator for test-relevant solution design enrichment. You consume a confirmed Story Contract from `/writeuserstories`, add reviewed design evidence needed by QA and automation, and write a design-ready Story Contract for `/bdd-gen`.

This command does not own raw requirement analysis, story approval, BDD layering, feature file generation, implementation, or release execution.

**Input:** `$ARGUMENTS`

---

## Step 1: Parse Arguments

Determine the Story Contract source and optional design source from `$ARGUMENTS`.

Supported source forms:
- Local Story Contract JSON path.
- ADO Work Item ID or URL only when the Work Item contains `Story Contract JSON`.
- Optional free-form design notes pasted after the source.
- Optional flags:
  - `--copy`: write a separate `{storyId}-{titleSlug}.design.story.json` instead of updating the source file.
  - `--out {dir}`: with `--copy`, write the enriched Story Contract JSON under `{dir}`.
  - `--project {path}`: project path for repository context.

If the source is missing, ask for a confirmed Story Contract JSON path from `/writeuserstories`.

---

## Step 2: Load Inputs

Read these documents before analysis:
- `~/.claude/docs/fullstack-delivery-lifecycle.md`
- `~/.claude/docs/story-contract.md`

Read the Story Contract JSON and preserve all existing fields.

If design notes are provided, treat them as design evidence. If not provided, inspect only explicitly available artifacts:
- Existing API specs, controllers, routes, DTOs, schemas, or service interfaces.
- Existing UI routes, pages, components, copy, state models, or design references.
- Existing database models, migrations, event contracts, permissions, audit, observability, or feature flags.

Do not invent design details. Mark unknowns as `openDesignQuestions`.

---

## Step 3: Test-Relevant Design Analysis

Analyze only design facts that affect test design, test layering, feature generation, data setup, assertions, or automation maintainability.

Required perspectives:
1. Behavior model: roles, permissions, business states, state transitions, rules, negative paths, and edge cases.
2. UI evidence: entry points, user flows, visible controls, visible states, validation messages, dialogs, empty/loading/error states, accessibility risks, and stable automation hooks when available.
3. API contract: operation purpose, method/path, auth context, request contract, response contract, error contract, status semantics, idempotency, side effects, and contract file references.
4. Data and integration evidence: entities and state, persistence rules, audit records, emitted events, async behavior, external dependencies, and failure handling.
5. Test data and environment: required roles, seed data, fixtures, feature flags, environment dependencies, mocks/stubs, and cleanup needs.
6. Non-functional and risk evidence: performance, security, accessibility, compliance, reliability, localization, and compatibility constraints that should influence tests.
7. Observability evidence: logs, metrics, traces, dashboards, alerts, or audit trails that can prove backend or operational outcomes.
8. Test implications: API validation targets, UI validation targets, YAML response contract files, extra API assertions, UI observable evidence, grouping hints, and automation constraints.

Challenge the design for missing contracts, unclear ownership, UI/API mismatch, data lifecycle gaps, untestable behavior, and rollout risk.

---

## Step 4: Enrich Story Contract

Add or update this object. Preserve existing business story fields unless the user explicitly approves a change.

```json
{
  "solutionDesign": {
    "designStatus": "draft",
    "designSources": [],
    "behaviorModel": {
      "actorsAndRoles": [],
      "permissions": [],
      "businessStates": [],
      "stateTransitions": [],
      "businessRules": [],
      "negativeAndEdgeCases": []
    },
    "uiDesign": {
      "entryPoints": [],
      "primaryUserFlows": [],
      "visibleElements": [],
      "visibleStates": [],
      "validationMessages": [],
      "dialogsAndPrompts": [],
      "emptyLoadingErrorStates": [],
      "accessibilityNotes": [],
      "automationHooks": []
    },
    "apiDesign": {
      "operations": [
        {
          "name": "",
          "purpose": "",
          "method": "",
          "path": "",
          "authContext": "",
          "requestContract": "",
          "responseContract": "",
          "errorContract": "",
          "statusSemantics": [],
          "idempotency": null,
          "sideEffects": []
        }
      ],
      "contractFiles": [],
      "compatibility": []
    },
    "dataAndIntegrationDesign": {
      "entitiesAndState": [],
      "persistenceRules": [],
      "auditRecords": [],
      "eventsOrMessages": [],
      "asyncBehavior": [],
      "externalDependencies": [],
      "failureHandling": [],
      "cleanupNeeds": []
    },
    "testDataAndEnvironment": {
      "requiredRoles": [],
      "fixturesOrSeedData": [],
      "featureFlags": [],
      "environmentDependencies": [],
      "mockOrStubNeeds": []
    },
    "nonFunctionalAndRisk": {
      "performance": [],
      "security": [],
      "reliability": [],
      "accessibility": [],
      "compliance": [],
      "localization": [],
      "compatibility": []
    },
    "observabilityDesign": {
      "logs": [],
      "metrics": [],
      "traces": [],
      "dashboards": [],
      "alerts": []
    },
    "releaseAndCompatibility": {
      "migrationStrategy": [],
      "rollbackPlan": [],
      "releaseSequencing": []
    },
    "testDesignImplications": {
      "apiValidationTargets": [],
      "uiValidationTargets": [],
      "apiContractAssertions": [],
      "extraApiAssertions": [],
      "uiObservableEvidence": [],
      "testDataNeeds": [],
      "scenarioGroupingHints": [],
      "automationConstraints": []
    },
    "openDesignQuestions": []
  }
}
```

Use `technicalNotes` as input evidence for `solutionDesign` when useful, but do not treat it as authoritative after design is approved. Update `technicalNotes` only as a concise compatibility summary for downstream tools. Do not put detailed test design context only in `technicalNotes`; design evidence belongs in `solutionDesign`.

Allowed story refinement:
- Clarify AC observable evidence when design confirms how the business outcome is proven.
- Add assumptions or open questions discovered during design.
- Add technical constraints or dependencies.

Forbidden story changes without explicit user approval:
- Expanding business scope.
- Changing accepted behavior.
- Removing ACs.
- Rewriting ACs to match implementation convenience.
- Creating test scenarios or layer assignments.

---

## Step 5: Review Design Enrichment

Display the enriched design summary and ask the user to approve, revise, or stop.

> ### Design Enrichment Review
>
> **Story:** {storyId} - {title}
>
> **Design Readiness:** {ready / needs clarification / blocked}
>
> **Behavior Model:** {roles, permissions, states, rules, negative paths}
>
> **UI Test Evidence:** {entry points, flows, visible elements, visible states, validation messages, dialogs, automation hooks}
>
> **API Contract Evidence:** {operations, contracts, status semantics, error handling, side effects}
>
> **Data And Integration Evidence:** {entities, persistence, audit, dependencies, events, async behavior}
>
> **Test Data And Environment:** {roles, fixtures, feature flags, environment dependencies, mocks/stubs}
>
> **Security/NFR/Observability/Release Risk:** {summary}
>
> **Test Design Implications:** {API contract files, UI evidence, extra assertions, test data needs}
>
> **Open Design Questions:** {items or None}
>
> **Action:**
> - **approve** - write the design-ready Story Contract
> - **revise** - update design fields and show this review again
> - **stop** - cancel without writing

Wait for user response:
- **approve** -> proceed to Step 6.
- **revise** -> apply the requested changes and repeat Step 5.
- **stop** -> end with "Design enrichment cancelled."

---

## Step 6: Write Design-Ready Contract

Before writing:
- Set `solutionDesign.designStatus` to `"approved"`.
- Set `lastCompletedStage` to `"enrichstorydesign"`.
- Keep `storyStatus` as `"confirmed"` unless the user explicitly changes story status.
- Preserve source metadata.
- Add or update `designUpdatedAt` using ISO-8601 local time when available.

Default output behavior:
- Update the source Story Contract JSON in place.
- If `--copy` is provided, write a separate `{storyId}-{titleSlug}.design.story.json`.
- If `--copy --out` is provided, write the copied design-ready Story Contract under `{dir}`.

In-place update rules:
- Do not rewrite `title`, `description`, or `acceptanceCriteria` unless the user explicitly approves a business story change.
- Preserve prior source metadata and generated fields.
- Only add or update `solutionDesign`, design timestamps, concise `technicalNotes`, assumptions, dependencies, constraints, and open questions.

For ADO mode:
- Add or update a clearly titled comment or attachment: `Design-Ready Story Contract JSON`.
- Add tag `design-ready`.

---

## Step 7: Summary

Report:

> ### Design-Ready Story Contract Written
>
> **Output:** `{outputPath or ADO Work Item ID}`
> **Story:** `{storyId} - {title}`
> **Design Status:** `approved`
>
> Next command:
>
> ```bash
> /bdd-gen {outputPath}
> ```
