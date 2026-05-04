# Test Layering Output Standards

Detailed output standards for `qa-test-analysis-agent`. This document defines the Phase 1 report contract, field rules, tag rules, grouping key rules, and required output checks.

`test-layering-methodology.md` defines how to think. This file defines what the output must contain.

## 1. Source Boundaries

| Purpose | Source of truth | Fallback | Forbidden |
|---------|-----------------|----------|-----------|
| Behavior scope | Confirmed Story Contract ACs and business fields | Approved assumptions | Inventing behavior not present in the Story Contract |
| Observable evidence | Story Contract `observableEvidence` | AC expected outcome when explicit evidence is absent | Ignoring evidence because it is awkward to automate |
| Test-relevant design | Approved `solutionDesign` | `technicalNotes` only as weak trace context | Letting technical notes override approved solution design |
| Layer selection | Validation target from methodology | None | Selecting layer because an endpoint, page, or module name exists |
| Domain risk | Story scope plus FX structured products judgement | Domain gap report | Adding unapproved product rules or pricing formulas |

## 2. Test Point Field Rules

Every test point must include:
- `TP-###`: sequential, neutral, and stable within the report.
- `Layer`: exactly one of `@api` or `@playwright`.
- `Scenario Name`: English, descriptive, and specific. This is a test-point name, not final Gherkin.
- `Tags`: exactly one polarity tag and exactly one selection tag.
- `AC Mapping`: one or more AC IDs from the Story Contract.
- `Validation Target`: what must be proven.
- `Observable Evidence`: how the outcome is observed.
- `Grouping Key`: neutral downstream grouping hint.
- `Reasoning`: concise layer/risk rationale.

Do not include feature names, feature tags, TC IDs, file paths, step wording, snippets, Java classes, endpoints, story modules, or implementation artifacts.

## 3. Tag Rules

Layer tag:
- `@api`
- `@playwright`

Polarity tag:
- `@positive`
- `@negative`

Selection tag:
- `@smoke`
- `@regression`

Each test point must include:
- exactly one layer tag
- exactly one polarity tag
- exactly one selection tag

## 4. Grouping Key Rules

`Grouping Key` identifies compatible test points for downstream BDD case design. It is not a feature name, tag, TC ID, or file path.

Format:

```text
{layer}:{entry-point-or-flow}:{assertion-theme}
```

Use the same grouping key only when test points share:
- same layer
- same business entry point or UI flow
- same precondition shape
- same assertion theme
- compatible polarity

Examples:
- `api:create-trade:validation-errors`
- `api:create-trade:persistence`
- `ui:create-trade:visible-affordance`
- `ui:cancel-trade:confirmation-dialog`
- `ui:maker-checker-lifecycle:visible-status`

## 5. Domain And Design Gaps

Report gaps when safe test design requires information not available in the confirmed Story Contract or approved solution design.

For FX TRF and derivatives stories, common gap areas include:
- target redemption and early termination behavior
- fixing, settlement, maturity, tenor, holiday calendar, and value date rules
- currency pair, direction, strike, notional, leverage, and product variant constraints
- payoff, precision, rounding, and FX rate source
- maker-checker permissions and self-approval prevention
- trade lifecycle state transitions
- persistence, audit, downstream events, confirmation, and reporting visibility

Do not fill these gaps by inventing product behavior.

## 6. Required Output Checks

Before returning:
- Every AC appears in at least one test point.
- Every observable evidence item is covered by at least one test point or explicitly justified in reasoning.
- Compound ACs are split when behaviors, validation targets, layers, or evidence differ.
- Every test point has exactly one layer, one polarity tag, and one selection tag.
- API/UI layer assignment follows the methodology's validation-target rules.
- No UI-visible behavior is incorrectly pushed to API.
- No backend-only validation is unnecessarily promoted to UI.
- Duplicate API/UI coverage is justified by distinct value.
- Grouping keys are neutral and compatible.
- Domain and design gaps are reported instead of guessed.
- No Gherkin, TC IDs, feature paths, step wording, snippets, or automation implementation details appear.

## 7. Output Contract

This section is the single detailed output contract for `qa-test-analysis-agent`. Other workflow files should reference this section instead of duplicating the template.

Return only this markdown structure:

```markdown
# Test Layering Analysis Report

**Story:** {story ID} - {title}

## Test Point List

| # | Test Point ID | Layer | Scenario Name | Tags | AC Mapping | Validation Target | Observable Evidence | Grouping Key | Reasoning |
|---|---------------|-------|---------------|------|------------|-------------------|---------------------|--------------|-----------|
| 1 | TP-001 | @api | Descriptive name | @positive @smoke | AC-001 | backend rule/persistence | trade is stored as Pending Approval | api:create-trade:persistence | Reasoning |
| 2 | TP-002 | @playwright | Descriptive name | @positive @regression | AC-002 | user-visible affordance | Create Trade button is visible and enabled | ui:create-trade:visible-affordance | Reasoning |

## Coverage Matrix

| Dimension | API | UI/E2E | Notes |
|-----------|-----|--------|-------|
| Happy path | Yes/No | Yes/No | |
| Error/negative | Yes/No | Yes/No | |
| Boundary values | Yes/No | Yes/No | |
| Business rules | Yes/No | Yes/No | |
| Cross-role flow | Yes/No | Yes/No | maker to checker |
| State lifecycle | Yes/No | Yes/No | create to approve to live |
| Data persistence | Yes/No | Yes/No | |

## Domain And Design Gaps

| Gap ID | Area | Gap | Impact | Suggested Owner |
|--------|------|-----|--------|-----------------|

If no gaps exist, write: `None`.
```
