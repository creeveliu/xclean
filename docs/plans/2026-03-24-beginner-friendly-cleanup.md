# 面向新手的清理流程实现计划

> **给 Claude：** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标：** 重构 `xclean` 的交互式清理流程，让非专业用户通过更友好的清理层级和双语提示来决策，而不是直接面对技术分类名词。

**架构：** 保持扫描和删除行为不变，但引入用户可见的清理层级模型和轻量级本地化层。`TerminalUI` 改为按本地化层级分组和本地化规则说明来驱动，同时保留既有安全检查和规则标题。

**技术栈：** SwiftPM、Swift Foundation、XCTest

---

### Task 1: 在核心模型中加入清理层级

**Files:**
- Modify: `Sources/XCleanCore/Models.swift`
- Test: `Tests/XCleanCoreTests/RuleDefinitionTests.swift`

**Step 1: 先写失败测试**

在 `Tests/XCleanCoreTests/RuleDefinitionTests.swift` 中加入断言，验证：

- `DerivedData`、`UserData/Previews` 和 `simctl-unavailable` 归属到 safe 层级
- `DocumentationCache`、device support 和 logs 归属到 clean-if-needed 层级
- `CoreSimulator/Devices` 归属到 careful 层级

**Step 2: 运行测试并确认它先失败**

Run: `swift test --filter RuleDefinitionTests`
Expected: FAIL，因为当前还没有清理层级模型

**Step 3: 写最小实现**

在 `Sources/XCleanCore/Models.swift` 中：

- 新增 `CleanupTier` 枚举，包含 `safe`、`cleanIfNeeded`、`careful`
- 给 `CleanupRule` 增加 `tier` 属性
- 按批准后的层级映射填充默认规则

**Step 4: 再跑测试并确认通过**

Run: `swift test --filter RuleDefinitionTests`
Expected: PASS

**Step 5: 提交**

```bash
git add /Users/cl/Projects/xclean/Sources/XCleanCore/Models.swift /Users/cl/Projects/xclean/Tests/XCleanCoreTests/RuleDefinitionTests.swift
git commit -m "feat: add user-facing cleanup tiers"
```

### Task 2: 加入轻量级语言检测和共享本地化字符串

**Files:**
- Create: `Sources/XCleanCore/Localization.swift`
- Test: `Tests/XCleanCoreTests/LocalizationTests.swift`

**Step 1: 先写失败测试**

创建 `Tests/XCleanCoreTests/LocalizationTests.swift`，覆盖：

- `zh-Hans`、`zh-CN`、`zh` 都解析为中文
- `en-US` 和未知值回退到英文
- 层级标题和共享 UI 标签返回预期的本地化字符串

**Step 2: 运行测试并确认它先失败**

Run: `swift test --filter LocalizationTests`
Expected: FAIL，因为本地化类型还不存在

**Step 3: 写最小实现**

创建 `Sources/XCleanCore/Localization.swift`，内容包括：

- 一个很小的 `AppLanguage` 枚举，包含 `english` 和 `simplifiedChinese`
- 基于用户首选语言标识的检测逻辑
- 集中管理层级名、层级描述、提示语、确认文案和标题文案

**Step 4: 再跑测试并确认通过**

Run: `swift test --filter LocalizationTests`
Expected: PASS

**Step 5: 提交**

```bash
git add /Users/cl/Projects/xclean/Sources/XCleanCore/Localization.swift /Users/cl/Projects/xclean/Tests/XCleanCoreTests/LocalizationTests.swift
git commit -m "feat: add lightweight cli localization"
```

### Task 3: 加入本地化、面向决策的规则说明文案

**Files:**
- Modify: `Sources/XCleanCore/Models.swift`
- Test: `Tests/XCleanCoreTests/RuleDefinitionTests.swift`

**Step 1: 先写失败测试**

扩展 `Tests/XCleanCoreTests/RuleDefinitionTests.swift`，断言每个代表性规则都能提供：

- 本地化的 “what it is” 文案
- 本地化的 “after deletion” 文案
- 本地化的 “when to clean” 文案

至少使用 `DerivedData` 和 `CoreSimulator/Devices` 各写一条英文和中文期望。

**Step 2: 运行测试并确认它先失败**

Run: `swift test --filter RuleDefinitionTests`
Expected: FAIL，因为规则模型当前没有暴露本地化决策文案

**Step 3: 写最小实现**

在 `Sources/XCleanCore/Models.swift` 中：

