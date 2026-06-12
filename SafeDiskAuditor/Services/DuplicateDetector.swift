import Foundation

/// Finds duplicate candidates using exact file size only.
///
/// This service intentionally does not compute partial hashes, full hashes, or
/// perform any destructive cleanup action.
struct DuplicateDetector {
    func candidateGroups(from files: [ScannedFile]) -> [DuplicateGroup] {
        Dictionary(grouping: files.filter { $0.size > 0 }, by: \.size)
            .compactMap { size, files in
                guard files.count > 1 else {
                    return nil
                }

                return DuplicateGroup(
                    size: size,
                    files: files.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
                )
            }
            .sorted { lhs, rhs in
                if lhs.size == rhs.size {
                    return (lhs.files.first?.path ?? "") < (rhs.files.first?.path ?? "")
                }

                return lhs.size > rhs.size
            }
    }
}
