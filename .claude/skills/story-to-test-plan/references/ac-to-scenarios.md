# Acceptance Criteria → Scenarios

Patterns for translating AC sentences into Gherkin scenarios. Use these AFTER `layering.md` has assigned the layer.

## Coverage formula per AC

For each AC sentence, derive scenarios in this order:

1. **Happy path** — the success case stated by the AC.
2. **Named negatives** — every failure mode the AC mentions explicitly ("invalid credentials", "malformed payload", "locked account").
3. **Boundary cases** — numerical thresholds, edge timings, empty / max-length inputs.
4. **Implied negatives** — what should NOT happen (no enumeration leakage, no extra side effects).
5. **Resilience** — repeat / concurrent / timeout / retry behaviour, if AC implies state machine.

Stop when the AC's claim is fully bounded — don't pad with speculative scenarios.

## Pattern A: simple HTTP rule

**AC**: "POST /api/v1/auth/login returns 200 with a signed JWT for valid credentials, and 401 with an error code for invalid credentials."

**Scenarios**:
```gherkin
Scenario: Successful login returns a signed JWT
  ...

Scenario: Wrong password returns 401 with stable error code
  ...

Scenario: Unknown email returns 401 (no user enumeration)
  ...                # ← implied negative: response must NOT differ

Scenario: Malformed payload returns 400
  ...                # ← boundary: missing required field
```

Four scenarios from one AC sentence. The two 401 cases are split because they test DIFFERENT properties (wrong password vs unknown user) — and an attacker can use a difference between them to enumerate users.

## Pattern B: state-machine rule

**AC**: "After 5 consecutive failed login attempts within 10 minutes, the account is locked and the API returns 423 Locked until an admin unlocks it."

**Scenarios**:
```gherkin
Scenario: 4 failures within 10 minutes do NOT lock the account
  ...                # ← boundary: just below threshold

Scenario: 5 failures within 10 minutes lock the account
  ...                # ← state transition

Scenario: Locked account returns 423 even with correct password
  ...                # ← state persistence

Scenario: Failures more than 10 minutes apart do not accumulate
  ...                # ← window semantics

Scenario: Admin unlock restores access
  ...                # ← state exit
```

Five scenarios. State-machine ACs almost always need: just-below threshold, threshold, post-state, time-window edge, recovery.

## Pattern C: UI form validation

**AC**: "The email field validates basic email shape on blur; the password field is masked by default with a show/hide toggle."

**Scenarios**:
```gherkin
Scenario: Email field validates shape on blur
  ...

Scenario: Password field is masked by default
  ...

Scenario: Show/hide toggle reveals and re-masks the password
  ...                # ← interaction state cycle

Scenario: Submitting with empty fields highlights both           # ← implied negative
  ...
```

Notice: each behaviour is one scenario. Combining "validates AND is masked" into one scenario would violate S3 (one outcome per scenario).

## Pattern D: timing assertion

**AC**: "Given valid credentials, when I submit the login form, then I am redirected to /dashboard within 2 seconds."

This AC straddles layers. Split:

**API layer** (`features/api/auth/login.feature`):
```gherkin
Scenario: Login response returns within 500 ms p95
  ...                # ← server-side latency budget (tighter than user-facing 2s)
```

**UI layer** (`features/ui/auth/redirect-after-login.feature`):
```gherkin
Scenario: Successful login redirects to /dashboard within 2 seconds
  ...                # ← user-observable end-to-end time
```

Two scenarios, two files. The API scenario is more stable; the UI scenario covers the integrated experience.

## Pattern E: "does NOT" assertions (implied negatives)

Many ACs imply things that should NOT happen but don't state them. Surface these:

- "Returns 401 for invalid credentials" → ALSO: response does not leak which field was wrong, response time does not differ from valid-email-wrong-password case (timing attack), response has no Set-Cookie.
- "Disables button during request" → ALSO: no duplicate submit network call fires if user clicks twice quickly.
- "Shows inline error" → ALSO: does not navigate away, focus does not disappear, no console error logged.

These are often the most security-relevant scenarios. Always ask: "what should be false?"

## Granularity check

After drafting scenarios, run this check:

| Smell | Fix |
|-------|-----|
| `Then` block has more than 2 `And`s | Split into smaller scenarios |
| Scenario title starts with a verb ("Submit ...") | Rename to describe outcome ("Submission with wrong password is rejected") |
| Two scenarios differ only by one data value | Use `Scenario Outline` with `Examples:` |
| One scenario has 8+ steps total | It's a story, not a scenario; decompose |
| Scenario name contains "and" | Probably two scenarios fused |

## Output: per-AC scenario list

For each AC, write down the planned scenarios BEFORE drafting Gherkin:

```
AC3 (api): POST /api/v1/auth/login returns 200 / 401 / 400
  └─ features/api/auth/login.feature
     • Successful login returns a signed JWT
     • Wrong password returns 401 with stable error code
     • Unknown email returns 401 (no user enumeration)
     • Malformed payload returns 400

AC4 (api): After 5 failures, account locks (423)
  └─ features/api/auth/lockout.feature
     • 4 failures do not lock
     • 5 failures lock (returns 423)
     • Locked account returns 423 even with correct password
     • Window expires after 10 minutes
     • Admin unlock restores access
```

This plan goes into the output report from SKILL.md's procedure step 8.
