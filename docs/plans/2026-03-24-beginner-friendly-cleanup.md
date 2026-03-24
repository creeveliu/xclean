# Beginner-Friendly Cleanup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rework `xclean` interactive cleanup so non-expert users choose from user-friendly cleanup tiers with bilingual prompts instead of raw technical categories.

**Architecture:** Keep scanning and deletion behavior unchanged, but introduce a user-facing cleanup tier model and a lightweight localization layer. Drive `TerminalUI` from localized tier groupings and localized rule copy while preserving safety checks and rule titles.

**Tech Stack:** SwiftPM, Swift Foundation, XCTest

---

### Task 1: Add cleanup tiers to the core model

**Files:**
- Modify: `Sources/XCleanCore/Models.swift`
- Test: `Tests/XCleanCoreTests/RuleDefinitionTests.swift`

**Step 1: Write the failing test**

Add assertions in `Tests/XCleanCoreTests/RuleDefinitionTests.swift` verifying:

- `DerivedData`, `UserData/Previews`, and `simctl-unavailable` map to the safe tier
- `DocumentationCache`, device support, and logs map to the clean-if-needed tier
- `CoreSimulator/Devices` maps to the careful tier

**Step 2: Run test to verify it fails**

Run: `swift test --filter RuleDefinitionTests`
Expected: FAIL because no cleanup tier model exists yet

**Step 3: Write minimal implementation**

In `Sources/XCleanCore/Models.swift`:

- add a `CleanupTier` enum for `safe`, `cleanIfNeeded`, and `careful`
- add a `tier` property to `CleanupRule`
- populate each default rule with the approved tier assignment

**Step 4: Run test to verify it passes**

Run: `swift test --filter RuleDefinitionTests`
Expected: PASS

**Step 5: Commit**

```bash
git add /Users/cl/Projects/xclean/Sources/XCleanCore/Models.swift /Users/cl/Projects/xclean/Tests/XCleanCoreTests/RuleDefinitionTests.swift
git commit -m "feat: add user-facing cleanup tiers"
```

### Task 2: Add lightweight language detection and shared localized strings

**Files:**
- Create: `Sources/XCleanCore/Localization.swift`
- Test: `Tests/XCleanCoreTests/LocalizationTests.swift`

**Step 1: Write the failing test**

Create `Tests/XCleanCoreTests/LocalizationTests.swift` covering:

- `zh-Hans`, `zh-CN`, and `zh` resolve to Chinese
- `en-US` and unknown values fall back to English
- tier titles and shared UI labels return the expected localized strings

**Step 2: Run test to verify it fails**

Run: `swift test --filter LocalizationTests`
Expected: FAIL because localization types do not exist

**Step 3: Write minimal implementation**

Create `Sources/XCleanCore/Localization.swift` with:

- a small `AppLanguage` enum for `english` and `simplifiedChinese`
- language detection from preferred identifiers
- centralized localized UI strings for tier names, tier descriptions, prompts, confirmations, and headings

**Step 4: Run test to verify it passes**

Run: `swift test --filter LocalizationTests`
Expected: PASS

**Step 5: Commit**

```bash
git add /Users/cl/Projects/xclean/Sources/XCleanCore/Localization.swift /Users/cl/Projects/xclean/Tests/XCleanCoreTests/LocalizationTests.swift
git commit -m "feat: add lightweight cli localization"
```

### Task 3: Add localized decision-oriented rule copy

**Files:**
- Modify: `Sources/XCleanCore/Models.swift`
- Test: `Tests/XCleanCoreTests/RuleDefinitionTests.swift`

**Step 1: Write the failing test**

Extend `Tests/XCleanCoreTests/RuleDefinitionTests.swift` to assert each representative rule can provide:

- localized "what it is" text
- localized "after deletion" text
- localized "when to clean" text

Use at least one English and one Chinese expectation for `DerivedData` and `CoreSimulator/Devices`.

**Step 2: Run test to verify it fails**

Run: `swift test --filter RuleDefinitionTests`
Expected: FAIL because the rule model does not expose localized decision copy

**Step 3: Write minimal implementation**

In `Sources/XCleanCore/Models.swift`:

- add localized presentation helpers on `CleanupRule`
- keep rule titles unchanged
- provide the approved decision-oriented copy for all default rules in English and Chinese

