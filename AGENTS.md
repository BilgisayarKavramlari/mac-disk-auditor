# SafeDisk Auditor – Codex Development Guide

## Product Goal

SafeDisk Auditor is a macOS-only SwiftUI + AppKit desktop application that helps users find duplicate files, review them safely, preview files before deletion, and move selected duplicates to Trash.

The application must prioritize safety, transparency, and user control. It must never permanently delete files in the MVP.

## Technology

- Language: Swift
- UI: SwiftUI
- macOS integration: AppKit where needed
- Preview: SwiftUI quickLookPreview or Quick Look integration
- Build system: Xcode project
- CI: GitHub Actions macOS runner
- Minimum macOS target: macOS 14 unless there is a strong reason to lower it

## Core Principles

1. Do not permanently delete files.
2. Move files only to Trash.
3. Always show what will be removed before removal.
4. Prefer selected folders over full disk scanning.
5. Avoid scanning system-critical paths by default.
6. Provide clear audit logs for scan and delete operations.
7. Write testable service classes.
8. Keep UI and scanning logic separated.
9. Use async scanning where appropriate.
10. Avoid blocking the main thread.

## MVP Features

- Select one or more folders to scan.
- Enumerate files recursively.
- Collect file path, filename, extension, size, modification date, creation date.
- Group candidate duplicates by file size.
- Compute partial hashes for files with same size.
- Compute full SHA-256 hash only for strong candidates.
- Display duplicate groups in SwiftUI.
- Show thumbnail or Quick Look preview for selected files.
- Reveal file in Finder.
- Open file with default app.
- Allow user to select duplicates manually.
- Provide a safe auto-select feature that never selects all files in a group.
- Move selected files to Trash.
- Write audit log.

## Duplicate Detection Rules

Use this staged approach:

1. Ignore directories, packages, hidden system paths, and zero-byte files unless explicitly enabled later.
2. Group files by size.
3. Discard groups with only one file.
4. For remaining files, compute partial hash:
   - first chunk
   - middle chunk
   - last chunk
5. For files with same size and same partial hash, compute full SHA-256.
6. Files with the same full SHA-256 are duplicates.

## Auto-select Safety Rules

Auto-select may suggest duplicate files for deletion, but must never delete automatically.

Rules:

- Never select all files in a duplicate group.
- Prefer keeping files in Documents, Desktop, Pictures, Movies, and user-selected protected folders.
- Prefer deleting files in Downloads, temporary folders, duplicated export folders, or files with names like "copy", "duplicate", "kopya", "(1)", "(2)".
- Prefer keeping the oldest original if no better signal exists.
- Always allow user override.

## Cleaner Module

Do not implement aggressive cleaner behavior in the first MVP.

Later cleaner rules should be implemented as an explicit rule engine with safe dry-run output first.

## Testing

Add unit tests for:

- File size grouping
- Partial hash consistency
- Full hash duplicate detection
- Auto-select never selecting all files in a group
- TrashService mock behavior where possible

## CI

GitHub Actions should build the macOS app on a macOS runner and upload the app or zipped artifact.

## Code Style

- Prefer small files and clear names.
- Avoid massive view files.
- Keep scanning logic in Services.
- Keep UI state in ViewModels.
- Do not introduce external dependencies unless necessary.
