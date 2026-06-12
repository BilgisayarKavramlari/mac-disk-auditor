import AppKit
import SwiftUI

enum DuplicateCandidateSortMode: String, CaseIterable, Identifiable {
    case defaultPriority = "Default"
    case size = "Size"
    case fileName = "File Name"
    case modificationDate = "Modified Date"
    case path = "Path"

    var id: String { rawValue }
}

struct DuplicatesView: View {
    @ObservedObject var scanViewModel: ScanViewModel
    let runAnotherScan: () -> Void
    @State private var interactionMessage: String?
    @State private var sortMode: DuplicateCandidateSortMode = .defaultPriority
    @State private var selectedFileIDs: Set<String> = []

    private var sortedDuplicateGroups: [DuplicateGroup] {
        scanViewModel.duplicateGroups.sorted { lhs, rhs in
            switch sortMode {
            case .defaultPriority:
                let lhsReclaimable = lhs.estimatedReclaimableSize
                let rhsReclaimable = rhs.estimatedReclaimableSize
                if lhsReclaimable != rhsReclaimable {
                    return lhsReclaimable > rhsReclaimable
                }
                if lhs.size != rhs.size {
                    return lhs.size > rhs.size
                }
                return newestModificationDate(in: lhs) > newestModificationDate(in: rhs)
            case .size:
                return lhs.size > rhs.size
            case .fileName:
                return firstSortedFile(in: lhs).filename.localizedStandardCompare(firstSortedFile(in: rhs).filename) == .orderedAscending
            case .modificationDate:
                return newestModificationDate(in: lhs) > newestModificationDate(in: rhs)
            case .path:
                return firstSortedFile(in: lhs).path.localizedStandardCompare(firstSortedFile(in: rhs).path) == .orderedAscending
            }
        }
    }

    private var allCandidateFiles: [ScannedFile] {
        scanViewModel.duplicateGroups.flatMap(\.files)
    }

    private var totalCandidateFiles: Int {
        allCandidateFiles.count
    }

    private var selectedFiles: [ScannedFile] {
        allCandidateFiles.filter { selectedFileIDs.contains($0.id) }
    }

    private var selectedTotalSize: Int64 {
        selectedFiles.reduce(0) { $0 + $1.size }
    }

    private var selectedTotalSizeDescription: String {
        ByteCountFormatter.string(fromByteCount: selectedTotalSize, countStyle: .file)
    }

    private var hasRunScan: Bool {
        scanViewModel.lastScanStartedAt != nil || scanViewModel.scanStatus == .completed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            summary
            sortingAndSelectionControls
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
                Label("Back to Scan", systemImage: "house")
            }
        }
    }

    var summary: some View {
        HStack(spacing: 16) {
            metricCard(title: "Candidate groups", value: "\(scanViewModel.duplicateGroups.count)")
            metricCard(title: "Candidate files", value: "\(totalCandidateFiles)")
            metricCard(title: "Estimated reclaimable", value: scanViewModel.estimatedReclaimableCandidateSizeDescription)
            metricCard(title: "Selected", value: "\(selectedFiles.count) files")
        }
    }

    var sortingAndSelectionControls: some View {
        GroupBox("Review Controls") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Picker("Sort", selection: $sortMode) {
                        ForEach(DuplicateCandidateSortMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Spacer()

                    Text("Sort: \(sortMode.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Button("Select All") {
                        selectedFileIDs = Set(allCandidateFiles.map(\.id))
                    }
                    .disabled(allCandidateFiles.isEmpty)

                    Button("Clear Selection") {
                        selectedFileIDs.removeAll()
                    }
                    .disabled(selectedFileIDs.isEmpty)

                    Text("Selected: \(selectedFiles.count) files • \(selectedTotalSizeDescription)")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Spacer()
                }

                HStack(spacing: 12) {
                    Button("Move Selected to Trash") {}
                        .disabled(true)
                    Button("Keep Newest in Each Group") {}
                        .disabled(true)
                    Button("Merge All") {}
                        .disabled(true)
                }

                Text("Cleanup actions are disabled until hash verification is implemented. Current results are size-based candidates only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
                        ForEach(sortedFiles(in: group)) { file in
                            candidateFileRow(file)
                        }
                    } header: {
                        Text(groupHeader(for: group))
                            .font(.headline)
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 360)
            }
        }
    }

    func candidateFileRow(_ file: ScannedFile) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle("", isOn: selectionBinding(for: file))
                .labelsHidden()

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

    func selectionBinding(for file: ScannedFile) -> Binding<Bool> {
        Binding {
            selectedFileIDs.contains(file.id)
        } set: { isSelected in
            if isSelected {
                selectedFileIDs.insert(file.id)
            } else {
                selectedFileIDs.remove(file.id)
            }
        }
    }

    var emptyCandidatesMessage: String {
        hasRunScan
        ? "No duplicate candidates found in the latest scan."
        : "Run a scan first to calculate duplicate candidates."
    }

    func sortedFiles(in group: DuplicateGroup) -> [ScannedFile] {
        group.files.sorted { lhs, rhs in
            switch sortMode {
            case .defaultPriority, .modificationDate:
                return (lhs.modificationDate ?? .distantPast) > (rhs.modificationDate ?? .distantPast)
            case .size:
                return lhs.size > rhs.size
            case .fileName:
                return lhs.filename.localizedStandardCompare(rhs.filename) == .orderedAscending
            case .path:
                return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
            }
        }
    }

    func firstSortedFile(in group: DuplicateGroup) -> ScannedFile {
        sortedFiles(in: group).first ?? group.files[0]
    }

    func newestModificationDate(in group: DuplicateGroup) -> Date {
        group.files.compactMap(\.modificationDate).max() ?? .distantPast
    }

    func groupHeader(for group: DuplicateGroup) -> String {
        let reclaimableSize = group.estimatedReclaimableSize
        let reclaimableDescription = ByteCountFormatter.string(fromByteCount: reclaimableSize, countStyle: .file)
        return "\(group.fileCount) candidate files • \(ByteCountFormatter.string(fromByteCount: group.size, countStyle: .file)) each • estimated reclaimable \(reclaimableDescription)"
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
