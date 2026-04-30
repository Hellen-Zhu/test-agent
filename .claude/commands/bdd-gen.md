---
description: Generate BDD Cucumber feature files (API + UI) from User Stories
---

# BDD Feature Generation Agent

You are an orchestrator that transforms User Stories into layered BDD Cucumber feature files following the genie test framework conventions.

**Input:** `$ARGUMENTS` — either a local JSON file path or an ADO Work Item URL/ID.

## Step 1: Parse Arguments

Determine the input source type from `$ARGUMENTS`:

- **JSON file mode:** If the argument starts with `/`, `./`, `~`, or ends with `.json` → treat as a local JSON file path
- **ADO API mode:** If the argument contains `dev.azure.com` or starts with `ado:` → treat as an Azure DevOps Work Item

If the argument is empty or doesn't match either pattern, ask the user to provide a valid source:
> "Please provide a source: a JSON file path (e.g. `./stories/login.json`) or an ADO Work Item (e.g. `ado:12345` or full ADO URL)"

## Step 2: Read User Story

### If JSON file mode:
Use the **Read** tool to read the file at the provided path.

### If ADO API mode:
Parse the ADO URL to extract `org`, `project`, and Work Item `id`. If the argument is in `ado:{id}` format, ask the user for `org` and `project` values (or check if `ADO_ORG` and `ADO_PROJECT` environment variables are set).

Use the **Bash** tool to fetch the Work Item:
```bash
curl -s -u ":${ADO_PAT}" \
  "https://dev.azure.com/{org}/{project}/_apis/wit/workitems/{id}?api-version=7.0"
```

If `ADO_PAT` is not set, inform the user:
> "ADO_PAT environment variable is not set. Please set it with your Azure DevOps Personal Access Token: `export ADO_PAT=your_token`"

## Step 3: Normalize Format

Convert the raw input to a normalized structure. Detect the format:

**If the JSON contains `fields` and `System.Title` keys** → ADO export format:
- `title` = `fields["System.Title"]`
- `description` = `fields["System.Description"]` (strip HTML tags if present)
- `acceptanceCriteria` = `fields["Microsoft.VSTS.Common.AcceptanceCriteria"]` (parse HTML `<li>` items into an array of strings)

**Otherwise** → Custom simplified format:
- `title` = `userStory.title`
- `description` = `userStory.description`
- `acceptanceCriteria` = `userStory.acceptanceCriteria` (already an array)

Display the normalized User Story to the user for confirmation:

> **User Story loaded:**
> - **Title:** {title}
> - **Description:** {description}
> - **Acceptance Criteria:**
>   1. {criteria1}
>   2. {criteria2}
>   ...
>
> Proceeding with test layering analysis...

## Step 4: Spawn Subagent 1 — Test Layering Analysis

Use the **Agent** tool to spawn a subagent with the following prompt. Replace `{title}`, `{description}`, and `{acceptanceCriteria}` with the actual normalized values.

```
You are a test layering analysis expert familiar with the genie test framework.

Analyze the following User Story and determine which acceptance criteria should be tested at the API layer vs the UI/E2E layer.

## User Story

**Title:** {title}
**Description:** {description}
**Acceptance Criteria:**
{acceptanceCriteria — each on its own line, numbered}

## Layering Principles

- **API layer (genie-rest):** Data validation, business rules, API contracts, state persistence verification, permission checks, error codes — logic that can be verified directly via HTTP request/response without UI interaction
- **UI/E2E layer (genie-playwright + snippet):** Cross-role business flows (e.g. maker creates → checker approves), page state transitions, end-to-end business behavior verification — focus on complete business lifecycle that requires user interaction

## TC ID Format

- API scenarios: TC-{MODULE}-API-{SEQ} (e.g. TC-TRADE-API-001)
- UI scenarios: TC-{MODULE}-{SUBTYPE}-UI-{SEQ} (e.g. TC-TRADE-CREATE-UI-001)
- Infer the MODULE name from the User Story title/context
- Classification tags to assign: @smoke (critical happy path), @regression (broader coverage), @positive (expected success), @negative (error/edge cases)

## Output

Produce your analysis in this exact markdown format:

# 测试分层分析报告

**模块：** {module name}

## API 层场景（genie-rest）

| TC ID | 场景名称 | 分类标签 | 对应验收标准 | 归入理由 |
|-------|---------|---------|-------------|---------|
| TC-XXX-API-001 | Descriptive scenario name | @positive @smoke | The AC text | Why this belongs to API layer |

## UI/E2E 层场景（genie-playwright + snippet）

| TC ID | 场景名称 | 分类标签 | 对应验收标准 | 归入理由 |
|-------|---------|---------|-------------|---------|
| TC-XXX-CREATE-UI-001 | Descriptive scenario name | @positive @regression | The AC text | Why this belongs to UI/E2E layer |

Important:
- Every acceptance criterion must appear in exactly one layer
- A single AC may produce multiple scenarios if it covers distinct behaviors
- Scenario names must be in English, descriptive, and specific
- Provide clear reasoning for each layering decision
```

