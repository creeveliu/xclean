# AGENTS.md

## Project Summary

- Project name: `xclean`
- Type: SwiftPM executable for macOS
- Purpose: interactive cleanup of common Xcode junk files under the current user's home directory
- Entry point: `Sources/xclean/main.swift`
- Core module: `Sources/XCleanCore`

## Current CLI Commands

- `xclean`
- `xclean clean`
- `xclean scan`
- `xclean update`
- `xclean uninstall`
- `xclean --version`

## Current Version

- Source version is defined in `Sources/XCleanCore/CLI.swift`
- Latest released version at time of writing: `0.1.8`

## Architecture

Keep code split across these areas:

- Rule/category definitions: `Sources/XCleanCore/Models.swift`
- Scanner: `Sources/XCleanCore/Scanner.swift`
- Cleaner: `Sources/XCleanCore/Cleaner.swift`
- Terminal UI: `Sources/XCleanCore/TerminalUI.swift`
- Install/update/uninstall logic: `Sources/XCleanCore/Updater.swift`
- Process execution: `Sources/XCleanCore/ProcessRunner.swift`
- Path safety: `Sources/XCleanCore/PathSafety.swift`

## Safety Rules

- Only operate on Xcode-related paths under the current user's home directory
- Do not add cleanup targets outside user home
- Do not add archives, provisioning profiles, signing assets, or other destructive targets without explicit product decision
- Deletion must remain opt-in and explicitly confirmed
- Missing paths should not be treated as fatal errors
- Failure on one item must not stop processing of other items

## Install / Update / Uninstall Behavior

- Installer script: `install.sh`
- Public installer URL:
  `https://pub-d400c4fab9ed43a4b869b5bd85b09934.r2.dev/xclean/install.sh`
- Default install dir:
  `~/.local/bin`
- Installer behavior:
  - first tries to download prebuilt release assets from the R2 mirror
  - retries from GitHub Releases if the mirror download fails
  - falls back to source build if download fails
- `xclean update`:
  - reruns installer
  - preserves current install directory
- `xclean uninstall`:
  - removes the current binary
  - removes the install directory only if it becomes empty

## Release Assets

GitHub repo:

- `https://github.com/creeveliu/xclean`

GitHub releases page:

- `https://github.com/creeveliu/xclean/releases`

Expected release asset names:

- `xclean-macos-arm64.tar.gz`
- `xclean-macos-x86_64.tar.gz`
- `xclean-<version>-macos-arm64.tar.gz`
- `xclean-<version>-macos-x86_64.tar.gz`
- `sha256sums.txt`

Release packaging script:

- `scripts/build-release.sh`

Build command:

```bash
bash scripts/build-release.sh 0.1.8
```

## Testing and Verification

Minimum checks before claiming work is done:

```bash
swift test
swift run xclean --help
swift run xclean --version
```

For release-related changes, also verify:

```bash
bash -n install.sh
bash scripts/build-release.sh <version>
```

For installer smoke tests, prefer installing into a temporary directory instead of touching the real user install path.

## GitHub Release Notes

Automated tag release flow currently works and has been used for:

- `v0.1.0`
- `v0.1.1`
- `v0.1.2`
- `v0.1.3`
- `v0.1.4`
- `v0.1.7`
- `v0.1.8`

Current sequence:

1. Update version in `Sources/XCleanCore/CLI.swift`
2. Run tests
3. Commit and push `main`
4. Create git tag `v<version>` and push it
5. GitHub Actions creates the GitHub release
6. GitHub Actions builds and uploads release assets
7. GitHub Actions merges `sha256sums.txt`
8. GitHub Actions syncs installer assets to R2

Manual fallback commands:

```bash
bash scripts/build-release.sh <version>
bash scripts/upload-r2.sh <version>
```

## GitHub Actions Note

- A release workflow file exists at `.github/workflows/release.yml`
- The workflow now creates the GitHub release, uploads release assets, merges checksums, and syncs artifacts to R2 after a tag push
- Required repository secrets for R2 sync:
  - `CLOUDFLARE_API_TOKEN`
  - `CLOUDFLARE_ACCOUNT_ID`
  - `XCLEAN_R2_BUCKET`
- `gh` must have `workflow` scope before pushing workflow changes

Suggested command:

```bash
gh auth refresh -h github.com -s workflow
```

## Known Environment Issue

- Network access to GitHub can be intermittently affected by TLS handshake failures in this environment
- When release creation or installer smoke tests fail unexpectedly, first suspect transient GitHub connectivity before assuming a code regression

## Development Notes

- Keep dependencies zero-third-party
- Keep code ASCII-only unless there is a strong reason not to
- Keep terminal copy direct and plain
- Prefer small, test-backed changes
- When adding commands, update:
  - `Sources/XCleanCore/CLI.swift`
  - `README.md`
  - tests under `Tests/XCleanCoreTests`
