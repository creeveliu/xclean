# 模拟器设备选择实现计划

> **给 Claude：** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标：** 把 `CoreSimulator/Devices` 的整目录删除改成按设备选择和删除，同时提示用户保留一个常用模拟器。

**架构：** 扩展扫描模型，使 `simulator-devices` 能暴露基于 `simctl` 元数据和已匹配目录构建出的嵌套设备候选项。终端交互仍按层级组织，但为模拟器设备新增二级选择步骤，仅确认并删除所选子目录。保留现有路径安全规则和单项失败隔离。

**技术栈：** Swift 6.1、SwiftPM、Foundation、XCTest

---

### Task 1: 先为模拟器设备候选扫描补失败测试

**Files:**
- Modify: `/Users/cl/Projects/xclean/Tests/XCleanCoreTests/ScannerAggregationTests.swift`
- Modify: `/Users/cl/Projects/xclean/Tests/XCleanCoreTests/MockProcessRunner.swift`

**Step 1: 先写失败测试**

新增测试，创建一个临时 `CoreSimulator/Devices` 目录，其中包含两个 UDID 子目录和一个无法映射的子目录，然后断言扫描结果：
- 为已匹配的 UDID 返回设备级候选项
- 包含来自 `simctl list devices --json` 的展示元数据
- 恰好有一个候选项被标记为建议保留
- 对未映射目录报告 skipped 信息

**Step 2: 运行测试并确认它先失败**

Run: `swift test --filter ScannerAggregationTests`
Expected: FAIL，因为 `ScannedItem` 和 scanner 逻辑还没有暴露模拟器设备候选项

**Step 3: 写最小实现**

先不要实现。确认红灯后停下。

**Step 4: 再次运行并确认仍按预期失败**

Run: `swift test --filter ScannerAggregationTests`
Expected: FAIL，并且失败原因应是缺少模型成员或候选输出不符合断言

**Step 5: 提交**

```bash
git add /Users/cl/Projects/xclean/Tests/XCleanCoreTests/ScannerAggregationTests.swift /Users/cl/Projects/xclean/Tests/XCleanCoreTests/MockProcessRunner.swift
git commit -m "test: cover simulator device candidate scanning"
```

### Task 2: 实现模拟器设备扫描模型和 scanner 支持

**Files:**
- Modify: `/Users/cl/Projects/xclean/Sources/XCleanCore/Models.swift`
- Modify: `/Users/cl/Projects/xclean/Sources/XCleanCore/Scanner.swift`

**Step 1: 以 Task 1 的失败测试为当前红灯**

**Step 2: 运行测试并确认当前仍失败**

Run: `swift test --filter ScannerAggregationTests`
Expected: FAIL before implementation

**Step 3: 写最小实现**

实现：

- 一个可复用的嵌套候选项模型，用于可展开的扫描条目
- 模拟器设备专用候选字段：设备名、runtime、UDID、路径、大小、保留建议
- `xcrun simctl list devices --json` 的 JSON 解析
- `CoreSimulator/Devices` 子目录与 UDID 的精确匹配
- skipped-entry 详情报告
- 当 `simctl` 失败或没有任何候选能被安全映射时，保持默认安全行为

其它非模拟器规则保持不变。

**Step 4: 再跑测试并确认通过**

Run: `swift test --filter ScannerAggregationTests`
Expected: PASS

**Step 5: 提交**

```bash
git add /Users/cl/Projects/xclean/Sources/XCleanCore/Models.swift /Users/cl/Projects/xclean/Sources/XCleanCore/Scanner.swift
git commit -m "feat: scan simulator devices individually"
```

### Task 3: 先为仅删除选中模拟器子目录补失败测试

**Files:**
- Modify: `/Users/cl/Projects/xclean/Tests/XCleanCoreTests/CleanerTests.swift`

**Step 1: 先写失败测试**

新增测试，要求：

- 创建一个包含多个子目录的 `CoreSimulator/Devices` 根目录
- 只选择一个设备候选项进行删除
- 断言只有被选中的子目录被删除
- 根目录和未选中的子目录仍然存在

同时增加一个测试，验证不安全或未映射的设备路径会被拒绝。

**Step 2: 运行测试并确认它先失败**

Run: `swift test --filter CleanerTests`
Expected: FAIL，因为 cleaner 当前只支持按规则整项删除

**Step 3: 写最小实现**

先不要实现。确认红灯后停下。

**Step 4: 再次运行并确认仍按预期失败**

Run: `swift test --filter CleanerTests`
Expected: FAIL，断言显示当前不支持模拟器子目录级删除

**Step 5: 提交**

```bash
git add /Users/cl/Projects/xclean/Tests/XCleanCoreTests/CleanerTests.swift
git commit -m "test: cover simulator subdirectory deletion"
```

