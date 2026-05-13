# Layering Decision Tree

For each acceptance criterion, decide which layer owns the assertion. Default to the LOWEST layer that can observe the behaviour — this gives faster, more stable tests.

## Two-question decision tree

```
For each AC sentence, ask:

Q1. Can this behaviour be observed without a browser?
    (i.e. by calling the HTTP API directly and inspecting status/body/headers)

    ├─ YES → API layer (features/api/)
    │
    └─ NO  → Q2

Q2. Is the behaviour purely client-side?
    (i.e. happens in DOM/JS without any server round trip, or is only
     verifiable by what the user sees on the rendered page)

    ├─ YES → UI layer (features/ui/)
    │
    └─ NO  → Split the AC. Route the server-side part to API and the
             browser-side consequence to UI as separate scenarios.
```

## Cheat sheet

| Pattern in AC | Layer | Why |
|--------------|-------|-----|
| "POST /x returns 200 with ..." | api | Status code and body are HTTP-observable |
| "After N attempts the account is locked" | api | Server-side state machine |
| "JWT contains the user's id claim" | api | Response body inspection |
| "Response time is under 500 ms" | api | HTTP-level timing |
| "Schema of the response matches ..." | api | JSON shape on the wire |
| "I am redirected to /dashboard" | ui | Browser URL state |
| "The button is disabled while request is in flight" | ui | DOM state during async op |
| "Inline error 'Invalid email' appears" | ui | Rendered DOM text |
| "Email field validates shape on blur" | ui | Client-side form behaviour |
| "Password field has type='password' by default" | ui | DOM attribute |
| "Focus returns to the password field after error" | ui | A11y / focus behaviour |
| "No network request is sent when fields are empty" | ui | Network observation from browser (page.route) |
| "Returns 401 AND shows 'Invalid' inline error" | **split** | API scenario for 401; UI scenario for inline error |

## When in doubt: ask "what is the source of truth?"

- If the server enforces the rule (auth, lockout, validation that gates persistence) → API owns the assertion. UI can have a thin "looks right" check.
- If the browser enforces the rule (mask toggle, focus management, visual disabled state) → UI owns the assertion. API isn't involved.

## Anti-patterns

### Anti-pattern: testing the same rule at both layers

If you find yourself writing both:

```gherkin
# features/api/auth/login.feature
Scenario: Wrong password returns 401
  ...

# features/ui/auth/login-form.feature
Scenario: Wrong password returns 401
  When I submit the login form with a wrong password
  Then the POST returns 401   # ← redundant: API layer already covers this
```

The UI scenario should assert the BROWSER consequence (inline error, focus, no redirect), not the HTTP status code.

### Anti-pattern: simulating server behaviour at the UI layer

If you find yourself writing `page.route()` to mock an API response so the UI assertion makes sense, you are usually testing UI behaviour given a server state. That's fine — but make sure the corresponding REAL server behaviour is covered at the API layer too, otherwise the mock can drift from reality.

### Anti-pattern: testing UI rendering at the API layer

Never assert against HTML strings in API responses. If the API returns HTML and you need to verify rendered content, that's a UI concern.

## Edge cases

- **Authentication tokens**: API layer issues and validates JWTs. UI layer tests "after login I see the dashboard" — never decodes the JWT itself.
- **CSRF / cookies**: Both layers care. API tests assert the cookie is set with correct flags; UI tests assert behaviour given the cookie exists.
- **WebSocket / SSE**: If the rule is "client receives an event" → UI. If the rule is "server publishes an event to subscribers" → API (or a dedicated integration layer).
- **Performance**: API timing is usually deterministic and belongs in api. UI render timing is flaky and should usually be a SHOULD assertion (warning, not hard fail) — or moved to a perf suite.

## Decision template

When uncertain, fill this in:

```
AC: "<verbatim text>"

Observable at API layer? <yes/no>  ← can curl + jq verify?
Observable at UI layer?  <yes/no>  ← does a real user notice?

If both: which is the SOURCE OF TRUTH (server vs client)?
Layer: <api / ui / split>
Rationale: <one sentence>
```
