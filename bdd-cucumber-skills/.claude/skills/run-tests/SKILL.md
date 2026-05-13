---
name: run-tests
description: Use when the user wants to execute the project's test suite and report results. Detects the test runner (jest/vitest/pytest/go test) automatically and surfaces only failures.
---

# run-tests

## Steps

1. **Detect runner** by checking project files:
   - `package.json` with `"test"` script → `npm test`
   - `pytest.ini` / `pyproject.toml` with `[tool.pytest]` → `pytest`
   - `go.mod` → `go test ./...`
   - `Cargo.toml` → `cargo test`
   - If none match, ask the user which command to run.

2. **Execute** the detected command via Bash. Capture exit code.

3. **Report** in this exact shape:
   - On pass: `✅ <N> tests passed in <runner>`
   - On fail: list only failing test names + the first 3 lines of each
     failure's stack trace. Do NOT dump the full output.

4. If the runner isn't installed, say so — don't try to install it.
