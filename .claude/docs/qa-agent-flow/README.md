# QA Agent Flow: API + E2E BDD Automation

这套 flow 用来模拟一名高级测试工程师从需求分析到自动化落地的完整思维过程，适合用于 Java + Cucumber 的 API + E2E hybrid 自动化测试体系。

English version: [en/README.md](./en/README.md)

## Agent 列表

0. [Flow Orchestrator](./00-flow-orchestrator.md)
   - 编排 4 个 agent 的执行顺序、输入输出交接、质量门禁和返工规则。

1. [Requirement Agent](./01-requirement-agent.md)
   - 把需求转化为可测试、可讨论、可验收的业务模型。

2. [Test Strategy Agent](./02-test-strategy-agent.md)
   - 基于风险和分层测试策略，决定测什么、在哪一层测、优先级是什么。

3. [BDD + Case Design Agent](./03-bdd-case-design-agent.md)
   - 把验收标准和测试策略转成 Gherkin Feature、Scenario、Scenario Outline 和测试用例矩阵。

4. [Automation + Review Agent](./04-automation-review-agent.md)
   - 将 BDD 场景转成可维护的自动化实现方案，并进行框架、代码、稳定性和质量门禁评审。

## 推荐执行 Flow

```text
业务需求 / PRD / User Story / API 文档 / UI 原型
  ↓
Requirement Agent
  输出：业务规则、验收标准、边界条件、异常场景、疑问清单
  ↓
Test Strategy Agent
  输出：风险矩阵、分层测试策略、自动化范围、执行优先级
  ↓
BDD + Case Design Agent
  输出：Feature 文件、Scenario、Examples、测试用例矩阵、Tag 设计
  ↓
Automation + Review Agent
  输出：Java + Cucumber 自动化实现方案、代码结构、评审清单、质量门禁
```

## 使用方式

每个 Markdown 文件都可以直接作为一个 agent 的系统提示词或团队工作规范使用。

如果你的工具支持 slash command，也可以直接使用 [commands](./commands/README.md) 目录里的 5 个 command 模板：

- `/qa-flow`
- `/qa-requirement`
- `/qa-strategy`
- `/qa-bdd`
- `/qa-automation-review`

建议使用方式：

1. 把对应文件内容复制到 agent 的 system prompt 或 instruction 中。
2. 每个 agent 只接收上游 agent 的结构化产出，不直接跳过流程。
3. 每个 agent 必须按自己的输出格式输出，方便下游 agent 消费。
4. 总控 agent 或人工 reviewer 负责检查每一步是否满足质量门禁。

## 统一协作原则

- 不凭空假设需求，所有推断必须标注为 `Assumption`。
- 所有疑问必须进入 `Open Questions`。
- 需求不清楚时，优先输出澄清问题，而不是直接编写测试代码。
- 自动化不是目标，风险覆盖和可维护性才是目标。
- 能在 API 层稳定验证的，不放到 E2E 层重复验证。
- Feature 文件使用业务语言，不暴露页面点击、接口路径、数据库字段等实现细节。
- Step Definition 保持轻薄，复杂业务逻辑下沉到 domain action。
- 所有测试数据必须可隔离、可重复、可清理。

## 统一输入模板

```md
# Input

## Requirement
粘贴 PRD、User Story、验收标准、接口说明、UI 原型说明或业务背景。

## Context
- 系统名称：
- 业务域：
- 相关角色：
- 相关服务：
- 相关页面：
- 已知约束：

## Target
- 本次希望产出：
- 自动化范围：
- 技术栈：
- 执行环境：

## Existing Artifacts
- 现有 Feature：
- 现有 API 文档：
- 现有测试用例：
- 现有自动化框架：
```

## 统一质量门禁

每个需求进入自动化实现前，至少满足：

- 验收标准明确。
- 核心业务规则明确。
- 高风险路径已识别。
- 分层测试策略已确定。
- API 和 E2E 的覆盖边界已确定。
- BDD 场景可读、可执行、可维护。
- 测试数据策略明确。
- 断言点不仅包含成功状态，还包含业务结果和状态变化。
- CI 执行策略和 Tag 设计明确。