### Task 4: 实现设备级模拟器删除

**Files:**
- Modify: `/Users/cl/Projects/xclean/Sources/XCleanCore/Cleaner.swift`
- Modify: `/Users/cl/Projects/xclean/Sources/XCleanCore/Models.swift`

**Step 1: 以 Task 3 的失败测试为当前红灯**

**Step 2: 运行测试并确认当前仍失败**

Run: `swift test --filter CleanerTests`
Expected: FAIL before implementation

**Step 3: 写最小实现**

实现对选中模拟器设备候选项的删除支持：

- 在删除请求中表达选中的候选路径
- 对每个选中的子路径都做 `PathSafetyValidator` 校验
- 只删除选中的子目录
- 保持按项独立的结果报告

非模拟器删除行为保持不变。

**Step 4: 再跑测试并确认通过**

Run: `swift test --filter CleanerTests`
Expected: PASS

**Step 5: 提交**

```bash
git add /Users/cl/Projects/xclean/Sources/XCleanCore/Cleaner.swift /Users/cl/Projects/xclean/Sources/XCleanCore/Models.swift
git commit -m "feat: delete selected simulator devices only"
```

### Task 5: 先为模拟器设备选择交互补失败测试

**Files:**
- Modify: `/Users/cl/Projects/xclean/Tests/XCleanCoreTests/TerminalUITests.swift`

**Step 1: 先写失败测试**

新增测试，断言：

- `CoreSimulator/Devices` 会进入设备级选择流程
- 输出显示设备名称、runtime、大小和路径
- 有一个条目标记为建议保留
- 确认信息提醒用户尽量保留一个常用模拟器
- 结果输出反映的是所选设备删除，而不是根目录删除

**Step 2: 运行测试并确认它先失败**

Run: `swift test --filter TerminalUITests`
Expected: FAIL，因为 UI 当前仍把 `simulator-devices` 当作普通规则项处理

**Step 3: 写最小实现**

先不要实现。确认红灯后停下。

**Step 4: 再次运行并确认仍按预期失败**

Run: `swift test --filter TerminalUITests`
Expected: FAIL，缺少设备级交互与输出

**Step 5: 提交**

```bash
git add /Users/cl/Projects/xclean/Tests/XCleanCoreTests/TerminalUITests.swift
git commit -m "test: cover simulator device selection ui"
```

### Task 6: 实现模拟器设备选择 UI 和本地化文案

**Files:**
- Modify: `/Users/cl/Projects/xclean/Sources/XCleanCore/TerminalUI.swift`
- Modify: `/Users/cl/Projects/xclean/Sources/XCleanCore/Localization.swift`
- Modify: `/Users/cl/Projects/xclean/Sources/XCleanCore/Models.swift`

**Step 1: 以 Task 5 的失败测试为当前红灯**

**Step 2: 运行测试并确认当前仍失败**

Run: `swift test --filter TerminalUITests`
Expected: FAIL before implementation

**Step 3: 写最小实现**

实现：

- 在现有谨慎层级流程下增加模拟器设备详情视图
- 支持按索引选择设备候选项
- 本地化“建议保留”文案
- 本地化 skipped-entry 提示
- 基于选中设备渲染确认输出
- 用直白文案提醒用户尽量保留一个常用模拟器

其它规则的交互保持不变。

**Step 4: 再跑测试并确认通过**

Run: `swift test --filter TerminalUITests`
Expected: PASS

**Step 5: 提交**

```bash
git add /Users/cl/Projects/xclean/Sources/XCleanCore/TerminalUI.swift /Users/cl/Projects/xclean/Sources/XCleanCore/Localization.swift /Users/cl/Projects/xclean/Sources/XCleanCore/Models.swift
git commit -m "feat: add simulator device selection flow"
```

### Task 7: 更新文档以说明新的谨慎清理行为

**Files:**
- Modify: `/Users/cl/Projects/xclean/README.md`
- Modify: `/Users/cl/Projects/xclean/README.zh-CN.md`

**Step 1: 写失败检查**

不要求自动化文档测试，使用显式检查清单：
- README 不再暗示 `CoreSimulator/Devices` 会被一步整目录删除
- README 解释按设备选择和“保留一个常用模拟器”的建议

**Step 2: 运行检查并确认当前不匹配**

手工检查当前文档，确认仍在描述旧的粗粒度行为。

**Step 3: 写最小实现**

更新两个 README，说明：
- 模拟器设备会单独展示
- 用户只能删除选中的模拟器文件夹
- 建议保留一个常用模拟器

**Step 4: 再次检查并确认通过**

手工检查编辑后的文档是否与实现一致。
