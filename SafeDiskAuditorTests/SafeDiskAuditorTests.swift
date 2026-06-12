import XCTest
@testable import SafeDiskAuditor

final class SafeDiskAuditorTests: XCTestCase {
    @MainActor
    func testAppViewModelDefaultsToScanSection() {
        let viewModel = AppViewModel()

        XCTAssertEqual(viewModel.selectedSection, .scan)
    }

    func testFileScannerRecursivelyCollectsRegularFileMetadata() async throws {
        let root = try makeTemporaryDirectory()
        let nested = root.appendingPathComponent("Nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        let textFile = root.appendingPathComponent("report.txt")
        let nestedFile = nested.appendingPathComponent("image.jpeg")
        try Data("hello".utf8).write(to: textFile)
        try Data([0, 1, 2, 3]).write(to: nestedFile)

        let result = try await FileScanner().scan(folders: [root])
        let scannedPaths = Set(result.files.map(\.path))

        XCTAssertEqual(result.files.count, 2)
        XCTAssertEqual(result.totalSize, 9)
        XCTAssertTrue(scannedPaths.contains(textFile.path))
        XCTAssertTrue(scannedPaths.contains(nestedFile.path))

        let scannedTextFile = try XCTUnwrap(result.files.first { $0.path == textFile.path })
        XCTAssertEqual(scannedTextFile.fileURL, textFile)
        XCTAssertEqual(scannedTextFile.filename, "report.txt")
        XCTAssertEqual(scannedTextFile.fileExtension, "txt")
        XCTAssertEqual(scannedTextFile.size, 5)
        XCTAssertNotNil(scannedTextFile.creationDate)
        XCTAssertNotNil(scannedTextFile.modificationDate)
    }

    func testFileScannerSkipsHiddenFilesAndPackageContents() async throws {
        let root = try makeTemporaryDirectory()
        let visibleFile = root.appendingPathComponent("visible.md")
        let hiddenFile = root.appendingPathComponent(".hidden.md")
        let package = root.appendingPathComponent("Example.app", isDirectory: true)
        let packageFile = package.appendingPathComponent("Contents.txt")

        try Data("visible".utf8).write(to: visibleFile)
        try Data("hidden".utf8).write(to: hiddenFile)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        try Data("package".utf8).write(to: packageFile)

        let result = try await FileScanner().scan(folders: [root])
        let scannedPaths = Set(result.files.map(\.path))

        XCTAssertEqual(scannedPaths, [visibleFile.path])
    }

    func testFileScannerReportsProgress() async throws {
        let root = try makeTemporaryDirectory()
        let firstFile = root.appendingPathComponent("first.bin")
        let secondFile = root.appendingPathComponent("second.bin")
        try Data([1, 2]).write(to: firstFile)
        try Data([3, 4, 5]).write(to: secondFile)

        var progressEvents: [FileScanProgress] = []
        let result = try await FileScanner().scan(folders: [root]) { progress in
            progressEvents.append(progress)
        }

        XCTAssertEqual(result.files.count, 2)
        XCTAssertEqual(progressEvents.last, FileScanProgress(scannedFileCount: 2, totalSize: 5, currentPath: nil))
        XCTAssertTrue(progressEvents.contains { $0.scannedFileCount == 1 })
    }
}

private extension XCTestCase {
    func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }
}
