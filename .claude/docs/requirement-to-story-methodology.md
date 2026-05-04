# Requirement To Story Methodology

This methodology defines how `writeuserstories` converts raw business requirements into a high-quality User Story and Given/When/Then acceptance criteria.

## Core Principle

Real requirement analysis is iterative. Do not mechanically run a waterfall checklist. Keep cycling until the story, rules, observable evidence, and acceptance criteria agree with each other.

The agent must not freely invent product behavior. It may infer structure only from evidence in the source. Every uncertain point must become an assumption or open question.

## Analysis Loop

Use this loop until the story is coherent and testable:

```text
Business intent
  -> Behavior model
  -> Observable evidence
  -> Given/When/Then ACs
  -> Challenge and refine
  -> repeat if gaps remain
```

The loop can start from any point. For example, if the source says "Create button should be visible", start from observable evidence and work backward to the business capability and permission rule.

## 1. Business Intent

Clarify what the business wants before writing ACs.

| Element | Question |
|---------|----------|
| Persona | Who receives value or performs the action? |
| Capability | What business capability is needed? |
| Business value | Why does it matter? |
| Trigger | What starts the behavior? |
| Outcome | What business state or visible result proves success? |

Story format:

```text
As a {persona},
I want {business capability},
so that {business value}.
```

Rules:
- Use business language, not implementation language.
- If persona is missing, infer only from evidence. Otherwise use `null` and add an open question.
- The title should be capability-focused: `{Business Object} {Business Action}`.

## 2. Requirement Classification

Classify the raw input so the right analysis path is used:

| Input Type | Examples | Action |
|------------|----------|--------|
| Business capability | "Allow makers to create FX TRF trades" | Convert to a user outcome story |
| Workflow change | "Maker submits, checker approves" | Model actors, states, and handoffs |
| Rule or validation | "Reject invalid maturity date" | Extract business rule and examples |
| Reporting/visibility | "Show status in blotter" | Identify user-visible outcome |
| UI affordance or prompt | "Show Create button", "Display confirmation dialog" | Treat as business-visible evidence when it controls or confirms user action |
| Technical note | endpoint, class, service, payload | Preserve in `technicalNotes`; do not make it the business story |
| Bug-like request | "Trade status is wrong after approval" | Convert to desired behavior and regression ACs |

`technicalNotes` is raw intake evidence. Later solution design may promote, revise, or discard these hints; downstream test design must prefer approved `solutionDesign` over `technicalNotes`.

Output:
- `requirementType`
- raw facts
- technical notes
- assumptions
- open questions

## 3. Scope Boundary

Separate what this story owns from related work.

| Category | Meaning |
|----------|---------|
| In scope | Behavior explicitly requested or required for the stated outcome |
| Out of scope | Related behavior that should not be included in this story |
| Dependencies | Upstream systems, roles, data, feature flags, approvals |
| Constraints | Compliance, permission, data, timing, product constraints |
| Non-functional needs | Performance, audit, security, reliability, observability |

Rules:
- Do not expand one requirement into multiple capabilities unless the source clearly asks for them.
- If a requirement contains multiple independent outcomes, propose a story split.
- Keep technical implementation details out of ACs unless the story is explicitly technical.

## 4. Behavior Model

Model the behavior before finalizing ACs.

| Item | Example |
|------|---------|
| Entity | trade, product, composer config |
| Starting state | draft, pending approval, active |
| Action | create, submit, approve, cancel, amend |
| Resulting state | pending approval, live, rejected |
| Actor handoff | maker -> checker |
| Rule | only makers can create, checker cannot approve own trade |
| Exception | missing required field, invalid state transition |
| Observable evidence | status, button, dialog, validation reason, response, audit record |

Use this model to avoid vague assertions like "works successfully".

## 5. Observable Evidence

Observable evidence is how the behavior will be proven. It is allowed to be specific.

Valid evidence:
- UI-visible: action button visible/enabled/disabled, confirmation dialog, warning banner, status label, validation message, table row, menu item
- API-visible: response field, error reason, returned business state
- Data-visible: persisted entity state, stored field value, generated reference
- Audit-visible: audit event, timestamp, actor, state transition record
- Notification-visible: email, alert, task, queue message, dashboard notification

