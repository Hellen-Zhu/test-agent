---
description: Generate BDD Cucumber feature files (API + UI) from User Stories
---

# BDD Feature Generation Agent

You are an orchestrator that transforms User Stories into layered BDD Cucumber feature files following the genie test framework conventions.

**Input:** `$ARGUMENTS` — either a local JSON file path, an ADO Work Item ID, or an ADO Work Item URL.

## Step 1: Parse Arguments

Determine the input source type from `$ARGUMENTS`:

- **JSON file mode:** If the argument starts with `/`, `./`, `~`, or ends with `.json` → treat as a local JSON file path
- **ADO mode:** If the argument is a number, contains `dev.azure.com`, or starts with `ado:` → treat as an Azure DevOps Work Item

If the argument is empty or doesn't match either pattern, ask the user to provide a valid source:
> "Please provide a source: a JSON file path (e.g. `./stories/login.json`) or an ADO Work Item (e.g. `13424715`, `ado:13424715`, or full ADO URL)"

## Step 2: Read User Story

### If JSON file mode:
Use the **Read** tool to read the file at the provided path.

### If ADO mode:
Use the **ado-agent** MCP tool to fetch the Work Item details. Extract the Work Item ID from the argument:
- If the argument is a pure number → use it directly
- If the argument is `ado:{id}` → extract the number after `ado:`
- If the argument is a full URL → extract the ID from the URL path

The ado-agent MCP tool will return structured User Story information including title, description, acceptance criteria, state, sprint, tags, and scope.

## Step 3: Normalize Format

Convert the raw input to a normalized structure. Detect the format:

**If the input came from ado-agent MCP** → extract from the structured output:
- `title` = the User Story title
- `description` = the User Story description text
- `acceptanceCriteria` = the numbered acceptance criteria items (parse into an array of strings)
- `scope` = scope information if available (module, API changes, UI changes)

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

Read the agent prompt file at `.claude/agents/bdd-agent.md`.

Use the **Agent** tool to spawn a subagent. Construct the prompt by:
1. Including the **"Phase 1: Test Layering Analysis"** section from the agent file
2. Replacing `{title}`, `{description}`, and `{acceptanceCriteria}` with the actual normalized values

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

Read the agent prompt file at `.claude/agents/bdd-agent.md`.

Use the **Agent** tool to spawn a subagent. Construct the prompt by:
1. Including the **"Phase 2: BDD Feature Generation"** section from the agent file
2. Replacing placeholders: `{title}`, `{description}`, `{acceptanceCriteria}`, `{layeringReport}` (confirmed output from Step 5), and `{projectPath}` (the current working directory or target Java project root)

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
   - If YES → Read the existing file content, then append the new Scenario blocks at the end. Do NOT duplicate the Feature declaration, Background, or top-level tags.
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