- 为 `CleanupRule` 增加本地化展示 helper
- 保持规则标题不变
- 为所有默认规则补齐英文和中文的面向决策文案

**Step 4: 再跑测试并确认通过**

Run: `swift test --filter RuleDefinitionTests`
Expected: PASS

**Step 5: 提交**

```bash
git add /Users/cl/Projects/xclean/Sources/XCleanCore/Models.swift /Users/cl/Projects/xclean/Tests/XCleanCoreTests/RuleDefinitionTests.swift
git commit -m "feat: add localized cleanup guidance"
```

### Task 4: 按清理层级重构终端菜单

**Files:**
- Modify: `Sources/XCleanCore/TerminalUI.swift`
- Modify: `Sources/XCleanCore/CLI.swift`
- Test: `Tests/XCleanCoreTests/TerminalUITests.swift`

**Step 1: 先写失败测试**

创建 `Tests/XCleanCoreTests/TerminalUITests.swift`，验证：

- 顶层菜单按清理层级分组
- 层级标题渲染本地化的层级名和说明
- 条目渲染展示本地化的面向决策说明，而不是原始 recommendation label
- 确认输出包含本地化的影响说明

优先从 `TerminalUI` 中提取纯渲染 helper，这样测试可以直接断言生成字符串，而不必 mock stdin。

**Step 2: 运行测试并确认它先失败**

Run: `swift test --filter TerminalUITests`
Expected: FAIL，因为 UI 目前仍按技术分类和英文提示渲染

**Step 3: 写最小实现**

在 `Sources/XCleanCore/TerminalUI.swift` 中：

- 注入或推导当前语言
- 用清理层级替换原来的 category-first 菜单
- 渲染本地化层级说明
- 用本地化的决策说明渲染每个条目
- 把删除确认和结果标题改成本地化字符串

在 `Sources/XCleanCore/CLI.swift` 中：

- 用已解析出的语言来构建 `TerminalUI`，或者让 `TerminalUI` 在内部以可测试的方式解析

**Step 4: 再跑测试并确认通过**

Run: `swift test --filter TerminalUITests`
Expected: PASS

**Step 5: 提交**

```bash
git add /Users/cl/Projects/xclean/Sources/XCleanCore/TerminalUI.swift /Users/cl/Projects/xclean/Sources/XCleanCore/CLI.swift /Users/cl/Projects/xclean/Tests/XCleanCoreTests/TerminalUITests.swift
git commit -m "feat: add tier-based localized cleanup flow"
```

### Task 5: 更新文档以匹配新行为

**Files:**
- Modify: `README.md`

**Step 1: 写失败检查**

手工检查 `README.md`，确认它目前还没有描述：

- 基于层级的清理流程
- 双语提示
- safe、clean-if-needed、careful 三种层级的区别

**Step 2: 运行检查并确认不匹配**

Run: `rg -n "Safe Cleanup|Clean If Needed|Careful Cleanup|安全清理|按需清理|谨慎清理" README.md`
Expected: no matches

**Step 3: 写最小实现**

更新 `README.md`，说明：

- 新的层级化交互体验
- 提示会根据系统语言显示英文或简体中文
- `CoreSimulator/Devices` 会出现在谨慎清理中，因为它可能删除模拟器本地 App 数据

**Step 4: 再跑检查并确认通过**

Run: `rg -n "Safe Cleanup|Clean If Needed|Careful Cleanup|安全清理|按需清理|谨慎清理" README.md`
Expected: matches present

**Step 5: 提交**

```bash
git add /Users/cl/Projects/xclean/README.md
git commit -m "docs: describe tiered localized cleanup flow"
```

### Task 6: 跑项目校验

**Files:**
- Modify: none

**Step 1: 跑完整测试**

Run: `swift test`
Expected: PASS

**Step 2: 校验 CLI help**

Run: `swift run xclean --help`
Expected: PASS，且 usage 文本能正常输出

**Step 3: 校验 CLI version**

Run: `swift run xclean --version`
Expected: PASS，且输出当前版本

**Step 4: 审查 diff**

Run: `git diff -- Sources/XCleanCore README.md Tests/XCleanCoreTests`
Expected: only intended tiering/localization/documentation changes

**Step 5: 提交**

```bash
git add /Users/cl/Projects/xclean/Sources/XCleanCore /Users/cl/Projects/xclean/Tests/XCleanCoreTests /Users/cl/Projects/xclean/README.md
git commit -m "feat: make cleanup flow beginner friendly"
```
