import Foundation

/// Candidate duplicate files grouped by exact file size.
///
/// This is an early, non-destructive candidate model. Files in a group are not
/// confirmed duplicates until future hash-based checks are implemented.
struct DuplicateGroup: Identifiable, Equatable, Codable {
    var id: Int64 { size }

    let size: Int64
    let files: [ScannedFile]

    var fileCount: Int {
        files.count
    }

    var estimatedReclaimableSize: Int64 {
        Int64(max(0, fileCount - 1)) * size
    }
}
