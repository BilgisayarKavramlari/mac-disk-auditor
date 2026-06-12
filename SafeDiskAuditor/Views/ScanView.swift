import AppKit
import SwiftUI

struct ScanView: View {
    @ObservedObject var viewModel: ScanViewModel
    let showDuplicateCandidates: () -> Void
    @State private var scannedFilesSortOrder: [KeyPathComparator<ScannedFile>] = [
        KeyPathComparator(\ScannedFile.size, order: .reverse)
    ]
    @State private var interactionMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if !viewModel.hasSelectedFolders {
                    firstRunCard
                }

                folderSelection
                scanStatus
                scanDashboard
                completionSummary
                diagnostics
                recentFiles
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Scan")
    }
}

private extension ScanView {
    var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Start with a safe, focused scan", systemImage: "magnifyingglass.circle")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Choose one or more folders to recursively scan for regular files. SafeDisk Auditor only scans folders you select, skips hidden files and package contents by default, and does not modify files during scanning.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                viewModel.chooseFolders()
            } label: {
                Label("Choose Folders…", systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isScanning)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.quaternary)
        }
    }

    var firstRunCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Choose a folder to start", systemImage: "folder.badge.plus")
                .font(.title2)
                .fontWeight(.semibold)

            Text("SafeDisk Auditor only scans folders you select. No files are modified.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                viewModel.chooseFolders()
            } label: {
                Label("Choose Folders…", systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isScanning)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.quaternary)
        }
    }

    var folderSelection: some View {
        GroupBox("Selected Folders") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button {
                        viewModel.chooseFolders()
                    } label: {
                        Label(viewModel.folderSelectionButtonTitle, systemImage: "folder.badge.plus")
                    }
                    .disabled(viewModel.isScanning)

                    Button {
                        viewModel.startScan()
                    } label: {
                        Label("Start Scan", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canStartScan)

                    if viewModel.isScanning {
                        Button("Cancel", role: .cancel) {
                            viewModel.cancelScan()
                        }
                    }

                    Button {
                        viewModel.saveScanResults()
                    } label: {
                        Label("Save Scan Results…", systemImage: "square.and.arrow.down")
                    }
                    .disabled(!viewModel.hasScanResults || viewModel.isScanning)

                    Button {
                        viewModel.loadScanResults()
                    } label: {
                        Label("Load Scan Results…", systemImage: "square.and.arrow.up")
                    }
                    .disabled(viewModel.isScanning)
                }

                Text(viewModel.selectedFolderSummary)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if viewModel.isLoadedScanResult, let timestamp = viewModel.loadedScanTimestampDescription {
                    Label("Loaded from saved scan: \(timestamp)", systemImage: "externaldrive")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !viewModel.selectedFolders.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(viewModel.selectedFolders, id: \.path) { folder in
                            Text(folder.path)
                                .font(.caption)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var scanStatus: some View {
        GroupBox("Scan Status") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(viewModel.scanStatus.rawValue)
                        .font(.headline)

                    if viewModel.isScanning {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                HStack(spacing: 16) {
                    metricCard(title: "Files scanned", value: "\(viewModel.scannedFileCount)")
                    metricCard(title: "Total size", value: viewModel.totalSizeDescription)
                }

                if let currentPath = viewModel.currentPath {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current file")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(currentPath)
                            .font(.caption)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    var scanDashboard: some View {
        if viewModel.hasScanResults {
            GroupBox("Scan Dashboard") {
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.isLoadedScanResult, let timestamp = viewModel.loadedScanTimestampDescription {
                        Label("Showing results loaded from a saved scan: \(timestamp)", systemImage: "tray.and.arrow.down")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                        metricCard(title: "Free disk space", value: viewModel.freeDiskSpaceDescription)
                        metricCard(title: "Scanned files", value: "\(viewModel.scannedFileCount)")
                        metricCard(title: "Scanned size", value: viewModel.totalSizeDescription)
                        metricCard(title: "Candidate groups", value: "\(viewModel.duplicateGroups.count)")
                        metricCard(title: "Candidate files", value: "\(viewModel.duplicateCandidateFileCount)")
                        metricCard(title: "Estimated reclaimable", value: viewModel.estimatedReclaimableCandidateSizeDescription)
                        metricCard(title: "Scan duration", value: viewModel.scanDurationDescription)
                        metricCard(title: "Selected folders", value: "\(viewModel.lastSelectedFolderCount)")
                    }

                    reclaimableBar

                    Text("Duplicate size is estimated from candidate groups and is not safe to clean until hash verification is implemented.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    var completionSummary: some View {
        if viewModel.scanStatus == .completed {
            GroupBox("Completion Summary") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        metricCard(title: "Scanned files", value: "\(viewModel.scannedFileCount)")
                        metricCard(title: "Scanned size", value: viewModel.totalSizeDescription)
                        metricCard(title: "Duplicate candidate groups", value: "\(viewModel.duplicateGroups.count)")
                    }

                    Label("No files are modified.", systemImage: "checkmark.shield")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Button {
                        showDuplicateCandidates()
                    } label: {
                        Label("View Duplicate Candidates", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    var reclaimableBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Estimated candidate reclaimable size")
                .font(.caption)
                .foregroundStyle(.secondary)
            GeometryReader { proxy in
                let ratio = viewModel.totalSize > 0
                    ? min(1, Double(viewModel.estimatedReclaimableCandidateSize) / Double(viewModel.totalSize))
                    : 0
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.orange)
                        .frame(width: max(4, proxy.size.width * ratio))
                }
            }
            .frame(height: 8)
        }
    }

    var diagnostics: some View {
        GroupBox("Diagnostics") {
            VStack(alignment: .leading, spacing: 12) {
                diagnosticRow("Last selected folder count", "\(viewModel.lastSelectedFolderCount)")
                diagnosticRow("Last scan started", formattedDate(viewModel.lastScanStartedAt))
                diagnosticRow("Last scan completed", formattedDate(viewModel.lastScanCompletedAt))
                diagnosticRow("Last scan status", viewModel.scanStatus.rawValue)
                if let errorMessage = viewModel.errorMessage {
                    diagnosticRow("Last error message", errorMessage)
                }
                diagnosticRow("Scanned file count", "\(viewModel.scannedFileCount)")
                diagnosticRow("Duplicate candidate group count", "\(viewModel.duplicateGroups.count)")

                if !viewModel.diagnosticsLog.isEmpty {
                    Divider()
                    Text("Recent events")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(viewModel.diagnosticsLog.suffix(8).enumerated()), id: \.offset) { _, entry in
                            Text(entry)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var recentFiles: some View {
        GroupBox("Scanned Files") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Tip: Double-click a file name to open it. Click a path to reveal it in Finder. These actions only open files or reveal them in Finder. No files are modified.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let interactionMessage {
                    Text(interactionMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if viewModel.scannedFiles.isEmpty {
                    ContentUnavailableView(
                        "No Files Scanned",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Select folders and start a scan to collect file metadata. No files are modified.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 160)
                } else {
                    // Default to largest files first so users can quickly identify scans with the highest storage impact.
                    Table(sortedScannedFiles, sortOrder: $scannedFilesSortOrder) {
                        TableColumn("Name", value: \.filename) { file in
                            Text(file.filename)
                                .lineLimit(1)
                                .onTapGesture(count: 2) {
                                    openFile(file)
                                }
                        }
                        TableColumn("Extension", value: \.fileExtension) { file in
                            Text(file.fileExtension.isEmpty ? "—" : file.fileExtension)
                        }
                        TableColumn("Size", value: \.size) { file in
                            Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                        }
                        TableColumn("Path", value: \.path) { file in
                            Button {
                                revealInFinder(file)
                            } label: {
                                Label(file.path, systemImage: "folder")
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .buttonStyle(.link)
                            .help("Reveal in Finder")
                        }
                    }
                    .frame(minHeight: 180)
                }
            }
        }
    }

    var sortedScannedFiles: [ScannedFile] {
        viewModel.scannedFiles.sorted(using: scannedFilesSortOrder)
    }

    func openFile(_ file: ScannedFile) {
        guard FileManager.default.fileExists(atPath: file.fileURL.path) else {
            interactionMessage = "Could not open file: file no longer exists at \(file.path)"
            return
        }

        if NSWorkspace.shared.open(file.fileURL) {
            interactionMessage = "Opened file: \(file.filename)"
        } else {
            interactionMessage = "Could not open file: \(file.path)"
        }
    }

    func revealInFinder(_ file: ScannedFile) {
        guard FileManager.default.fileExists(atPath: file.fileURL.path) else {
            interactionMessage = "Could not reveal file in Finder: file no longer exists at \(file.path)"
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([file.fileURL])
        interactionMessage = "Revealed in Finder: \(file.filename)"
    }

    func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    func diagnosticRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 16)
            Text(value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .font(.callout)
    }

    func formattedDate(_ date: Date?) -> String {
        guard let date else {
            return "—"
        }

        return date.formatted(date: .abbreviated, time: .standard)
    }
}

#Preview {
    ScanView(viewModel: ScanViewModel(), showDuplicateCandidates: {})
}
