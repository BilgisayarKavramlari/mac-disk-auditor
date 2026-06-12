import SwiftUI

struct ScanView: View {
    @ObservedObject var viewModel: ScanViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            folderSelection
            progressSummary
            recentFiles
            Spacer(minLength: 0)
        }
        .padding(32)
        .navigationTitle("Scan")
    }
}

private extension ScanView {
    var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Start with a safe, focused scan", systemImage: "externaldrive.badge.magnifyingglass")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Choose one or more folders to recursively scan for regular files. SafeDisk Auditor skips hidden files and package contents by default, and this screen only collects metadata—duplicate detection and deletion are not implemented yet.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var folderSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    viewModel.chooseFolders()
                } label: {
                    Label("Choose Folders…", systemImage: "folder.badge.plus")
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
            }

            Text(viewModel.selectedFolderSummary)
                .font(.callout)
                .foregroundStyle(.secondary)

            if !viewModel.selectedFolders.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.selectedFolders, id: \.path) { folder in
                        Text(folder.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
        }
    }

    var progressSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.isScanning {
                ProgressView("Scanning…")
                    .controlSize(.small)
            }

            HStack(spacing: 16) {
                metricCard(title: "Files scanned", value: "\(viewModel.scannedFileCount)")
                metricCard(title: "Total size", value: viewModel.totalSizeDescription)
            }

            if let currentPath = viewModel.currentPath {
                Text("Current file: \(currentPath)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
    }

    var recentFiles: some View {
        GroupBox("Scanned Files") {
            if viewModel.scannedFiles.isEmpty {
                ContentUnavailableView(
                    "No Files Scanned",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Select folders and start a scan to collect file metadata.")
                )
                .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                Table(viewModel.scannedFiles) {
                    TableColumn("Name") { file in
                        Text(file.filename)
                            .lineLimit(1)
                    }
                    TableColumn("Extension") { file in
                        Text(file.fileExtension.isEmpty ? "—" : file.fileExtension)
                    }
                    TableColumn("Size") { file in
                        Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                    }
                    TableColumn("Path") { file in
                        Text(file.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .frame(minHeight: 180)
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
    ScanView(viewModel: ScanViewModel())
}
