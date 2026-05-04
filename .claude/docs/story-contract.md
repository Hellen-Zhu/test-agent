# Story Contract

This document defines the normalized requirement contract shared by upstream story-writing flows, solution design enrichment, and downstream engineering/test flows.

## Ownership

| Responsibility | Owner |
|----------------|-------|
| Load raw source from ADO, JSON, or free-form notes | `writeuserstories` |
| Normalize title, description, persona, module, ACs, and technical notes | `writeuserstories` |
| Split acceptance criteria into stable numbered items | `writeuserstories` |
| Show the parsed story to the user and handle revise/approve/stop | `writeuserstories` |
| Persist the approved normalized story | `writeuserstories` |
| Enrich the confirmed story with reviewed test-relevant design details | `enrichstorydesign` |
| Consume the approved story for BDD layering and feature generation | `bdd-gen` |

`bdd-gen` must not own requirement normalization, story approval, or solution design. It may check whether the handoff is confirmed and design-ready enough to run BDD generation.

## JSON File Output

When `writeuserstories` targets JSON or both outputs, it must persist the approved story as a local JSON file.

Default output directory:

```text
{WORKSPACE}/.claude/story-contracts/
```

Default file name:

```text
{storyId}-{titleSlug}.story.json
```

Rules:
- `titleSlug` is lowercase kebab-case.
- Keep only `a-z`, `0-9`, and `-`.
- Collapse repeated dashes.
- Limit the slug to 60 characters.
- If `storyId` is unavailable, use `local-{YYYYMMDD-HHMMSS}`.
- The local JSON file is the preferred handoff artifact for `/bdd-gen`.

## ADO Output

When `writeuserstories` targets ADO, it must preserve the same Story Contract content.

Required ADO output:
- Title, Description, and Acceptance Criteria in ADO-ready user story format.
- Tag: `story-contract-ready`.
- Full Story Contract JSON attached to the work item or added as a clearly titled comment: `Story Contract JSON`.

`bdd-gen` ADO mode may proceed only when it can read the confirmed Story Contract JSON from the work item. ADO-formatted text alone is not enough for downstream BDD generation.

## Required Fields

```json
{
  "storyId": "12345",
  "title": "Business-facing story title",
  "description": "As a ..., I want ..., so that ...",
  "persona": "Trader",
  "storyModule": "technical-module-or-service",
  "requirementAnalysis": {
    "requirementType": "capability | workflow | rule | visibility | technical | bug-like",
    "inScope": ["behavior explicitly included"],
    "outOfScope": ["related behavior explicitly excluded"],
    "assumptions": ["assumption that needs review"],
    "openQuestions": ["question that needs clarification"],
    "dependencies": ["upstream system, role, data, or approval"],
    "constraints": ["business, compliance, data, or timing constraint"],
    "nonFunctionalNeeds": ["performance, audit, security, reliability, observability"],
    "readiness": "ready | needs clarification | split recommended"
  },
  "acceptanceCriteria": [
    {
      "id": "AC-001",
      "given": "precondition or starting context",
      "when": "action or event occurs",
      "then": "expected observable outcome",
      "observableEvidence": [
        "business-visible evidence such as an enabled action, visible status, confirmation dialog, validation reason, audit record, or persisted state"
      ]
    }
  ],
  "technicalNotes": {
    "endpoint": "POST /api/...",
    "keyClasses": ["Controller", "Service"],
    "constraints": ["constraint or implementation note"],
    "testLayer": "optional hint only"
  },
  "solutionDesign": {
    "designStatus": "not_started | draft | approved",
    "designSources": [],
    "behaviorModel": {
      "actorsAndRoles": [],
      "permissions": [],
      "businessStates": [],
      "stateTransitions": [],
      "businessRules": [],
      "negativeAndEdgeCases": []
    },
    "apiDesign": {
      "operations": []
    },
    "uiDesign": {
      "entryPoints": [],
      "primaryUserFlows": [],
      "visibleElements": [],
      "visibleStates": [],
      "validationMessages": [],
      "dialogsAndPrompts": [],
      "automationHooks": []
    },
    "dataAndIntegrationDesign": {
      "entitiesAndState": [],
      "persistenceRules": [],
      "auditRecords": [],
      "eventsOrMessages": [],
      "asyncBehavior": [],
      "externalDependencies": []
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
      "accessibility": [],
      "compliance": [],
      "reliability": [],
      "compatibility": []
    },
    "observabilityDesign": {
      "logs": [],
      "metrics": [],
      "traces": [],
      "dashboards": [],
      "alerts": []
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
  },
  "storyStatus": "confirmed",
  "lastCompletedStage": "writeuserstories",
  "source": {
    "type": "ado | json | freeform",
    "value": "source identifier or path"
  },
  "generatedAt": "2026-05-02T14:51:00+08:00"
}
```

## Compatibility Rules

- `acceptanceCriteria` must use Given/When/Then objects.
- Legacy OREO fields such as `offlineStoryData.title` and `offlineStoryData.acceptanceCriteria` are raw input fields, not the downstream contract.
- Downstream flows may read legacy fields only to identify that the payload is not a Story Contract handoff.
- Downstream flows must not repair, split, rewrite, or re-normalize story content. They should stop with a clear message asking the user to rerun `/writeuserstories` when the handoff is not a confirmed Story Contract.
- `solutionDesign` is optional immediately after `/writeuserstories`, but is recommended before `/bdd-gen` for API, UI, workflow, permission, data, integration, or release-risk stories.
- `/enrichstorydesign` may add or update `solutionDesign`, `technicalNotes`, assumptions, dependencies, open design questions, and observable evidence. It must not change accepted business behavior without explicit user approval.
- `solutionDesign` should contain test-relevant design evidence, not a complete implementation specification. Store detailed API specs, UI designs, data models, or architecture documents by reference when possible.
- `technicalNotes` preserves raw or early technical hints from requirement intake. It is not authoritative for test design when approved `solutionDesign` exists.
- Test design and BDD generation must use approved `solutionDesign` before `technicalNotes`. If they conflict, approved `solutionDesign` wins.

## Writeuserstories Validation Rules

- `storyId`, `title`, `description`, and `acceptanceCriteria` are required.
- `acceptanceCriteria` must contain at least one testable item.
- Each AC must have stable `id`, `given`, `when`, and `then` fields.
- Store `given`, `when`, and `then` values without the leading `Given`, `When`, or `Then` keyword.
- `given`, `when`, and `then` should be business-facing and observable. Do not describe implementation internals unless the requirement is explicitly technical.
- `observableEvidence` is optional but recommended when the expected outcome is proven through a specific UI-visible, API-visible, data-visible, or audit-visible signal.
- UI-visible evidence is allowed when it is business meaningful, such as "Create Trade button is visible", "confirmation dialog is displayed", or "trade status is shown as Pending Approval".
- Do not put low-level mechanics in `observableEvidence`, such as CSS selectors, click paths, DOM IDs, request builders, or framework-specific implementation details.
- Confirmation may be represented by `storyStatus: "confirmed"`, `storyStatus: "approved"`, `lastCompletedStage: "writeuserstories"`, or an equivalent value written by the story flow.
- Technical notes are optional for UI-only stories, but should be preserved when present.
- `source` and `generatedAt` are optional metadata, but should be written when available.
- `requirementAnalysis` is required for Story Contracts created by current `writeuserstories`.
