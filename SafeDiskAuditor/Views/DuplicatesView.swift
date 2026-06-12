import AppKit
import SwiftUI

struct DuplicatesView: View {
    @ObservedObject var scanViewModel: ScanViewModel
    let runAnotherScan: () -> Void
    @State private var interactionMessage: String?

    private var sortedDuplicateGroups: [DuplicateGroup] {
        scanViewModel.duplicateGroups.sorted { lhs, rhs in
            if lhs.fileCount == rhs.fileCount {
                return lhs.size > rhs.size
            }

            return lhs.fileCount > rhs.fileCount
        }
    }

    private var totalCandidateFiles: Int {
        scanViewModel.duplicateGroups.reduce(0) { $0 + $1.fileCount }
    }

    private var hasRunScan: Bool {
        scanViewModel.lastScanStartedAt != nil || scanViewModel.scanStatus == .completed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            summary
            interactionHint
            candidateGroups
            Spacer(minLength: 0)
        }
        .padding(32)
        .navigationTitle("Duplicates")
    }
}

private extension DuplicatesView {
    var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Duplicate Candidates", systemImage: "doc.on.doc")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Candidates are grouped by exact file size only. No partial hashes, full hashes, deletion, Trash, auto-select, preview, or cleaner actions are implemented on this screen. No files are modified.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                runAnotherScan()
            } label: {
                Label("Run Another Scan", systemImage: "magnifyingglass.circle")
            }
        }
    }

    var summary: some View {
        HStack(spacing: 16) {
            metricCard(title: "Candidate groups", value: "\(scanViewModel.duplicateGroups.count)")
            metricCard(title: "Candidate files", value: "\(totalCandidateFiles)")
        }
    }

    var interactionHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Right-click a candidate file for actions. These actions only open files or reveal them in Finder. No files are modified.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let interactionMessage {
                Text(interactionMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    var candidateGroups: some View {
        GroupBox("Current Scan Candidates") {
            if scanViewModel.duplicateGroups.isEmpty {
                ContentUnavailableView(
                    "No Candidate Groups",
                    systemImage: "doc.on.doc",
                    description: Text(emptyCandidatesMessage)
                )
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                List(sortedDuplicateGroups) { group in
                    Section {
                        ForEach(group.files) { file in
                            candidateFileRow(file)
                        }
                    } header: {
                        Text("\(group.fileCount) candidate files • \(ByteCountFormatter.string(fromByteCount: group.size, countStyle: .file)) each")
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 260)
            }
        }
    }

    func candidateFileRow(_ file: ScannedFile) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(file.filename)
                    .font(.headline)
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(file.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            openFile(file)
        }
        .contextMenu {
            Button("Open File") {
                openFile(file)
            }

            Button("Show in Finder") {
                revealInFinder(file)
            }
        }
    }

    var emptyCandidatesMessage: String {
        hasRunScan
        ? "No duplicate candidates found in the latest scan."
        : "Run a scan first to calculate duplicate candidates."
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
}

#Preview {
    DuplicatesView(scanViewModel: ScanViewModel(), runAnotherScan: {})
}
