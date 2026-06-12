# SafeDisk Auditor

SafeDisk Auditor is a native macOS SwiftUI application for safely finding and reviewing duplicate files.

The application is designed around safety-first cleanup:

- Scan user-selected folders
- Detect duplicate files using staged hashing
- Preview files before removal
- Reveal files in Finder
- Move selected files to Trash
- Keep audit logs

## MVP Scope

The first version focuses only on duplicate file detection and safe review.

It does not permanently delete files.
It does not clean system folders automatically.
It does not perform aggressive cache cleanup.

## Technology

- macOS
- SwiftUI
- AppKit where needed
- Quick Look preview
- GitHub Actions for CI builds
