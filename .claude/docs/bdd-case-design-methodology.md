# BDD Case Design Methodology

This methodology defines how `bdd-case-design-agent` turns an approved Phase 1 test point plan into stakeholder-readable Gherkin and reusable business step pattern contracts.

`bdd-feature-generation-standards.md` defines exact names, paths, tags, TC ID formats, output sections, and required checks. This file defines the design thinking.

## Core Principle

A feature file is a business behavior contract, not an automation adapter.

Ask:

```text
What business behavior must this scenario prove, and what reusable business step contract expresses it?
```

Do not change the approved Phase 1 validation intent, layer, tags, AC mapping, validation target, or observable evidence. Phase 2 may improve scenario economy and wording only inside the approved Phase 1 boundary.

## Design Loop

Use this loop after Phase 1 is approved:

```text
Approved test points
  -> Trace index
  -> Coverage group
  -> Scenario strategy
  -> Business step pattern contract
  -> Automation handoff intent
  -> check against standards for leakage, duplication, and trace loss
```

The loop starts from approved Phase 1 test points, not from raw story re-analysis.

## 1. Build Trace Context

Create an internal trace index from the approved Phase 1 report:
- `TP-###`
- layer
- tags
- AC mapping
- validation target
- observable evidence

This is indexing and completeness checking only. Do not re-derive, reinterpret, add, remove, or relayer any test point.

## 2. Design Coverage Groups

Phase 2 should not assume one test point equals one scenario. It should group compatible test points so a smaller scenario set covers more approved validation intent.

Use approved Phase 1 fields as grouping evidence. Do not require or invent a separate Phase 1 grouping hint field.

Keep test points together when they share:
- same layer
- compatible polarity
- compatible validation target
- compatible observable evidence
- compatible precondition and action shape inferred from the approved test point name and reasoning
- a cohesive business flow that can be expressed without hiding traceability

Split candidate groups when:
- the scenario would become too long or vague
- the assertions require materially different setup
- positive and negative behavior would mix
- execution would become unclear or brittle

Explain grouping decisions using the approved test point fields, not new analysis of raw ACs.

## 3. Shape Scenarios

One scenario should prove one cohesive behavior. A scenario may assert multiple outcomes only when those outcomes are part of the same approved behavior and evidence set.

Use `Scenario Outline` only for data or expectation variants of the same behavior. Do not mix positive and negative examples in one outline.

Use `Background:` only for stable shared business setup. Do not hide the behavior under test, dynamic data preparation, or assertions in `Background:`.

Preserve AC and TP traceability even when multiple test points are grouped into one scenario.

## 4. Design Business Language

Write Gherkin as a reviewable business specification:
- use domain language from the approved story, Phase 1 report, and approved solution design
- use consistent third-person role language such as `maker`, `checker`, `admin`, or `the user`
- keep feature steps at the business contract level

Existing `.feature` files may provide clean terminology and style evidence. They must not force implementation-shaped wording.

## 5. Design API Business Steps

API feature steps should be designed from the approved business outcome, not from HTTP mechanics or automation glue.

Ask:
- What business request is being made?
- What precondition or business data shape matters?
- What accepted, rejected, persisted, audit, event, or downstream business outcome proves the approved evidence?
- Can this be expressed as a stable business step pattern that is independent of the automation framework?

Exact allowed and forbidden API wording is defined in `bdd-feature-generation-standards.md`.

## 6. Design UI Business Steps

UI feature steps should be designed from user intent and user-visible evidence.

Ask:
- What business action is the actor trying to complete?
- What visible state, status, warning, dialog, option, or result proves the approved evidence?
- Does this scenario need a multi-actor lifecycle or handoff to prove the business value?
- Can the step remain stable if the UI control or selector changes?

Exact allowed and forbidden UI wording is defined in `bdd-feature-generation-standards.md`.

## 7. Design Business Step Pattern Reuse

Phase 2 owns reuse at the business semantic layer only.

Reuse design order:
1. Same business meaning inside the generated feature set -> use one identical pattern.
2. Same actor + verb + business object + outcome -> use the same pattern.
3. Same intent with variable product, role, status, date, currency, amount, or quantity -> define a parameterized business pattern.
4. Existing `.feature` files use a clean business term for the same concept -> align terminology if it does not leak implementation detail.
5. Otherwise define a new business step pattern contract.

The Automation Handoff Contract should explain:
- the step pattern
- business meaning
- reusable scope
- implementation need
- suggested downstream owner
- notes that help automation implementation without designing implementation internals

Do not check whether a concrete Cucumber step definition already exists. Do not select Java methods, snippets, page objects, API clients, fixtures, or helpers.

## 8. Standards Relationship

This methodology intentionally does not define Phase 2 pass/fail rules. Design Integrity Rules, Required Output Checks, and the output contract live in `bdd-feature-generation-standards.md`.

After applying the design loop, validate and repair the candidate result against those standards.

## 9. Output Relationship

Output structure and exact field rules are defined in `bdd-feature-generation-standards.md`.

The methodology output should let `/bdd-gen` write approved feature files and handoff files without reinterpreting Phase 2 decisions.
