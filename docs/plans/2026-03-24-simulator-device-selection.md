# Simulator Device Selection Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace whole-folder deletion of `CoreSimulator/Devices` with device-level selection and deletion, while guiding users to keep one commonly used simulator.

**Architecture:** Extend the scan model so `simulator-devices` can expose nested per-device candidates derived from `simctl` metadata and matched device directories. Keep terminal interaction tier-based, but add a second selection step for simulator devices that confirms and deletes only selected child directories. Preserve existing path safety and per-item failure isolation.

**Tech Stack:** Swift 6.1, SwiftPM, Foundation, XCTest

---

### Task 1: Add failing scanner tests for simulator device candidates

**Files:**
- Modify: `/Users/cl/Projects/xclean/Tests/XCleanCoreTests/ScannerAggregationTests.swift`
- Modify: `/Users/cl/Projects/xclean/Tests/XCleanCoreTests/MockProcessRunner.swift`

**Step 1: Write the failing test**

Add tests that create a temporary `CoreSimulator/Devices` directory with two UDID subfolders and one unmapped subfolder, then assert that scanning:
- returns device-level candidates for the mapped UDIDs
- includes display metadata from `simctl list devices --json`
- marks exactly one candidate as recommended to keep
- reports skipped entries for unmapped directories

**Step 2: Run test to verify it fails**

Run: `swift test --filter ScannerAggregationTests`
Expected: FAIL because `ScannedItem` and scanner logic do not yet expose simulator device candidates.

**Step 3: Write minimal implementation**

Do not implement yet. Stop after confirming the red state.

**Step 4: Run test to verify it still fails for the expected reason**

Run: `swift test --filter ScannerAggregationTests`
Expected: FAIL with missing model members or unmet assertions about simulator candidate output.

**Step 5: Commit**

```bash
git add /Users/cl/Projects/xclean/Tests/XCleanCoreTests/ScannerAggregationTests.swift /Users/cl/Projects/xclean/Tests/XCleanCoreTests/MockProcessRunner.swift
git commit -m "test: cover simulator device candidate scanning"
```

### Task 2: Implement simulator device scan models and scanner support

**Files:**
- Modify: `/Users/cl/Projects/xclean/Sources/XCleanCore/Models.swift`
- Modify: `/Users/cl/Projects/xclean/Sources/XCleanCore/Scanner.swift`

**Step 1: Write the failing test**

Use the scanner tests from Task 1 as the active failing tests.

**Step 2: Run test to verify it fails**

Run: `swift test --filter ScannerAggregationTests`
Expected: FAIL before implementation.

**Step 3: Write minimal implementation**

Implement:
- a reusable nested candidate model for expandable scanned items
- simulator-device-specific candidate fields: device name, runtime, UDID, path, size, keep recommendation
- JSON parsing for `xcrun simctl list devices --json`
- exact UDID-to-directory matching for child folders under `CoreSimulator/Devices`
- skipped-entry detail reporting
- safe behavior when `simctl` fails or no candidates can be safely mapped

Keep all non-simulator rules unchanged.

**Step 4: Run test to verify it passes**

Run: `swift test --filter ScannerAggregationTests`
Expected: PASS

**Step 5: Commit**

```bash
git add /Users/cl/Projects/xclean/Sources/XCleanCore/Models.swift /Users/cl/Projects/xclean/Sources/XCleanCore/Scanner.swift
git commit -m "feat: scan simulator devices individually"
```

### Task 3: Add failing cleaner tests for deleting selected simulator subdirectories only

**Files:**
- Modify: `/Users/cl/Projects/xclean/Tests/XCleanCoreTests/CleanerTests.swift`

**Step 1: Write the failing test**

Add tests that:
- create a `CoreSimulator/Devices` root with multiple child directories
- select one device candidate for deletion
- assert that only the selected child directory is removed
- assert that the root directory and unselected child directories remain

Also add a test that unsafe or unmapped device paths are rejected.

**Step 2: Run test to verify it fails**

Run: `swift test --filter CleanerTests`
Expected: FAIL because cleaner currently only deletes whole rule paths.

**Step 3: Write minimal implementation**

Do not implement yet. Stop after confirming the red state.

**Step 4: Run test to verify it still fails for the expected reason**

Run: `swift test --filter CleanerTests`
Expected: FAIL with assertions showing simulator child deletion is unsupported.

**Step 5: Commit**

```bash
git add /Users/cl/Projects/xclean/Tests/XCleanCoreTests/CleanerTests.swift
git commit -m "test: cover simulator subdirectory deletion"
```

### Task 4: Implement device-level simulator deletion

**Files:**
- Modify: `/Users/cl/Projects/xclean/Sources/XCleanCore/Cleaner.swift`
- Modify: `/Users/cl/Projects/xclean/Sources/XCleanCore/Models.swift`

**Step 1: Write the failing test**

Use the cleaner tests from Task 3 as the active failing tests.

**Step 2: Run test to verify it fails**

