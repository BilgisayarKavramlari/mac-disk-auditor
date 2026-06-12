import Foundation

/// Metadata collected for a regular file discovered during a scan.
struct ScannedFile: Identifiable, Equatable {
    var id: String { path }

    let fileURL: URL
    let filename: String
    let path: String
    let fileExtension: String
    let size: Int64
    let creationDate: Date?
    let modificationDate: Date?
}
