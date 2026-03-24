# R2 Installer Link Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Switch the public installation entrypoint to a single R2 URL without changing the existing GitHub release process.

**Architecture:** The installer will default to the R2 mirror for release asset downloads and retry against GitHub Releases if the mirror fails. Documentation will expose only the R2-hosted installer URL.

**Tech Stack:** Bash, SwiftPM docs, existing release asset naming

---

### Task 1: Update installer defaults

**Files:**
- Modify: `install.sh`

**Step 1: Write the failing test**

Run a shell assertion that expects the R2 base URL to already be present in `install.sh`.

**Step 2: Run test to verify it fails**

Run: `test -n "$(rg -n 'pub-d400c4fab9ed43a4b869b5bd85b09934\\.r2\\.dev/xclean/releases' install.sh)"`
Expected: fail because the script still defaults to GitHub Releases.

**Step 3: Write minimal implementation**

Set the default `XCLEAN_RELEASE_BASE_URL` to the R2 mirror and add a retry against GitHub Releases when prebuilt mirror downloads fail.

**Step 4: Run test to verify it passes**

Run: `rg -n 'pub-d400c4fab9ed43a4b869b5bd85b09934\\.r2\\.dev/xclean/releases|github.com/creeveliu/xclean/releases' install.sh`
Expected: R2 default present and GitHub Releases fallback still present.

### Task 2: Update public installation docs

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`

**Step 1: Write the failing test**

Run a shell assertion that expects the R2 installer URL to be the documented public install command.

**Step 2: Run test to verify it fails**

Run: `test -n "$(rg -n 'pub-d400c4fab9ed43a4b869b5bd85b09934\\.r2\\.dev/xclean/install\\.sh' README.md README.zh-CN.md)"`
Expected: fail because both READMEs still point to GitHub Raw.

**Step 3: Write minimal implementation**

Replace public install examples with the R2 URL and document the R2 mirror layout used for release assets.

**Step 4: Run test to verify it passes**

Run: `test -z "$(rg -n 'raw\\.githubusercontent\\.com/creeveliu/xclean/main/install\\.sh' README.md README.zh-CN.md)"`
Expected: pass because the public install command no longer uses GitHub Raw.

### Task 3: Verify behavior

**Files:**
- Modify: `install.sh`
- Modify: `README.md`
- Modify: `README.zh-CN.md`

**Step 1: Validate shell syntax**

Run: `bash -n install.sh`
Expected: success with no output.

**Step 2: Run package tests**

Run: `swift test`
Expected: all tests pass.

**Step 3: Verify CLI help**

Run: `swift run xclean --help`
Expected: usage output is shown.

**Step 4: Verify CLI version**

Run: `swift run xclean --version`
Expected: `0.1.4`