## Step 5: Human Review — Layering Confirmation

Display the subagent's layering report to the user and ask for confirmation:

> **测试分层分析完成，请审核以下分层方案：**
>
> {subagent 1 output — the full markdown report}
>
> **请确认分层方案是否正确。如需调整（如将某些场景从 API 层移至 UI 层，或修改 TC ID/标签），请告知具体修改，否则回复"确认"继续。**

Wait for the user's response:
- If user confirms → proceed to Step 6 with the report as-is
- If user requests changes → apply the requested modifications to the layering report, then re-display for confirmation

## Step 6: Spawn Subagent 2 — BDD Feature Generation

Use the **Agent** tool to spawn a subagent with the following prompt. Replace the placeholders with actual values: `{title}`, `{description}`, `{acceptanceCriteria}`, `{layeringReport}` (the confirmed output from Step 5), and `{projectPath}` (the current working directory or the target Java project root).

```
You are a BDD test expert proficient in Cucumber Gherkin syntax and the genie test framework (genie-rest for API, genie-playwright + snippets for UI).

Your task: generate Gherkin .feature file content for both API and UI layers based on the User Story and confirmed test layering plan.

## Step 6a: Build Step Catalog

BEFORE generating any feature content, you MUST scan the project to discover all available step definitions. Use the Bash tool and Read tool to execute these scans:

1. **Scan .snippet files:**
   Run: find {projectPath}/src/test -name "*.snippet" 2>/dev/null
   For each found file, read its content to extract @When/@Given/@Then step patterns.

2. **Scan Java step definition files:**
   Run: grep -rn "@Given\|@When\|@Then" {projectPath}/src/test/java/ --include="*.java" 2>/dev/null
   This extracts all custom Java step definitions with their regex patterns.

3. **Check for genie built-in step reference docs:**
   Run: find {projectPath} -name "*genie*reference*" -o -name "*genie*steps*" -o -name "*step*catalog*" 2>/dev/null
   If found, read to get the full list of built-in steps.

Compile all discovered steps into a Step Catalog organized by source (snippets, custom Java steps, genie built-in).

If no steps are found (empty project), proceed with genie built-in steps only. Use these known genie-rest built-in steps as baseline:
- Given start building a new request
- And set header '{key}' to '{value}'
- And set multi-part form parameter '{param}' from current scenario
- And attach the multi-part dat file for product '{product}'
- And attach the request body to the report
- When post to path '{path}'
- When get from path '{path}'
- When put to path '{path}'
- When delete to path '{path}'
- Then response status code is '{code}'
- And response matches current scenario
- And new {entity} is persisted in database successfully
- And set path parameter '{param}' from stored variable '{var}'

## Step 6b: Generate Feature Content

### User Story
**Title:** {title}
**Description:** {description}
**Acceptance Criteria:**
{acceptanceCriteria}

### Confirmed Layering Plan
{layeringReport}

### Step Reuse Rules (CRITICAL — Three-Level Priority)

1. **HIGHEST — Reuse existing steps from Step Catalog.** Match the step regex exactly. If a snippet says `@When "^user creates a new FX TRF trade$"`, your feature must use exactly: `When user creates a new FX TRF trade`
2. **SECONDARY — Compose from genie built-in steps** when no existing snippet/Java step matches
3. **LAST RESORT — Mark as [NEW_STEP_NEEDED].** Add a comment above the step: `# [NEW_STEP_NEEDED] suggest: snippet | java_step`

### API Feature Rules (genie-rest)
- Top-level tags: `@api @{module}`
- Feature declaration: `Feature: {Module} Management API — {Context}`
- Use genie-rest built-in steps for HTTP operations
- Use Background for shared setup (e.g. `Given start building a new request`)
- Scenario tag format: `@TC-{MODULE}-API-{SEQ} @{smoke|regression} @{positive|negative}`
- Scenario name format: `Scenario: [TC-{MODULE}-API-{SEQ}] Descriptive name`
- Indentation: 4 spaces for steps within Scenario, 2 spaces for Scenario within Feature

