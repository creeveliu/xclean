# xclean

`xclean` is a lightweight macOS Swift CLI for interactively cleaning common Xcode junk files.

[中文说明](./README.zh-CN.md)

## Install

Remote install:

```bash
curl -fsSL https://pub-d400c4fab9ed43a4b869b5bd85b09934.r2.dev/xclean/install.sh | bash
```

Pin to a specific release:

```bash
curl -fsSL https://pub-d400c4fab9ed43a4b869b5bd85b09934.r2.dev/xclean/install.sh | \
  XCLEAN_INSTALL_VERSION=v0.1.7 bash
```

Local development install:

```bash
bash install.sh
```

The installer:

- first tries to download a prebuilt release archive
- falls back to cloning the repo and building with Swift in release mode
- installs `xclean` to `~/.local/bin`

You can override defaults:

```bash
XCLEAN_RELEASE_BASE_URL=https://pub-d400c4fab9ed43a4b869b5bd85b09934.r2.dev/xclean/releases \
XCLEAN_INSTALL_VERSION=latest \
XCLEAN_REPO_URL=https://github.com/creeveliu/xclean.git \
XCLEAN_INSTALL_REF=main \
XCLEAN_INSTALL_DIR="$HOME/.local/bin" \
curl -fsSL https://pub-d400c4fab9ed43a4b869b5bd85b09934.r2.dev/xclean/install.sh | bash
```

## Usage

```bash
xclean
xclean clean
xclean scan
xclean update
xclean uninstall
xclean --version
```

`xclean update` reruns the installer and replaces the current binary in the same install directory.
`xclean uninstall` removes the current binary and deletes the install directory if it becomes empty.

## Screenshot

Interactive cleanup prompt with Simplified Chinese localization:

![Interactive cleanup screenshot](docs/screenshots/interactive-cleanup-zh.png)

## Interactive Cleanup

The interactive flow is organized by cleanup impact instead of Xcode internals:

- `Safe Cleanup`
  Good first choice. These items are temporary caches that will be rebuilt automatically when needed.
- `Clean If Needed`
  Usually safe to delete, but some related files may need to be rebuilt or downloaded again later.
- `Careful Cleanup`
  Still valid to clean, but you should decide item-by-item because it may remove simulator-local environments or test data.

Examples:

- `DerivedData`, `UserData/Previews`, and unavailable simulators appear in `Safe Cleanup`
- documentation cache, device support files, and logs appear in `Clean If Needed`
- `CoreSimulator/Devices` appears in `Careful Cleanup`, then expands into individual simulator device folders

Each item explains:

- what it is
- what happens after deletion
- when it makes sense to clean it

Prompts automatically follow the system's preferred language:

- Simplified Chinese is used when the preferred language starts with `zh`
- English is used otherwise

Technical names such as `DerivedData` and `CoreSimulator/Devices` stay unchanged so the output still maps clearly to real Xcode paths.

## Scope

`xclean` only targets Xcode-related paths under the current user's home directory:

- `DerivedData`
- `DocumentationCache`
- `UserData/Previews`
- `iOS DeviceSupport`
- `tvOS DeviceSupport`
- `CoreSimulator/Devices`
- unavailable simulators via `xcrun simctl delete unavailable`
- optional log directories

It does not touch archives, signing assets, or provisioning profiles.

`CoreSimulator/Devices` is included as a cautious target because deleting simulator device folders may reset those devices and remove simulator-local app data.

When you select `CoreSimulator/Devices`, `xclean` does not delete the whole folder at once.
It loads recognizable simulator device subfolders, shows device name, runtime, size, and path, and lets you choose which ones to remove.
The prompt also recommends keeping one commonly used simulator when possible so you do not wipe every local simulator environment in one pass.

## Release Packaging

Build a release archive:

```bash
./scripts/build-release.sh
```

The archive is written to `dist/`.

For GitHub Releases, upload at least:

- `xclean-macos-arm64.tar.gz`
- `xclean-macos-x86_64.tar.gz`
- optionally the versioned archives and `sha256sums.txt`

Push a version tag to trigger the full release workflow:

```bash
git push
git tag v0.1.7
git push origin v0.1.7
```

GitHub Actions will then:

- create the GitHub release
- build and upload release assets
- merge `sha256sums.txt`
- sync the installer and release assets to R2

If you need a manual fallback for R2 sync:

```bash
bash scripts/upload-r2.sh 0.1.7
```

## Publishing `curl | bash`

Current public installer:

```bash
curl -fsSL https://pub-d400c4fab9ed43a4b869b5bd85b09934.r2.dev/xclean/install.sh | bash
```

Current release page:

```text
https://github.com/creeveliu/xclean/releases
```

Mirror release assets to the R2 bucket using the same path layout expected by the installer:

```text
https://pub-d400c4fab9ed43a4b869b5bd85b09934.r2.dev/xclean/releases/latest/download/xclean-macos-arm64.tar.gz
https://pub-d400c4fab9ed43a4b869b5bd85b09934.r2.dev/xclean/releases/latest/download/xclean-macos-x86_64.tar.gz
https://pub-d400c4fab9ed43a4b869b5bd85b09934.r2.dev/xclean/releases/download/v0.1.7/xclean-macos-arm64.tar.gz
https://pub-d400c4fab9ed43a4b869b5bd85b09934.r2.dev/xclean/releases/download/v0.1.7/xclean-macos-x86_64.tar.gz
https://pub-d400c4fab9ed43a4b869b5bd85b09934.r2.dev/xclean/releases/download/v0.1.7/sha256sums.txt
```

The manual helper upload command writes these object keys automatically:

```bash
bash scripts/upload-r2.sh 0.1.7
```

If you later move the installer again, do this:

1. Host `install.sh` at a stable URL.
2. Set `XCLEAN_RELEASE_BASE_URL` in that hosted script to your real release base URL.
3. Upload prebuilt archives named `xclean-macos-arm64.tar.gz` and `xclean-macos-x86_64.tar.gz`.
4. Optionally keep `XCLEAN_REPO_URL` and `XCLEAN_INSTALL_REF` for source-build fallback.
5. If you want to pin installs to a tag, set `XCLEAN_INSTALL_VERSION=v0.1.7`.
