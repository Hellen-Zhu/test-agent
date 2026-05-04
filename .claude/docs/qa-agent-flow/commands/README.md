# QA Slash Commands

这个目录提供 5 个可以直接复制到不同 agent 平台里的 command 模板。

## Command 列表

| Command | File | Purpose |
| --- | --- | --- |
| `/qa-flow` | [qa-flow.md](./qa-flow.md) | 一次性跑完整 QA flow：需求分析、测试策略、BDD 设计、自动化评审 |
| `/qa-requirement` | [qa-requirement.md](./qa-requirement.md) | 只做需求可测试性分析 |
| `/qa-strategy` | [qa-strategy.md](./qa-strategy.md) | 基于需求分析结果制定分层测试策略 |
| `/qa-bdd` | [qa-bdd.md](./qa-bdd.md) | 基于需求和策略生成 BDD 场景与测试用例矩阵 |
| `/qa-automation-review` | [qa-automation-review.md](./qa-automation-review.md) | 基于 BDD 场景设计自动化实现方案并做质量评审 |

## command 和 agent 的关系

```text
agent md = 完整岗位说明书
command md = 调用这个岗位能力的快捷入口
```

如果你的平台支持独立 agent：

```text
Agent Prompt 放进 agent system prompt
Command 只负责调用 agent
```

如果你的平台只支持 command：

```text
Command 里面直接放 Agent Prompt + {{user_input}}
```

这个目录采用第二种方式，所以每个 command 都可以单独使用。

## 推荐使用顺序

```text
/qa-requirement <原始需求>
  ↓
/qa-strategy <Requirement Agent 输出>
  ↓
/qa-bdd <Requirement + Strategy 输出>
  ↓
/qa-automation-review <BDD + Strategy 输出>
```

如果想一次性执行完整流程：

```text
/qa-flow <原始需求>
```

## 占位符说明

不同平台的占位符语法不同，这里统一使用：

```text
{{user_input}}
```

你可以按平台替换为：

| Platform | Possible Placeholder |
| --- | --- |
| Generic | `{{user_input}}` |
| Cursor / custom command | `$ARGUMENTS` |
| Claude command style | `$ARGUMENTS` |
| Shell wrapper | `$1` or stdin |
| 自建 agent 平台 | request body 中的 input 字段 |
