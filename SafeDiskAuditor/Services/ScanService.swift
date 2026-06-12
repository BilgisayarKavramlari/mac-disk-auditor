import Foundation

/// Placeholder service for future scan orchestration.
///
/// Duplicate detection and deletion features are intentionally not implemented
/// in the initial app shell. Future scan logic should live in services like this
/// rather than in SwiftUI views.
struct ScanService {
    func statusMessage() -> String {
        "Ready to configure safe folder scanning."
    }
}
