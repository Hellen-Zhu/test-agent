# Test Layering Methodology

A systematic 5-step method for assigning acceptance criteria to API (`@api`) or UI/E2E (`@playwright`) test layers.

---

## Step 1: Decompose ACs into Atomic Behaviors

A single acceptance criterion often bundles multiple independently verifiable behaviors. Decompose before layering.

**Example:**

AC: "Given a valid FX TRF trade payload, When a Maker POSTs to POST /trades/create with correct headers, Then the response status code is 200 and the trade is persisted in the database with correct field values"

Decomposes into:
- Behavior 1: API returns 200 on valid payload
- Behavior 2: Trade record exists in DB with correct field values
- Behavior 3: (implicit negative) Invalid payload returns appropriate error code

**Rules:**
- If an AC contains "and" joining two distinct assertions → split
- If an AC implies a negative/boundary case not stated → extract it
- Each atomic behavior gets its own layering decision

---

## Step 2: Model Entity State Machine

Map the entity lifecycle as a state machine. Identify which actor triggers each state transition.

**Example (Trade lifecycle):**

```
[Draft] --Maker POST--> [Pending Approval] --Checker approve--> [Live]
                                           --Checker reject---> [Rejected]
[Live]  --Maker amend--> [Pending Approval]
```

**Layering signals from the state machine:**

| Pattern | Layer | Reasoning |
|---------|-------|-----------|
| Single actor, single transition | API | One request, one response — no UI orchestration needed |
| Single actor, chained transitions | API (multi-step) | Sequential API calls by same actor |
| Cross-actor transition (role handoff) | UI/E2E | Requires separate user sessions (e.g. Maker → Checker) |
| Full lifecycle traversal (3+ states) | UI/E2E | End-to-end business flow verification |
| State persistence after transition | API | DB assertion after API call |

---

## Step 3: Separate Business Rules from Workflow

Every atomic behavior falls into one of two categories. This distinction drives layer assignment.

### Business Rules (data correctness)

Things the system enforces regardless of how you interact with it:

- Input validation (required fields, format, range)
- Calculation logic (pricing, notional amount)
- Constraint enforcement (duplicate detection, permission checks)
- Data transformation (field mapping, derived values)
- Error codes and messages for invalid inputs

**→ Almost always API layer.** These are properties of the backend, testable via HTTP request/response.

### Workflow (process correctness)

Things that emerge from multi-step, multi-actor interaction:

- Role handoff sequences (Maker creates → Checker approves)
- Status progression through a business process
- UI state consistency (blotter shows correct status after action)
- End-to-end orchestration (create → verify → approve → verify final state)

**→ Almost always UI/E2E layer.** These require browser-level orchestration or cross-session flows.

### Grey area: API-verifiable workflow

Some workflow steps CAN be verified via chained API calls (same actor, no UI rendering assertions). In these cases, prefer API layer for speed. Only push to UI/E2E if:
- The AC explicitly mentions UI elements (blotter, portal, page)
- Multiple user sessions are required
- The assertion is about what the user SEES, not what the system STORES

---

## Step 4: Apply Decision Tree

For each atomic behavior from Step 1, walk this decision tree:

```
Is this behavior fully verifiable through a single API request-response?
│
├── YES
│   ├── Core assertion is about data/state correctness?
│   │   ├── YES → API (@api)
│   │   └── NO (about UI rendering/display) → UI/E2E (@playwright)
│   │
│   └── (proceed)
│
└── NO
    ├── Does it require multiple actors (different user sessions)?
    │   ├── YES → UI/E2E (@playwright)
    │   └── NO
    │       ├── Can it be verified via chained API calls (same actor)?
    │       │   ├── YES → API (@api) with multi-step scenario
    │       │   └── NO (requires browser interaction) → UI/E2E (@playwright)
    │       └── (proceed)
    └── (proceed)
```

**Decision tree override rules:**
- AC explicitly says "via the trading portal" / "through the UI" / "in the blotter" → UI/E2E regardless of decision tree
- AC explicitly says "via API" / "POST/GET/PUT/DELETE" → API regardless of decision tree
- When in doubt, prefer API (faster, more stable, lower maintenance)

---

## Step 5: Test Pyramid Balance Check

After all atomic behaviors are assigned, validate the overall distribution:

### Ratio check

| Metric | Healthy Range | Action if Out of Range |
|--------|--------------|----------------------|
| API test points | 40–70% of total | If <40%: review whether some UI scenarios can be pushed down to API |
| UI/E2E test points | 30–60% of total | If >60%: likely over-testing through UI — check for API-verifiable behaviors |
| Uncovered ACs | 0 | Any uncovered AC is a gap — assign it |
| Dual-covered behaviors | Justified only | If same behavior tested at both layers, document why (e.g. API tests data correctness, UI tests display correctness) |

### Common mistakes to catch

1. **UI-heavy bias**: testing data validation through the UI when a 200ms API call would suffice
2. **Missing negative cases**: only testing happy paths → add `@negative` scenarios for error codes, validation failures
3. **Redundant cross-layer coverage**: exact same assertion at both API and UI → keep only the faster one unless the UI rendering assertion adds distinct value
4. **Lifecycle gaps**: state machine has transitions not covered by any test point → add scenarios for untested transitions

---

## Quick Reference: Layer Decision Signals

| Signal in AC | → Layer | Confidence |
|-------------|---------|------------|
| "POST / GET / PUT / DELETE" | API | High |
| "response status code" | API | High |
| "persisted in database" | API | High |
| "field values match" / "valid structure" | API | High |
| "error code" / "validation error" | API | High |
| "via the trading portal" / "through the UI" | UI/E2E | High |
| "in the blotter" / "shows status" | UI/E2E | High |
| "Maker creates ... Checker approves" | UI/E2E | High |
| "lifecycle" / "progresses through" | UI/E2E | Medium-High |
| "logged in" / "user session" | UI/E2E | Medium |
| "approval workflow" | UI/E2E | Medium |
| No explicit channel mentioned | API (default) | Medium |
