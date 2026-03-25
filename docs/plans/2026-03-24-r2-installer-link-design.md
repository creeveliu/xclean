# R2 安装入口设计

## 目标

把公开的 `curl | bash` 安装入口从 GitHub Raw 迁移到单一的 R2 托管 URL，让用户只看到一个安装链接，同时保持现有 GitHub release 流程不变。

## 约束

- 不修改现有 GitHub release workflow 或资产命名。
- 保持 `install.sh` 与现有 `XCLEAN_INSTALL_VERSION` 版本固定方式兼容。
- 当 R2 镜像缺失或暂时不可用时，保留回退路径。
- 所有文档中的公开安装说明应保持简单且一致。

## 设计

- 将 `install.sh` 托管在 `https://pub-d400c4fab9ed43a4b869b5bd85b09934.r2.dev/xclean/install.sh`。
- 将 release 产物镜像到 `https://pub-d400c4fab9ed43a4b869b5bd85b09934.r2.dev/xclean/releases`。
- 保持镜像 object key 与现有 GitHub Releases URL 布局兼容：
  - `xclean/releases/latest/download/xclean-macos-arm64.tar.gz`
  - `xclean/releases/latest/download/xclean-macos-x86_64.tar.gz`
  - `xclean/releases/download/v0.1.4/xclean-macos-arm64.tar.gz`
  - `xclean/releases/download/v0.1.4/xclean-macos-x86_64.tar.gz`
  - `xclean/releases/download/v0.1.4/sha256sums.txt`
- 修改 `install.sh`，让其默认 release base URL 指向 R2 镜像。
- 如果镜像下载失败，则重试一次 GitHub Releases，再回退到源码构建。
- 更新中英文 README，让所有公开安装示例都使用 R2 托管的 `install.sh`。

## 验证

- `bash -n install.sh`
- `swift test`
- `swift run xclean --help`
- `swift run xclean --version`
