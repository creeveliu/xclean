# Simulator Device Selection Design

## Summary

Change `xclean` so that the `CoreSimulator/Devices` cleanup flow no longer deletes the entire directory at once.
When the user selects that cleanup target, `xclean` should enumerate individual simulator device subdirectories, show device-friendly labels, and let the user delete selected devices only.

## Problem

The current careful cleanup confirmation for `CoreSimulator/Devices` is too coarse.
It asks the user to delete the whole simulator device store, which increases the chance of wiping every simulator environment and all simulator-local app data in one action.

This is especially risky for users who only want to free space from old or unused simulator devices while keeping one or two actively used environments.

## Goals

- Replace whole-directory deletion of `CoreSimulator/Devices` with per-device selection.
- Show device entries using human-readable metadata instead of raw UUID directory names.
- Keep deletion opt-in and explicit.
- Preserve the current safety rule that only known Xcode-related paths under the user's home directory can be removed.
- Give the user a clear recommendation to keep at least one commonly used simulator.
- Skip devices that cannot be mapped safely from simulator metadata to on-disk directories.

## Non-Goals

- Do not auto-select devices for deletion.
- Do not delete the `CoreSimulator/Devices` root directory itself.
- Do not add archive, signing, or non-simulator cleanup targets.
- Do not attempt fuzzy matching between device metadata and directories.

## User Experience

### Current behavior

When the user selects the careful cleanup tier and confirms `CoreSimulator/Devices`, the confirmation screen lists the root directory and then deletes the entire folder.

### New behavior

When the user selects `CoreSimulator/Devices`, `xclean` should:

1. Inspect child directories under `~/Library/Developer/CoreSimulator/Devices`.
2. Load simulator metadata from `xcrun simctl list devices --json`.
3. Build a list of removable device entries only when a device can be matched safely by UDID to a real subdirectory.
4. Present each removable entry with:
   - device name
   - runtime name or identifier
   - directory size
   - full path
   - a "recommended to keep" hint for one commonly used device
5. Let the user choose one or more device entries.
6. Confirm deletion using the selected device entries, not the root directory.

If some devices or directories cannot be mapped safely, `xclean` should tell the user those entries were skipped and are not part of the delete list.

If no device entries can be mapped safely, `xclean` should treat the item as non-actionable for device-level deletion and explain why.

## Recommendation Behavior

`xclean` should visibly advise the user to keep one commonly used simulator.

For the first version, the recommendation can be conservative and deterministic:

- mark one recognized device entry as "recommended to keep"
- prefer the first recognized available device returned by the metadata scan
- if the metadata later exposes a reliable last-used signal, the selection logic can be upgraded without changing the interaction model

This keeps the guidance simple without pretending the tool knows the user's real favorite simulator.

## Data Model Changes

Add a dedicated model for simulator device cleanup candidates.
The model should include at least:

- stable identifier for selection
- device display name
- runtime display value
- UDID
- absolute path
- size in bytes
- recommendation flag

`ScannedItem` should gain optional nested candidates or equivalent structured detail so that scanner output can represent:

- a parent cleanup item for `CoreSimulator/Devices`
- zero or more child device candidates
- skipped-item messaging when safe mapping is incomplete

The structure should stay generic enough that other future "expandable careful cleanup" items could reuse it.

## Scanner Changes

The scanner should keep current behavior for all existing rules except `simulator-devices`.

For `simulator-devices`, scanning should:

1. Validate the root path with `PathSafetyValidator`.
2. Read immediate child directories under `CoreSimulator/Devices`.
3. Run `xcrun simctl list devices --json`.
4. Parse device metadata.
5. Match only directories whose names exactly equal a simulator UDID from metadata.
6. Compute directory size for each matched child directory.
7. Build candidate entries with human-readable labels.
8. Record a detail message when entries were skipped because they could not be mapped safely.

If `simctl` fails, the item should remain safe-by-default:

- do not fall back to deleting the whole root directory
- report the item as unavailable or non-actionable with a direct message

## Cleaner Changes

Deleting simulator device candidates should remove only the chosen child directories.

Requirements:

- never delete the `CoreSimulator/Devices` parent directory as part of this flow
- validate every selected child path with path safety rules
- process each selected device independently
- continue after per-item failures
- return per-device delete results so the results screen remains granular

The existing directory cleanup path for other rules should stay unchanged.

## Terminal UI Changes

The interactive flow should stay tier-based.
Only the `simulator-devices` item gets a deeper selection step.

Expected UI behavior:

- `Careful Cleanup` still lists `CoreSimulator/Devices` as a top-level item
- selecting that item opens a device selection view instead of immediate root-folder confirmation
- the device selection view shows device name, runtime, size, path, and keep recommendation
- the confirmation message lists selected devices and includes a plain warning to keep one common simulator if possible
- skipped/unrecognized devices are summarized in a non-fatal note

The wording should remain plain and localized in English and Simplified Chinese.

## Safety Rules

The following rules remain mandatory:

- only delete paths under the current user's home directory
- only delete known Xcode-related simulator device subdirectories
- only delete directories matched exactly to simulator UDIDs
- do not treat missing subdirectories as fatal
- do not let one failed deletion stop the rest

## Testing Strategy

Add test coverage before implementation for:

- simulator device scanning produces device-level candidates
- scanner skips unmapped devices and reports that skip
- confirmation output lists device entries instead of the root directory
- recommended-to-keep guidance appears in the device-level UI
- deleting selected simulator devices removes only chosen child directories
- unmatched or unsafe paths are not deleted

Existing tests for non-simulator cleanup behavior should keep passing unchanged.
