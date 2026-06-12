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

        try Data("visible".utf8).write(to: visibleFile)
        try Data("hidden".utf8).write(to: hiddenFile)
        try makeMinimalAppBundle(at: package)

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

    func testDuplicateDetectorGroupsSameSizeFiles() {
        let first = makeScannedFile(path: "/tmp/a.txt", size: 12)
        let second = makeScannedFile(path: "/tmp/b.txt", size: 12)
        let unique = makeScannedFile(path: "/tmp/c.txt", size: 20)

        let groups = DuplicateDetector().candidateGroups(from: [first, second, unique])

        XCTAssertEqual(groups, [DuplicateGroup(size: 12, files: [first, second])])
    }

    func testDuplicateDetectorIgnoresUniqueSizeFiles() {
        let files = [
            makeScannedFile(path: "/tmp/a.txt", size: 10),
            makeScannedFile(path: "/tmp/b.txt", size: 20),
            makeScannedFile(path: "/tmp/c.txt", size: 30)
        ]

        let groups = DuplicateDetector().candidateGroups(from: files)

        XCTAssertTrue(groups.isEmpty)
    }

    func testDuplicateDetectorIgnoresZeroByteFiles() {
        let files = [
            makeScannedFile(path: "/tmp/empty-a.txt", size: 0),
            makeScannedFile(path: "/tmp/empty-b.txt", size: 0),
            makeScannedFile(path: "/tmp/non-empty-a.txt", size: 5),
            makeScannedFile(path: "/tmp/non-empty-b.txt", size: 5)
        ]

        let groups = DuplicateDetector().candidateGroups(from: files)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.size, 5)
        XCTAssertFalse(groups.flatMap(\.files).contains { $0.size == 0 })
    }

    func testDuplicateDetectorIgnoresGroupsWithOnlyOneFile() {
        let files = [
            makeScannedFile(path: "/tmp/lonely.txt", size: 42)
        ]

        let groups = DuplicateDetector().candidateGroups(from: files)

        XCTAssertTrue(groups.isEmpty)
    }

}

private extension XCTestCase {
    func makeScannedFile(path: String, size: Int64) -> ScannedFile {
        ScannedFile(
            fileURL: URL(fileURLWithPath: path),
            filename: URL(fileURLWithPath: path).lastPathComponent,
            path: path,
            fileExtension: URL(fileURLWithPath: path).pathExtension,
            size: size,
            creationDate: nil,
            modificationDate: nil
        )
    }

    func makeMinimalAppBundle(at bundleURL: URL) throws {
        let contents = bundleURL.appendingPathComponent("Contents", isDirectory: true)
        let macOS = contents.appendingPathComponent("MacOS", isDirectory: true)
        let resources = contents.appendingPathComponent("Resources", isDirectory: true)
        let executable = macOS.appendingPathComponent("Example")

        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)

        let infoPlist = contents.appendingPathComponent("Info.plist")
        let plist = [
            "CFBundleExecutable": "Example",
            "CFBundleIdentifier": "com.example.SafeDiskAuditorTests.Example",
            "CFBundleInfoDictionaryVersion": "6.0",
            "CFBundleName": "Example",
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "1"
        ]
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try plistData.write(to: infoPlist)

        try Data("#!/bin/sh\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        try Data("package".utf8).write(
            to: resources.appendingPathComponent("Contents.txt")
        )
    }

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
