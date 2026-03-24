# Beginner-Friendly Cleanup Design

**Date:** 2026-03-24

**Goal:** Make `xclean` understandable for non-expert users by shifting the interactive cleanup flow from technical directory categories to decision-oriented cleanup tiers, while adding lightweight bilingual prompts.

## Problem

The current CLI exposes Xcode-specific names such as `DerivedData`, `DeviceSupport`, and `CoreSimulator/Devices` as the primary decision surface. Even though each item already has a technical description and a recommendation label, the interface still assumes the user understands what these directories do.

That creates two usability issues:

1. Users must understand Xcode internals before they can decide what to delete.
2. The current prompts are English-only, which increases friction for users whose system language is Chinese.

## Product Direction

The default interactive flow should help users answer a practical question:

"Can I delete this safely, and what happens if I do?"

Instead of leading with engineering-oriented categories, the CLI should lead with cleanup tiers based on user impact:

- `Safe Cleanup`
- `Clean If Needed`
- `Careful Cleanup`

For Chinese systems, the same tiers should appear as:

- `安全清理`
- `按需清理`
- `谨慎清理`

## Tier Definitions

### Safe Cleanup

Use this tier for items that are primarily disposable caches or cleanup operations whose effects are straightforward and temporary.

Rules in this tier:

- `DerivedData`
- `UserData/Previews`
- `Unavailable Simulators`

User meaning:

- deleting them does not affect project source files
- the data will be regenerated later if needed
- this is the best first stop for most users

### Clean If Needed

Use this tier for items that are still generally deletable, but may trigger downloads, rebuilds, or setup work the next time a related feature is used.

Rules in this tier:

- `DocumentationCache`
- `iOS DeviceSupport`
- `tvOS DeviceSupport`
- `Xcode Logs`
- `CoreSimulator Logs`

User meaning:

- safe in most cases
- not always worth deleting unless the user wants to reclaim space
- should explain that some related tools or devices may take time to prepare again later

### Careful Cleanup

Use this tier for items that are valid cleanup targets but require the user to decide whether the stored environment still matters.

Rules in this tier:

- `CoreSimulator/Devices`

User meaning:

- this can remove simulator environments and local simulator app data
- still allowed and useful
- should not be presented as forbidden or hidden
- should be separated from the default "easy wins" so users choose it deliberately

## Content Strategy

Each cleanup item should be presented with decision-oriented copy, not just technical metadata.

Each localized rule description should cover:

- what it is
- what happens after deletion
- when it makes sense to clean it

Example structure:

- `What it is`
- `After deletion`
- `When to clean`

The rule's technical title should remain unchanged, so the output still maps clearly to real Xcode paths and terminology.

## Localization Strategy

Use lightweight in-process localization instead of introducing a heavy resource system.

Initial language support:

- English
- Simplified Chinese

Behavior:

- inspect the user's preferred language at runtime
- if the preferred language starts with `zh`, use Simplified Chinese prompts
- otherwise default to English

Scope of localization:

- menu titles
- menu descriptions
- prompts
- confirmation text
- action result headings
- decision-oriented rule copy

Non-localized elements:

- technical rule titles such as `DerivedData`
- actual filesystem paths
- command names

## Interaction Changes

The main interactive screen should present cleanup tiers first, not technical categories.

Suggested flow:

1. Show tier list with total reclaimable size and actionable item count.
2. Let the user choose a tier.
3. Within a tier, list the concrete cleanup items with localized decision-oriented copy.
4. Let the user select specific items or choose all actionable items within that tier.
5. Before deletion, show a localized confirmation summary emphasizing impact rather than raw path names alone.

The scan-only output may continue to show technical categories for now unless the implementation cost to align both outputs stays low.

## Model and Architecture Changes

The existing architecture can be preserved with focused extensions.

Expected changes:

- keep technical rule categories in `Models.swift` for internal organization if needed
- add a user-facing cleanup tier concept separate from the existing technical category
- add a lightweight localization layer to centralize UI strings
- enrich rule metadata so the UI can render localized, decision-oriented explanations
- update `TerminalUI.swift` to drive menus by cleanup tier instead of technical category

## Safety Constraints

This design does not change the existing product safety boundaries.

The implementation must preserve:

- cleanup only under the current user's home directory
- opt-in deletion only
- explicit confirmation before deletion
- graceful handling of missing paths
- partial failures not blocking other deletions

`CoreSimulator/Devices` remains opt-in and visible, but isolated in `Careful Cleanup` / `谨慎清理`.

## Testing Expectations

Add or update tests to cover:

- tier assignment for default rules
- language selection fallback behavior
- localized string output for English and Chinese
- interactive rendering logic where feasible through focused unit tests

Minimum verification before claiming completion:

- `swift test`
- `swift run xclean --help`
- `swift run xclean --version`

