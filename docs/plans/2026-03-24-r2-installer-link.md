# R2 安装入口实现计划

> **给 Claude：** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标：** 在不改变现有 GitHub release 流程的前提下，把公开安装入口切换为单一的 R2 URL。

**架构：** 安装器默认从 R2 镜像下载 release 资产；如果镜像失败，则重试 GitHub Releases。对外文档只暴露 R2 托管的安装脚本 URL。

**技术栈：** Bash、SwiftPM 文档、现有 release 资产命名

---

### Task 1: 更新安装器默认值

**Files:**
- Modify: `install.sh`

**Step 1: 先写失败测试**

运行一个 shell 断言，要求 `install.sh` 中已经存在 R2 基础 URL。

**Step 2: 运行测试并确认它先失败**

Run: `test -n "$(rg -n 'pub-d400c4fab9ed43a4b869b5bd85b09934\\.r2\\.dev/xclean/releases' install.sh)"`
Expected: fail，因为脚本默认值仍指向 GitHub Releases

**Step 3: 写最小实现**

把默认 `XCLEAN_RELEASE_BASE_URL` 设为 R2 镜像，并在预构建镜像下载失败时增加一次 GitHub Releases 重试。

**Step 4: 再跑测试并确认通过**

Run: `rg -n 'pub-d400c4fab9ed43a4b869b5bd85b09934\\.r2\\.dev/xclean/releases|github.com/creeveliu/xclean/releases' install.sh`
Expected: R2 默认值已存在，GitHub Releases 回退也仍然存在

### Task 2: 更新公开安装文档

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`

**Step 1: 先写失败测试**

运行一个 shell 断言，要求 R2 安装脚本 URL 成为文档中公开展示的安装命令。

**Step 2: 运行测试并确认它先失败**

Run: `test -n "$(rg -n 'pub-d400c4fab9ed43a4b869b5bd85b09934\\.r2\\.dev/xclean/install\\.sh' README.md README.zh-CN.md)"`
Expected: fail，因为两个 README 仍指向 GitHub Raw

**Step 3: 写最小实现**

把公开安装示例替换为 R2 URL，并说明安装器使用的 R2 镜像路径布局。

**Step 4: 再跑测试并确认通过**

Run: `test -z "$(rg -n 'raw\\.githubusercontent\\.com/creeveliu/xclean/main/install\\.sh' README.md README.zh-CN.md)"`
Expected: pass，因为公开安装命令已不再使用 GitHub Raw

### Task 3: 校验行为

**Files:**
- Modify: `install.sh`
- Modify: `README.md`
- Modify: `README.zh-CN.md`

**Step 1: 校验 shell 语法**

Run: `bash -n install.sh`
Expected: success with no output

**Step 2: 运行包测试**

Run: `swift test`
Expected: all tests pass

**Step 3: 校验 CLI help**

Run: `swift run xclean --help`
Expected: usage output is shown

**Step 4: 校验 CLI version**

Run: `swift run xclean --version`
Expected: `0.1.4`
