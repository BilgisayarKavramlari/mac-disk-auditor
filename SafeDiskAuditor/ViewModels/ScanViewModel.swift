import AppKit
import Combine
import Foundation

@MainActor
final class ScanViewModel: ObservableObject {
    @Published private(set) var selectedFolders: [URL] = []
    @Published private(set) var scannedFiles: [ScannedFile] = []
    @Published private(set) var duplicateGroups: [DuplicateGroup] = []
    @Published private(set) var scannedFileCount = 0
    @Published private(set) var totalSize: Int64 = 0
    @Published private(set) var currentPath: String?
    @Published private(set) var isScanning = false
    @Published var errorMessage: String?

    private let fileScanner: FileScanner
    private let duplicateDetector: DuplicateDetector
    private var scanTask: Task<Void, Never>?

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
            return "No folders selected"
        case 1:
            return selectedFolders[0].lastPathComponent
        default:
            return "\(selectedFolders.count) folders selected"
        }
    }

    var totalSizeDescription: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
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
            return
        }

        selectedFolders = panel.urls
        resetScanResults()
    }

    func startScan() {
        guard canStartScan else {
            return
        }

        let folders = selectedFolders
        isScanning = true
        errorMessage = nil
        scannedFiles = []
        duplicateGroups = []
        scannedFileCount = 0
        totalSize = 0
        currentPath = nil

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
            } catch is CancellationError {
                currentPath = nil
                isScanning = false
            } catch {
                currentPath = nil
                isScanning = false
                errorMessage = "Scan failed: \(error.localizedDescription)"
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        currentPath = nil
    }
}

private extension ScanViewModel {
    func apply(progress: FileScanProgress) {
        scannedFileCount = progress.scannedFileCount
        totalSize = progress.totalSize
        currentPath = progress.currentPath
    }

    func resetScanResults() {
        scannedFiles = []
        duplicateGroups = []
        scannedFileCount = 0
        totalSize = 0
        currentPath = nil
        errorMessage = nil
    }
}
