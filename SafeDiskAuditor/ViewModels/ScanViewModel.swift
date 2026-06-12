import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

enum ScanStatus: String, Codable {
    case ready = "Ready"
    case scanning = "Scanning"
    case completed = "Completed"
    case cancelled = "Cancelled"
    case failed = "Failed"
}


@MainActor
final class ScanViewModel: ObservableObject {
    @Published private(set) var selectedFolders: [URL] = []
    @Published private(set) var scannedFiles: [ScannedFile] = []
    @Published private(set) var duplicateGroups: [DuplicateGroup] = []
    @Published private(set) var scannedFileCount = 0
    @Published private(set) var totalSize: Int64 = 0
    @Published private(set) var currentPath: String?
    @Published private(set) var isScanning = false
    @Published private(set) var scanStatus: ScanStatus = .ready
    @Published private(set) var lastSelectedFolderCount = 0
    @Published private(set) var lastScanStartedAt: Date?
    @Published private(set) var lastScanCompletedAt: Date?
    @Published private(set) var diagnosticsLog: [String] = []
    @Published private(set) var loadedScanTimestamp: Date?
    @Published private(set) var isLoadedScanResult = false
    @Published var errorMessage: String?

    private let fileScanner: FileScanner
    private let duplicateDetector: DuplicateDetector
    private var scanTask: Task<Void, Never>?
    private var lastLoggedProgressCount = 0

    init(
        fileScanner: FileScanner = FileScanner(),
        duplicateDetector: DuplicateDetector = DuplicateDetector()
    ) {
        self.fileScanner = fileScanner
        self.duplicateDetector = duplicateDetector
    }

    var hasSelectedFolders: Bool {
        !selectedFolders.isEmpty
    }

    var canStartScan: Bool {
        hasSelectedFolders && !isScanning
    }

    var selectedFolderSummary: String {
        switch selectedFolders.count {
        case 0:
            return "No folders selected yet"
        case 1:
            return "1 folder selected"
        default:
            return "\(selectedFolders.count) folders selected"
        }
    }

    var folderSelectionButtonTitle: String {
        hasSelectedFolders ? "Change Folders…" : "Choose Folders…"
    }

    var totalSizeDescription: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    var hasScanResults: Bool {
        !scannedFiles.isEmpty || scanStatus == .completed || isLoadedScanResult
    }

    var duplicateCandidateFileCount: Int {
        duplicateGroups.reduce(0) { $0 + $1.fileCount }
    }

    var estimatedReclaimableCandidateSize: Int64 {
        duplicateGroups.reduce(0) { total, group in
            total + max(0, group.fileCount - 1) * group.size
        }
    }

    var estimatedReclaimableCandidateSizeDescription: String {
        ByteCountFormatter.string(fromByteCount: estimatedReclaimableCandidateSize, countStyle: .file)
    }

    var freeDiskSpaceDescription: String {
        guard let freeSize = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())[.systemFreeSize] as? NSNumber else {
            return "Unavailable"
        }

