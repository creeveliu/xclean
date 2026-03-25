# 更新前版本检查实现计划

> **给 Claude：** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标：** 让 `xclean update` 在安装前先检查最新 release 版本，输出清晰进度信息，在版本查询失败时直接失败退出，并同步修正文档和版本说明。

**架构：** 保持安装执行逻辑在 `Updater` 中，但在其中新增专用的远端版本查询和语义化版本比较路径。让 `CLI` 负责 update 分支的用户提示和分支控制，区分“已是最新”“需要升级”“检查失败”三种状态。同步更新文档，使其与新语义和当前版本保持一致。

**技术栈：** SwiftPM、Swift Foundation、XCTest、Bash 文档

---

### Task 1: 先为远端版本比较补失败测试

**Files:**
- Modify: `/Users/cl/Projects/xclean/Tests/XCleanCoreTests/UpdaterTests.swift`

**Step 1: 先写失败测试**

新增测试，验证：

- 本地 `0.1.7` 与远端 `v0.1.7` 被判定为已是最新
- 本地 `0.1.7` 与远端 `v0.1.8` 被判定为有更新
- 格式错误的远端版本会失败
- 远端获取失败会失败

使用注入的 test double，避免测试依赖真实网络访问。

**Step 2: 运行测试并确认它先失败**

Run: `swift test --filter UpdaterTests`
Expected: FAIL，因为 updater 当前还没有暴露远端版本查询和语义版本比较能力

**Step 3: 写最小实现**

在 `/Users/cl/Projects/xclean/Sources/XCleanCore/Updater.swift` 中：

- 增加一个小型版本值类型或 helper，把 `vX.Y.Z` 归一化成 `X.Y.Z`
- 增加按数字组件比较的逻辑
- 增加 updater 方法，用于解析最新远端版本并报告是否需要更新

**Step 4: 再跑测试并确认通过**

Run: `swift test --filter UpdaterTests`
Expected: PASS

**Step 5: 提交**

```bash
git add /Users/cl/Projects/xclean/Sources/XCleanCore/Updater.swift /Users/cl/Projects/xclean/Tests/XCleanCoreTests/UpdaterTests.swift
git commit -m "feat: compare update versions before install"
```

### Task 2: 先为 update 输出和分支逻辑补失败测试

**Files:**
- Modify: `/Users/cl/Projects/xclean/Tests/XCleanCoreTests/UpdaterTests.swift`
- Modify: `/Users/cl/Projects/xclean/Sources/XCleanCore/CLI.swift`

**Step 1: 先写失败测试**

新增 update 流程测试，断言：

- 首先输出当前版本
- 然后输出“正在检查更新中...”
- 当已是最新版本时，输出最新版本提示且不执行安装
- 当发现更高版本时，输出发现的新版本并触发安装
- 当版本查询失败时，报告错误并非零退出

如果当前 CLI 结构不易测试，就从 `CLI.swift` 中提取一个小型 helper 专门处理 update 命令。

**Step 2: 运行测试并确认它先失败**

Run: `swift test --filter UpdaterTests`
Expected: FAIL，因为当前 CLI update 流程总是执行安装器，也不会输出这些提示

**Step 3: 写最小实现**

在 `/Users/cl/Projects/xclean/Sources/XCleanCore/CLI.swift` 中：

- 输出 `当前版本：<version>`
- 输出 `正在检查更新中...`
- 调用 updater 的版本检查方法
- 若版本相同，输出 `当前是最新版本（<version>）` 并退出 0
- 若有更高版本，输出 `发现新版本：<version>，开始安装...`，然后执行安装
- 若检查失败，把直接错误输出到 stderr 并退出 1

**Step 4: 再跑测试并确认通过**

Run: `swift test --filter UpdaterTests`
Expected: PASS

**Step 5: 提交**

```bash
git add /Users/cl/Projects/xclean/Sources/XCleanCore/CLI.swift /Users/cl/Projects/xclean/Tests/XCleanCoreTests/UpdaterTests.swift
git commit -m "feat: show update check status"
```

### Task 3: 更新命令文案和过期版本引用

**Files:**
- Modify: `/Users/cl/Projects/xclean/AGENTS.md`
- Modify: `/Users/cl/Projects/xclean/README.md`
- Modify: `/Users/cl/Projects/xclean/README.zh-CN.md`

**Step 1: 先写失败检查**

运行搜索，确认过期文案仍然存在：

- `rg -n "0\\.1\\.4|Reinstall the latest version|重新执行安装脚本" /Users/cl/Projects/xclean/AGENTS.md /Users/cl/Projects/xclean/README.md /Users/cl/Projects/xclean/README.zh-CN.md`

**Step 2: 运行检查并确认它先失败**

Run: `rg -n "0\\.1\\.4|Reinstall the latest version|重新执行安装脚本" /Users/cl/Projects/xclean/AGENTS.md /Users/cl/Projects/xclean/README.md /Users/cl/Projects/xclean/README.zh-CN.md`
Expected: 在编辑前能搜索到匹配项

**Step 3: 写最小实现**

更新：

- `/Users/cl/Projects/xclean/AGENTS.md`，反映当前版本
- `/Users/cl/Projects/xclean/README.md`，把 `xclean update` 说明改成“检查更新，有更新时再安装”
- `/Users/cl/Projects/xclean/README.zh-CN.md`，做相同的中文语义修正

**Step 4: 再跑检查并确认通过**

Run: `rg -n "0\\.1\\.4|Reinstall the latest version|重新执行安装脚本" /Users/cl/Projects/xclean/AGENTS.md /Users/cl/Projects/xclean/README.md /Users/cl/Projects/xclean/README.zh-CN.md`
Expected: 只剩有意保留的引用，或不再有过期表述

**Step 5: 提交**

```bash
git add /Users/cl/Projects/xclean/AGENTS.md /Users/cl/Projects/xclean/README.md /Users/cl/Projects/xclean/README.zh-CN.md
git commit -m "docs: align update semantics and version notes"
```

### Task 4: 跑项目校验

**Files:**
- Modify: none

**Step 1: 跑完整测试**

Run: `swift test`
Expected: PASS

**Step 2: 校验 CLI help**

Run: `swift run xclean --help`
Expected: PASS，且 help 文案体现新的 update 语义

**Step 3: 校验 CLI version**

Run: `swift run xclean --version`
Expected: PASS，且输出当前版本

**Step 4: 审查 diff**

Run: `git diff -- /Users/cl/Projects/xclean/Sources/XCleanCore /Users/cl/Projects/xclean/Tests/XCleanCoreTests /Users/cl/Projects/xclean/README.md /Users/cl/Projects/xclean/README.zh-CN.md /Users/cl/Projects/xclean/AGENTS.md`
Expected: only update-flow and documentation/version-alignment changes

**Step 5: 提交**

```bash
git add /Users/cl/Projects/xclean/Sources/XCleanCore /Users/cl/Projects/xclean/Tests/XCleanCoreTests /Users/cl/Projects/xclean/README.md /Users/cl/Projects/xclean/README.zh-CN.md /Users/cl/Projects/xclean/AGENTS.md
git commit -m "feat: check updates before reinstalling"
```