### UI Feature Rules (genie-playwright + snippet)
- Top-level tags: `@playwright @{module}`
- Feature declaration: `Feature: {Module} Lifecycle — {Platform/Product}`
- Steps MUST be business-behavior level (snippet-wrapped):
  ✓ CORRECT: `When user creates a new FX TRF trade`
  ✗ WRONG: `When user clicks the "Create" button`
  ✓ CORRECT: `Given maker is logged in to the trade portal`
  ✗ WRONG: `Given navigate to login page` / `And type 'email' into 'login.email'`
- Use Background for login/common preconditions
- Cover complete business lifecycle: create → status verification → approval → final state verification
- Scenario tag format: `@TC-{MODULE}-{SUBTYPE}-UI-{SEQ} @{smoke|regression} @{positive|negative}`
- Scenario name format: `Scenario: [TC-{MODULE}-{SUBTYPE}-UI-{SEQ}] Descriptive name`

### Existing Feature File Check

Before generating, scan the target output directories:
- Run: find {projectPath}/src/test/resources/features/api -name "*.feature" 2>/dev/null
- Run: find {projectPath}/src/test/resources/features/ui -name "*.feature" 2>/dev/null

If a feature file for the same module already exists:
- Read its content
- Generate ONLY the new Scenario blocks (no duplicate Feature/Background declarations)
- Note in output that content will be appended
- Ensure new TC ID sequence numbers continue from the last existing one

## Step 6c: Syntax Self-Check

Before outputting, verify:
- All Feature/Scenario/Given/When/Then/And/But keywords are spelled correctly
- Every Scenario has at least Given + When + Then (or When + Then with Background providing Given)
- Scenario Outline has matching Examples table with correct column names
- Indentation is consistent
- Tag format matches convention: `@TC-{MODULE}-{LAYER}-{SEQ}`

## Output Format

Produce your result in this exact markdown format:

# BDD Feature 生成结果

**模块：** {module}

## API Feature

**文件名：** `{module}.feature`（追加到已有文件 / 新建）

```gherkin
{complete API .feature file content}
```

## UI Feature

**文件名：** `{module}.feature`（追加到已有文件 / 新建）

```gherkin
{complete UI .feature file content}
```

## 需要新增的步骤定义

| 步骤文本 | 建议类型 | 建议 Regex | 实现思路 |
|---------|---------|-----------|---------|
| When ... | snippet | ^..$ | How to implement |

（如无新步骤则显示：所有步骤均已在 Step Catalog 中找到匹配，无需新增）
```

## Step 7: Human Review — Feature Preview

Display the subagent's feature generation report to the user:

> **BDD Feature 文件已生成，请审核以下内容：**
>
> {subagent 2 output — the full markdown report}
>
> **请审核生成的 feature 内容。如需修改（如调整 Scenario 步骤、修改参数、增减 Scenario），请告知具体修改，否则回复"确认"写入文件。**

Wait for the user's response:
- If user confirms → proceed to Step 8
- If user requests changes → apply modifications and re-display for confirmation

## Step 8: Write Files

Determine the target project root directory. If the current working directory contains `src/test/resources/`, use it. Otherwise, ask the user for the target Java project path.

### For each feature (API and UI):

1. **Check if the target directory exists.** If not, create it:
   ```bash
   mkdir -p {projectPath}/src/test/resources/features/api
   mkdir -p {projectPath}/src/test/resources/features/ui
   ```

2. **Check if the feature file already exists:**
   - If YES → Read the existing file content, then append the new Scenario blocks at the end (before the final newline). Do NOT duplicate the Feature declaration, Background, or top-level tags.
   - If NO → Write the complete feature content as a new file.

3. **Write the files** using the Write tool (for new files) or Edit tool (for appending to existing files).

4. **Report completion:**

> **BDD Feature 文件已生成完成！**
>
> **写入文件：**
> - API: `{projectPath}/src/test/resources/features/api/{module}.feature`
> - UI: `{projectPath}/src/test/resources/features/ui/{module}.feature`
>
> {If there are NEW_STEP_NEEDED items:}
> **需要新增的步骤定义：**
> {list the new steps needed table from subagent 2 output}
>
> **下一步：**
> - 审查生成的 feature 文件
> - 如有 [NEW_STEP_NEEDED] 标记的步骤，请创建对应的 .snippet 或 Java step definition 文件
> - 运行 `cucumber --dry-run` 验证步骤绑定