Run: `swift test --filter CleanerTests`
Expected: FAIL before implementation.

**Step 3: Write minimal implementation**

Implement deletion support for selected simulator device candidates:
- represent selected candidate paths in the delete request
- validate each selected child path with `PathSafetyValidator`
- remove only chosen child directories
- keep independent per-item result reporting

Leave non-simulator delete behavior unchanged.

**Step 4: Run test to verify it passes**

Run: `swift test --filter CleanerTests`
Expected: PASS

**Step 5: Commit**

```bash
git add /Users/cl/Projects/xclean/Sources/XCleanCore/Cleaner.swift /Users/cl/Projects/xclean/Sources/XCleanCore/Models.swift
git commit -m "feat: delete selected simulator devices only"
```

### Task 5: Add failing UI tests for simulator device selection flow

**Files:**
- Modify: `/Users/cl/Projects/xclean/Tests/XCleanCoreTests/TerminalUITests.swift`

**Step 1: Write the failing test**

Add tests that assert:
- `CoreSimulator/Devices` opens a device-level selection flow
- the output shows device name, runtime, size, and path
- one entry is labeled with a keep recommendation
- the confirmation message warns users to keep one common simulator
- the results output reflects selected device deletions, not root directory deletion

**Step 2: Run test to verify it fails**

Run: `swift test --filter TerminalUITests`
Expected: FAIL because the UI currently treats `simulator-devices` like any normal rule item.

**Step 3: Write minimal implementation**

Do not implement yet. Stop after confirming the red state.

**Step 4: Run test to verify it still fails for the expected reason**

Run: `swift test --filter TerminalUITests`
Expected: FAIL with missing device-level interaction and output.

**Step 5: Commit**

```bash
git add /Users/cl/Projects/xclean/Tests/XCleanCoreTests/TerminalUITests.swift
git commit -m "test: cover simulator device selection ui"
```

### Task 6: Implement simulator device selection UI and localized copy

**Files:**
- Modify: `/Users/cl/Projects/xclean/Sources/XCleanCore/TerminalUI.swift`
- Modify: `/Users/cl/Projects/xclean/Sources/XCleanCore/Localization.swift`
- Modify: `/Users/cl/Projects/xclean/Sources/XCleanCore/Models.swift`

**Step 1: Write the failing test**

Use the UI tests from Task 5 as the active failing tests.

**Step 2: Run test to verify it fails**

Run: `swift test --filter TerminalUITests`
Expected: FAIL before implementation.

**Step 3: Write minimal implementation**

Implement:
- a simulator device detail view under the existing careful tier flow
- indexed selection of device candidates
- localized keep recommendation text
- localized skipped-entry note
- confirmation output based on selected simulator devices
- a plain warning advising users to keep one commonly used simulator

Keep existing interactions for other rules untouched.

**Step 4: Run test to verify it passes**

Run: `swift test --filter TerminalUITests`
Expected: PASS

**Step 5: Commit**

```bash
git add /Users/cl/Projects/xclean/Sources/XCleanCore/TerminalUI.swift /Users/cl/Projects/xclean/Sources/XCleanCore/Localization.swift /Users/cl/Projects/xclean/Sources/XCleanCore/Models.swift
git commit -m "feat: add simulator device selection flow"
```

### Task 7: Update docs for the new careful cleanup behavior

**Files:**
- Modify: `/Users/cl/Projects/xclean/README.md`
- Modify: `/Users/cl/Projects/xclean/README.zh-CN.md`

**Step 1: Write the failing test**

No automated doc test is required. Use an explicit content checklist instead:
- README no longer implies deleting the entire `CoreSimulator/Devices` folder in one step
- README explains device-level selection and keep-one recommendation

**Step 2: Run test to verify it fails**

Manually inspect current docs and confirm they still describe the old broad behavior.

**Step 3: Write minimal implementation**

Update both READMEs so the careful cleanup section explains:
- simulator devices are shown individually
- users can remove selected simulator folders only
- it is recommended to keep one commonly used simulator

**Step 4: Run test to verify it passes**

Manually inspect the edited docs for consistency with the implemented behavior.

**Step 5: Commit**

```bash
git add /Users/cl/Projects/xclean/README.md /Users/cl/Projects/xclean/README.zh-CN.md
git commit -m "docs: describe simulator device selection cleanup"
```

### Task 8: Run full verification

**Files:**
- Modify: none

**Step 1: Run the required test suite**

Run: `swift test`
Expected: PASS

**Step 2: Run CLI verification**

Run: `swift run xclean --help`
Expected: PASS and usage text prints successfully

Run: `swift run xclean --version`
Expected: PASS and prints `0.1.4`

**Step 3: Spot check the new flow manually**

Run: `swift run xclean`
Expected: interactive output shows the simulator device selection flow when `CoreSimulator/Devices` is chosen and does not propose deleting the parent folder directly.

**Step 4: Review diff**

Run: `git diff --stat`
Expected: only the planned implementation and documentation files changed.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: make simulator cleanup device-selectable"
```
