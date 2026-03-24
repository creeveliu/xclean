# xclean

`xclean` is a lightweight macOS Swift CLI for interactively cleaning common Xcode junk files.

## Install

Remote install:

```bash
curl -fsSL https://raw.githubusercontent.com/creeveliu/xclean/main/install.sh | bash
```

Pin to a specific release:

```bash
curl -fsSL https://raw.githubusercontent.com/creeveliu/xclean/main/install.sh | \
  XCLEAN_INSTALL_VERSION=v0.1.1 bash
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
XCLEAN_RELEASE_BASE_URL=https://github.com/creeveliu/xclean/releases \
XCLEAN_INSTALL_VERSION=latest \
XCLEAN_REPO_URL=https://github.com/creeveliu/xclean.git \
XCLEAN_INSTALL_REF=main \
XCLEAN_INSTALL_DIR="$HOME/.local/bin" \
curl -fsSL https://raw.githubusercontent.com/creeveliu/xclean/main/install.sh | bash
```

## Usage

```bash
xclean
xclean clean
xclean scan
xclean --version
```

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

## Publishing `curl | bash`

Current public installer:

```bash
curl -fsSL https://raw.githubusercontent.com/creeveliu/xclean/main/install.sh | bash
```

Current release page:

```text
https://github.com/creeveliu/xclean/releases
```

If you later move the installer to your own domain, do this:

1. Host `install.sh` at a stable URL.
2. Set `XCLEAN_RELEASE_BASE_URL` in that hosted script to your real release base URL.
3. Upload prebuilt archives named `xclean-macos-arm64.tar.gz` and `xclean-macos-x86_64.tar.gz`.
4. Optionally keep `XCLEAN_REPO_URL` and `XCLEAN_INSTALL_REF` for source-build fallback.
5. If you want to pin installs to a tag, set `XCLEAN_INSTALL_VERSION=v0.1.1`.
