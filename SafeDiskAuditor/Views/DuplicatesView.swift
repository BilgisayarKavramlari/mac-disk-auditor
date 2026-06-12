import SwiftUI

struct DuplicatesView: View {
    @ObservedObject var scanViewModel: ScanViewModel

    private var totalCandidateFiles: Int {
        scanViewModel.duplicateGroups.reduce(0) { $0 + $1.fileCount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            summary
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

            Text("Candidates are grouped by exact file size only. No partial hashes, full hashes, deletion, Trash, auto-select, preview, or cleaner actions are implemented on this screen.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var summary: some View {
        HStack(spacing: 16) {
            metricCard(title: "Candidate groups", value: "\(scanViewModel.duplicateGroups.count)")
            metricCard(title: "Candidate files", value: "\(totalCandidateFiles)")
        }
    }

    var candidateGroups: some View {
        GroupBox("Current Scan Candidates") {
            if scanViewModel.duplicateGroups.isEmpty {
                ContentUnavailableView(
                    "No Candidate Groups",
                    systemImage: "doc.on.doc",
                    description: Text("Run a scan to find same-size file groups. Unique-size and zero-byte files are ignored.")
                )
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                List(scanViewModel.duplicateGroups) { group in
                    Section {
                        ForEach(group.files) { file in
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
                        }
                    } header: {
                        Text("\(group.fileCount) files • \(ByteCountFormatter.string(fromByteCount: group.size, countStyle: .file)) each")
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 260)
            }
        }
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
    DuplicatesView(scanViewModel: ScanViewModel())
}
