import Foundation

struct FileScanProgress: Equatable {
    let scannedFileCount: Int
    let totalSize: Int64
    let currentPath: String?
}

struct FileScanResult: Equatable {
    let files: [ScannedFile]

    var totalSize: Int64 {
        files.reduce(0) { $0 + $1.size }
    }
}

/// Recursively scans user-selected folders and collects metadata for regular files.
///
/// Duplicate detection, deletion, trash, and cleaner behavior are intentionally
/// out of scope for this scanner.
struct FileScanner {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func scan(
        folders: [URL],
        progress: @escaping (FileScanProgress) -> Void = { _ in }
    ) async throws -> FileScanResult {
        let fileManager = self.fileManager
        let scanTask = Task.detached(priority: .userInitiated) {
            try scanSynchronously(folders: folders, fileManager: fileManager, progress: progress)
        }

        return try await withTaskCancellationHandler {
            try await scanTask.value
        } onCancel: {
            scanTask.cancel()
        }
    }
}

fileprivate extension FileScanner {
    static let resourceKeys: Set<URLResourceKey> = [
        .isRegularFileKey,
        .isHiddenKey,
        .isPackageKey,
        .fileSizeKey,
        .creationDateKey,
        .contentModificationDateKey
    ]
}

private func scanSynchronously(
    folders: [URL],
    fileManager: FileManager,
    progress: (FileScanProgress) -> Void
) throws -> FileScanResult {
    var files: [ScannedFile] = []
    var totalSize: Int64 = 0

    for folder in folders {
        try Task.checkCancellation()

        guard shouldScanFolder(folder) else {
            continue
        }

        guard let enumerator = fileManager.enumerator(
            at: folder,
            includingPropertiesForKeys: Array(FileScanner.resourceKeys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            continue
        }

        for case let fileURL as URL in enumerator {
            try Task.checkCancellation()

            guard let scannedFile = makeScannedFile(from: fileURL) else {
                continue
            }

            files.append(scannedFile)
            totalSize += scannedFile.size
            progress(
                FileScanProgress(
                    scannedFileCount: files.count,
                    totalSize: totalSize,
                    currentPath: scannedFile.path
                )
            )
        }
    }

    progress(
        FileScanProgress(
            scannedFileCount: files.count,
            totalSize: totalSize,
            currentPath: nil
        )
    )

    return FileScanResult(files: files)
}

private func shouldScanFolder(_ folderURL: URL) -> Bool {
    guard let values = try? folderURL.resourceValues(forKeys: [.isHiddenKey, .isPackageKey]) else {
        return true
    }

    return values.isHidden != true && values.isPackage != true
}

private func makeScannedFile(from fileURL: URL) -> ScannedFile? {
    guard let values = try? fileURL.resourceValues(forKeys: FileScanner.resourceKeys),
          values.isRegularFile == true,
          values.isHidden != true,
          values.isPackage != true
    else {
        return nil
    }

    return ScannedFile(
        fileURL: fileURL,
        filename: fileURL.lastPathComponent,
        path: fileURL.path,
        fileExtension: fileURL.pathExtension,
        size: Int64(values.fileSize ?? 0),
        creationDate: values.creationDate,
        modificationDate: values.contentModificationDate
    )
}
