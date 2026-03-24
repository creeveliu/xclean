# R2 Installer Link Design

## Goal

Move the public `curl | bash` entrypoint from GitHub Raw to a single R2-hosted URL so users only see one installation link, while keeping the existing GitHub release flow intact.

## Constraints

- Do not change the existing GitHub release workflow or asset names.
- Keep `install.sh` compatible with existing version pinning via `XCLEAN_INSTALL_VERSION`.
- Preserve a fallback path if the R2 mirror is missing or temporarily unavailable.
- Keep the public install instructions simple and identical across docs.

## Design

- Host `install.sh` at `https://pub-d400c4fab9ed43a4b869b5bd85b09934.r2.dev/xclean/install.sh`.
- Mirror release assets under `https://pub-d400c4fab9ed43a4b869b5bd85b09934.r2.dev/xclean/releases`.
- Keep the mirror object keys compatible with the existing GitHub Releases URL layout:
  - `xclean/releases/latest/download/xclean-macos-arm64.tar.gz`
  - `xclean/releases/latest/download/xclean-macos-x86_64.tar.gz`
  - `xclean/releases/download/v0.1.4/xclean-macos-arm64.tar.gz`
  - `xclean/releases/download/v0.1.4/xclean-macos-x86_64.tar.gz`
  - `xclean/releases/download/v0.1.4/sha256sums.txt`
- Change `install.sh` so its default release base URL points at the R2 mirror.
- If the mirror download fails, retry once against GitHub Releases before falling back to source build.
- Update both READMEs so every public install example uses the R2-hosted `install.sh`.

## Verification

- `bash -n install.sh`
- `swift test`
- `swift run xclean --help`
- `swift run xclean --version`
