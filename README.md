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

## Current MVP Progress

This repository currently contains the initial macOS SwiftUI app scaffold for `SafeDiskAuditor`:

- Xcode project and shared scheme
- SwiftUI app entry point
- Sidebar navigation for Scan, Duplicates, and Settings
- Folder selection from the Scan screen
- Recursive file metadata scanning for user-selected folders
- Hidden file and package-content skipping by default
- Initial app/view model/service separation
- Basic unit test target

No deletion, trash, cleaner, or duplicate detection features are implemented yet.

## Build and Test

Open `SafeDiskAuditor.xcodeproj` in Xcode, or run the following from the repository root on macOS with Xcode installed:

```sh
xcodebuild -project SafeDiskAuditor.xcodeproj -scheme SafeDiskAuditor -destination 'platform=macOS' build
xcodebuild -project SafeDiskAuditor.xcodeproj -scheme SafeDiskAuditor -destination 'platform=macOS' test
```

## Technology

- macOS 14+
- Swift
- SwiftUI
- AppKit where needed in future features
- Quick Look preview planned for future review workflows
- GitHub Actions planned for CI builds