Invalid low-level mechanics:
- CSS selectors, DOM IDs, XPath
- click/type/navigate instructions
- request builder steps, raw headers, framework glue
- Java class names or method names as business evidence

Rule of thumb:
- "Create Trade button is visible and enabled" is valid evidence.
- "Click `#create-trade-button`" is automation detail and should not be in ACs.

## 6. Rule And Example Mapping

Use examples to challenge the behavior model:

| Artifact | Meaning |
|----------|---------|
| Rules | Business rules the system must enforce |
| Examples | Concrete positive, negative, and boundary examples |
| Questions | Unknowns that block precise ACs |
| ACs | Final Given/When/Then acceptance criteria |

Rules:
- Each important rule needs at least one example or one open question.
- Include negative and boundary examples only when supported by the source or clearly implied by a rule.
- Do not invent exact values, error messages, or limits unless provided.

## 7. Write Given/When/Then ACs

Each AC describes one independently verifiable business behavior.

Pattern:

```text
Given {business precondition}
When {business action or event}
Then {observable business outcome}
Evidence: {optional specific observable signal}
```

Quality rules:
- `Given` sets context, not test setup mechanics.
- `When` contains one business action or event.
- `Then` contains the expected business outcome.
- `observableEvidence` contains the concrete proof signal when needed.
- UI-visible evidence is valid when it represents business availability, permission, confirmation, warning, status, or feedback.
- Avoid UI operations such as click, type, navigate, selectors, or DOM IDs.
- Avoid API mechanics such as headers, endpoint paths, request builders, and status-code-only assertions unless the requirement is explicitly API-specific.
- Split ACs when there are multiple actions, multiple outcomes, or materially different rules.

Good examples:

```text
Given a maker has permission to create trades
When the maker opens the trade blotter
Then the maker can start creating a new trade
Evidence: the Create Trade button is visible and enabled
```

```text
Given a maker has selected a live trade for cancellation
When the maker requests cancellation
Then the maker is asked to confirm the cancellation before it is submitted
Evidence: a cancellation confirmation dialog is displayed with the selected trade identifier
```

```text
Given a maker has a trade request missing a required maturity date
When the maker submits the trade for creation
Then the trade is rejected with a validation reason
Evidence: the maturity date validation reason is visible to the maker
```

Bad examples:

```text
Given user is on the page
When user clicks Save
Then success message appears
```

```text
Given start building a new request
When post to path '/api/v1/trades'
Then response status code is 200
```

Rewrite with business meaning:

```text
Given a maker has completed a valid trade request
When the maker submits the request
Then the maker receives confirmation that the trade was submitted
Evidence: a submission confirmation message is displayed
```

## 8. Challenge And Refine

After drafting the story and ACs, challenge them like a senior tester:

| Challenge | Question |
|-----------|----------|
| Missing rule | What rule would make this behavior fail? |
| Missing state | What starting or resulting state is assumed? |
| Missing role | Does another persona see or do something different? |
| Missing evidence | How would a tester know the outcome happened? |
| Over-specific AC | Is this describing implementation instead of behavior? |
| Under-specific AC | Could two people implement or test this differently? |
| Split risk | Is this really multiple stories? |

If a challenge exposes a gap, update the story, add an AC, add evidence, add an assumption, or create an open question.

## 9. Readiness Check

Before review, run INVEST and testability checks:

| Check | Pass Criteria |
|-------|---------------|
| Independent | Story can be delivered without unrelated capabilities |
| Negotiable | Describes outcome, not over-specified implementation |
| Valuable | Value is clear to a user, business, or system owner |
| Estimable | Scope and dependencies are understandable |
| Small | Not a bundle of unrelated stories |
| Testable | ACs have observable evidence or clear business outcomes |
| Traceable | ACs map back to source facts or assumptions |

Readiness result:
- `ready`: ACs are clear and testable.
- `needs clarification`: open questions block confident implementation or testing.
- `split recommended`: source contains multiple independent outcomes.

## 10. Review Output

The draft presented to the user must include:
- Story title
- Story description
- Persona
- In scope / out of scope
- Dependencies, constraints, non-functional needs
- Assumptions
- Open questions
- Given/When/Then ACs
- Observable evidence
- Technical notes
- Readiness result

Only write JSON or ADO output after the user approves the draft.