        return ByteCountFormatter.string(fromByteCount: freeSize.int64Value, countStyle: .file)
    }

    var scanDurationDescription: String {
        guard let start = lastScanStartedAt, let end = lastScanCompletedAt else {
            return "—"
        }

        return Self.durationFormatter.string(from: max(0, end.timeIntervalSince(start))) ?? "—"
    }

    var loadedScanTimestampDescription: String? {
        loadedScanTimestamp?.formatted(date: .abbreviated, time: .standard)
    }

    func chooseFolders() {
        let panel = NSOpenPanel()
        panel.title = "Choose Folders to Scan"
        panel.prompt = "Choose"
        panel.message = "Select one or more folders for SafeDisk Auditor to scan. Hidden files and package contents are skipped by default."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.resolvesAliases = true

        guard panel.runModal() == .OK else {
            appendDiagnostic("Folder selection cancelled")
            return
        }

        selectedFolders = panel.urls
        lastSelectedFolderCount = selectedFolders.count
        appendDiagnostic("Folders selected: \(selectedFolders.count)")
        resetScanResults()
    }

    func startScan() {
        guard canStartScan else {
            return
        }

        let folders = selectedFolders
        isScanning = true
        scanStatus = .scanning
        isLoadedScanResult = false
        loadedScanTimestamp = nil
        errorMessage = nil
        scannedFiles = []
        duplicateGroups = []
        scannedFileCount = 0
        totalSize = 0
        currentPath = nil
        lastScanStartedAt = Date()
        lastScanCompletedAt = nil
        lastLoggedProgressCount = 0
        appendDiagnostic("Scan started for \(folders.count) folder(s)")

        scanTask = Task { [fileScanner, duplicateDetector] in
            do {
                let result = try await fileScanner.scan(folders: folders) { progress in
                    Task { @MainActor in
                        self.apply(progress: progress)
                    }
                }

                scannedFiles = result.files
                duplicateGroups = duplicateDetector.candidateGroups(from: result.files)
                scannedFileCount = result.files.count
                totalSize = result.totalSize
                currentPath = nil
                isScanning = false
                scanStatus = .completed
                lastScanCompletedAt = Date()
                scanTask = nil
                appendDiagnostic("Scan completed: \(scannedFileCount) file(s), \(duplicateGroups.count) duplicate candidate group(s)")
            } catch is CancellationError {
                currentPath = nil
                isScanning = false
                scanStatus = .cancelled
                lastScanCompletedAt = Date()
                scanTask = nil
                appendDiagnostic("Scan cancelled")
            } catch {
                currentPath = nil
                isScanning = false
                scanStatus = .failed
                lastScanCompletedAt = Date()
                scanTask = nil
                errorMessage = "Scan failed: \(error.localizedDescription)"
                appendDiagnostic("Scan failed: \(error.localizedDescription)")
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        scanStatus = .cancelled
        lastScanCompletedAt = Date()
        currentPath = nil
        appendDiagnostic("Scan cancelled")
    }

    func saveScanResults() {
        guard hasScanResults else {
            errorMessage = "No scan results are available to save."
            return
        }

        let panel = NSSavePanel()
        panel.title = "Save Scan Results"
        panel.nameFieldStringValue = "SafeDiskAuditor-ScanResults.json"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else {
            appendDiagnostic("Save scan results cancelled")
            return
        }

        do {
            let snapshot = ScanResultSnapshot(
                savedAt: Date(),
                scanStartedAt: lastScanStartedAt,
                scanCompletedAt: lastScanCompletedAt,
                selectedFolders: selectedFolders,
                scannedFiles: scannedFiles,
                duplicateGroups: duplicateGroups
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(snapshot).write(to: url, options: .atomic)
            appendDiagnostic("Scan results saved: \(url.lastPathComponent)")
        } catch {
            errorMessage = "Could not save scan results: \(error.localizedDescription)"
            appendDiagnostic("Save scan results failed: \(error.localizedDescription)")
        }
    }

    func loadScanResults() {
        let panel = NSOpenPanel()
        panel.title = "Load Scan Results"
        panel.prompt = "Load"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else {
            appendDiagnostic("Load scan results cancelled")
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshot = try decoder.decode(ScanResultSnapshot.self, from: Data(contentsOf: url))
            selectedFolders = snapshot.selectedFolders
            scannedFiles = snapshot.scannedFiles
            duplicateGroups = snapshot.duplicateGroups
            scannedFileCount = snapshot.scannedFiles.count
            totalSize = snapshot.scannedFiles.reduce(0) { $0 + $1.size }
            currentPath = nil
            isScanning = false
            scanStatus = .completed
            lastSelectedFolderCount = snapshot.selectedFolders.count
            lastScanStartedAt = snapshot.scanStartedAt
            lastScanCompletedAt = snapshot.scanCompletedAt
            loadedScanTimestamp = snapshot.savedAt
            isLoadedScanResult = true
            errorMessage = nil
            appendDiagnostic("Loaded scan results: \(url.lastPathComponent)")
        } catch {
            errorMessage = "Could not load scan results: \(error.localizedDescription)"
            appendDiagnostic("Load scan results failed: \(error.localizedDescription)")
        }
    }
}

struct ScanResultSnapshot: Codable {
    let savedAt: Date
    let scanStartedAt: Date?
    let scanCompletedAt: Date?
    let selectedFolders: [URL]
    let scannedFiles: [ScannedFile]
    let duplicateGroups: [DuplicateGroup]
}

private extension ScanViewModel {
    func apply(progress: FileScanProgress) {
        scannedFileCount = progress.scannedFileCount
        totalSize = progress.totalSize
        currentPath = progress.currentPath

        guard progress.scannedFileCount != lastLoggedProgressCount else {
            return
        }

        if progress.scannedFileCount <= 5 || progress.scannedFileCount - lastLoggedProgressCount >= 25 {
            lastLoggedProgressCount = progress.scannedFileCount
            appendDiagnostic("Scan progress: \(progress.scannedFileCount) file(s), \(ByteCountFormatter.string(fromByteCount: progress.totalSize, countStyle: .file))")
        }
    }

    func resetScanResults() {
        scannedFiles = []
        duplicateGroups = []
        scannedFileCount = 0
        totalSize = 0
        currentPath = nil
        scanStatus = .ready
        lastScanStartedAt = nil
        lastScanCompletedAt = nil
        loadedScanTimestamp = nil
        isLoadedScanResult = false
        lastLoggedProgressCount = 0
        errorMessage = nil
    }

    func appendDiagnostic(_ message: String) {
        diagnosticsLog.append("\(Self.diagnosticTimestampFormatter.string(from: Date())) — \(message)")
        if diagnosticsLog.count > 20 {
            diagnosticsLog.removeFirst(diagnosticsLog.count - 20)
        }
    }

    static let diagnosticTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