**Step 4: Run test to verify it passes**

Run: `swift test --filter RuleDefinitionTests`
Expected: PASS

**Step 5: Commit**

```bash
git add /Users/cl/Projects/xclean/Sources/XCleanCore/Models.swift /Users/cl/Projects/xclean/Tests/XCleanCoreTests/RuleDefinitionTests.swift
git commit -m "feat: add localized cleanup guidance"
```

### Task 4: Rework terminal menus around cleanup tiers

**Files:**
- Modify: `Sources/XCleanCore/TerminalUI.swift`
- Modify: `Sources/XCleanCore/CLI.swift`
- Test: `Tests/XCleanCoreTests/TerminalUITests.swift`

**Step 1: Write the failing test**

Create `Tests/XCleanCoreTests/TerminalUITests.swift` to validate:

- the top-level menu groups items by cleanup tier
- tier headers render localized tier names and descriptions
- item rendering shows localized decision copy instead of raw recommendation labels
- confirmation output includes localized impact text

Prefer extracting pure rendering helpers from `TerminalUI` so tests can assert generated strings without mocking stdin.

**Step 2: Run test to verify it fails**

Run: `swift test --filter TerminalUITests`
Expected: FAIL because the UI still renders technical categories and English-only prompts

**Step 3: Write minimal implementation**

In `Sources/XCleanCore/TerminalUI.swift`:

- inject or derive the current app language
- replace the category-first menu with a tier-first menu
- render localized tier descriptions
- render each item with localized decision-oriented sections
- change deletion confirmation and result headings to localized strings

In `Sources/XCleanCore/CLI.swift`:

- construct `TerminalUI` with the resolved language, or allow `TerminalUI` to resolve it internally in a testable way

**Step 4: Run test to verify it passes**

Run: `swift test --filter TerminalUITests`
Expected: PASS

**Step 5: Commit**

```bash
git add /Users/cl/Projects/xclean/Sources/XCleanCore/TerminalUI.swift /Users/cl/Projects/xclean/Sources/XCleanCore/CLI.swift /Users/cl/Projects/xclean/Tests/XCleanCoreTests/TerminalUITests.swift
git commit -m "feat: add tier-based localized cleanup flow"
```

### Task 5: Update documentation to match the new behavior

**Files:**
- Modify: `README.md`

**Step 1: Write the failing check**

Manually inspect `README.md` and note that it does not describe:

- tier-based cleanup flow
- bilingual prompts
- the distinction between safe, clean-if-needed, and careful cleanup

**Step 2: Run check to verify mismatch**

Run: `rg -n "Safe Cleanup|Clean If Needed|Careful Cleanup|安全清理|按需清理|谨慎清理" README.md`
Expected: no matches

**Step 3: Write minimal implementation**

Update `README.md` to explain:

- the new tiered interactive experience
- that prompts display in English or Simplified Chinese based on system language
- that `CoreSimulator/Devices` appears under careful cleanup because it may remove simulator-local app data

**Step 4: Run check to verify it passes**

Run: `rg -n "Safe Cleanup|Clean If Needed|Careful Cleanup|安全清理|按需清理|谨慎清理" README.md`
Expected: matches present

**Step 5: Commit**

```bash
git add /Users/cl/Projects/xclean/README.md
git commit -m "docs: describe tiered localized cleanup flow"
```

### Task 6: Run project verification

**Files:**
- Modify: none

**Step 1: Run full test suite**

Run: `swift test`
Expected: PASS

**Step 2: Verify CLI help**

Run: `swift run xclean --help`
Expected: PASS and usage text prints successfully

**Step 3: Verify CLI version**

Run: `swift run xclean --version`
Expected: PASS and current version prints successfully

**Step 4: Review diffs**

Run: `git diff -- Sources/XCleanCore README.md Tests/XCleanCoreTests`
Expected: only intended tiering/localization/documentation changes

**Step 5: Commit**

```bash
git add /Users/cl/Projects/xclean/Sources/XCleanCore /Users/cl/Projects/xclean/Tests/XCleanCoreTests /Users/cl/Projects/xclean/README.md
git commit -m "feat: make cleanup flow beginner friendly"
```
