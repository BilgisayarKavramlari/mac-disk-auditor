import AppKit
import SwiftUI

private enum DuplicateExplorerGroupingMode: String, CaseIterable, Identifiable {
    case fileType = "File Type"
    case sizeBucket = "Size Bucket"
    case dateBucket = "Date Bucket"
    case locationBucket = "Location Bucket"

    var id: String { rawValue }
}

private enum DuplicateFileSortMode: String, CaseIterable, Identifiable {
    case size = "Size"
    case name = "Name"
    case modificationDate = "Modified"
    case path = "Path"

    var id: String { rawValue }
}

private struct DuplicateExplorerSection: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbolName: String
    let tint: Color
    let duplicateGroups: [DuplicateGroup]
    let isTinyFilesSection: Bool

    var candidateGroupCount: Int {
        duplicateGroups.count
    }

    var candidateFileCount: Int {
        duplicateGroups.reduce(0) { $0 + $1.fileCount }
    }

    var estimatedReclaimableSize: Int64 {
        duplicateGroups.reduce(0) { $0 + $1.estimatedReclaimableSize }
    }

    var estimatedReclaimableDescription: String {
        ByteCountFormatter.string(fromByteCount: estimatedReclaimableSize, countStyle: .file)
    }
}

struct DuplicatesView: View {
    @ObservedObject var scanViewModel: ScanViewModel
    let runAnotherScan: () -> Void

    @State private var interactionMessage: String?
    @State private var groupingMode: DuplicateExplorerGroupingMode = .fileType
    @State private var fileSortMode: DuplicateFileSortMode = .size
    @State private var hideTinyFiles = true
    @State private var expandedSectionIDs: Set<String> = []
    @State private var visibleGroupLimits: [String: Int] = [:]
    @State private var cachedExplorerSections: [DuplicateExplorerSection] = []
    @State private var selectedFileIDs: Set<String> = []
    @State private var selectedTotalSize: Int64 = 0

    private let tinyFileThreshold: Int64 = 64 * 1024
    private let duplicateGroupBatchSize = 50

    private var totalCandidateFiles: Int {
        scanViewModel.duplicateGroups.reduce(0) { $0 + $1.fileCount }
    }

    private var selectedTotalSizeDescription: String {
        ByteCountFormatter.string(fromByteCount: selectedTotalSize, countStyle: .file)
    }

    private var hiddenTinyCandidateCount: Int {
        scanViewModel.duplicateGroups
            .filter { isTinyDuplicateGroup($0) }
            .reduce(0) { $0 + $1.fileCount }
    }

    private var hasRunScan: Bool {
        scanViewModel.lastScanStartedAt != nil || scanViewModel.scanStatus == .completed
    }

    private func buildExplorerSections() -> [DuplicateExplorerSection] {
        var buckets: [String: (title: String, subtitle: String, symbolName: String, tint: Color, isTiny: Bool, groups: [DuplicateGroup])] = [:]

        for group in scanViewModel.duplicateGroups {
            let descriptor = sectionDescriptor(for: group)
            if descriptor.isTiny && hideTinyFiles {
                continue
            }

            var bucket = buckets[descriptor.id] ?? (
                title: descriptor.title,
                subtitle: descriptor.subtitle,
                symbolName: descriptor.symbolName,
                tint: descriptor.tint,
                isTiny: descriptor.isTiny,
                groups: []
            )
            bucket.groups.append(group)
            buckets[descriptor.id] = bucket
        }

        return buckets.map { id, bucket in
            DuplicateExplorerSection(
                id: id,
                title: bucket.title,
                subtitle: bucket.subtitle,
                symbolName: bucket.symbolName,
                tint: bucket.tint,
                duplicateGroups: sortedDuplicateGroups(bucket.groups),
                isTinyFilesSection: bucket.isTiny
            )
        }
        .sorted { lhs, rhs in
            if lhs.isTinyFilesSection != rhs.isTinyFilesSection {
                return !lhs.isTinyFilesSection
            }
            if lhs.estimatedReclaimableSize != rhs.estimatedReclaimableSize {
                return lhs.estimatedReclaimableSize > rhs.estimatedReclaimableSize
            }
            if lhs.candidateFileCount != rhs.candidateFileCount {
                return lhs.candidateFileCount > rhs.candidateFileCount
            }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                header
                summaryCards
                controls
                safetyNote
                interactionHint
                duplicateExplorer
            }
            .padding(32)
        }
        .navigationTitle("Duplicates")
        .onAppear(perform: resetExplorerState)
        .onChange(of: groupingMode) { _, _ in
            resetExplorerState()
        }
        .onChange(of: fileSortMode) { _, _ in
            resetExplorerState()
        }
        .onChange(of: hideTinyFiles) { _, _ in
            resetExplorerState()
        }
        .onChange(of: scanViewModel.duplicateGroups) { _, _ in
            pruneSelectionForCurrentResults()
            resetExplorerState()
        }
    }
}

private extension DuplicatesView {
    var header: some View {
        HStack(alignment: .top, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.blue.opacity(0.14))
                    .frame(width: 64, height: 64)
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Duplicate Explorer")
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                Text("Browse duplicate candidates by type, size, date, or location. Expand only the groups you want to review so large scans stay responsive.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    runAnotherScan()
                } label: {
                    Label("Back to Scan", systemImage: "house")
                }
            }
        }
    }

    var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 14)], spacing: 14) {
            metricCard(title: "Candidate groups", value: "\(scanViewModel.duplicateGroups.count)", systemImage: "rectangle.3.group", tint: .blue)
            metricCard(title: "Candidate files", value: "\(totalCandidateFiles)", systemImage: "doc.on.doc", tint: .purple)
            metricCard(title: "Estimated reclaimable", value: scanViewModel.estimatedReclaimableCandidateSizeDescription, systemImage: "externaldrive", tint: .green)
            metricCard(title: "Selected", value: "\(selectedFileIDs.count) files • \(selectedTotalSizeDescription)", systemImage: "checkmark.circle", tint: .orange)
        }
    }

    var controls: some View {
        GroupBox("Explorer Controls") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    Picker("Group by", selection: $groupingMode) {
                        ForEach(DuplicateExplorerGroupingMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Sort files", selection: $fileSortMode) {
                        ForEach(DuplicateFileSortMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                HStack(spacing: 12) {
                    Toggle("Hide tiny files under \(ByteCountFormatter.string(fromByteCount: tinyFileThreshold, countStyle: .file))", isOn: $hideTinyFiles)
                        .toggleStyle(.checkbox)

                    if hiddenTinyCandidateCount > 0 {
                        Text("\(hiddenTinyCandidateCount) tiny candidate files")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Clear Selection") {
                        selectedFileIDs.removeAll()
                        selectedTotalSize = 0
                    }
                    .disabled(selectedFileIDs.isEmpty)
                }

                Text("Top-level groups are sorted by estimated reclaimable size. Expanded groups render in batches of \(duplicateGroupBatchSize) candidate groups for smoother scrolling.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var safetyNote: some View {
        Label("Current duplicate results are candidates. No files are modified.", systemImage: "lock.shield")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    var interactionHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Right-click a candidate file for actions. These actions only open files or reveal them in Finder.")
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

    var duplicateExplorer: some View {
        Group {
            if cachedExplorerSections.isEmpty {
                ContentUnavailableView(
                    "No Candidate Groups",
                    systemImage: "doc.on.doc",
                    description: Text(emptyCandidatesMessage)
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(cachedExplorerSections) { section in
                        sectionCard(section)
                    }
                }
            }
        }
    }

    func sectionCard(_ section: DuplicateExplorerSection) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedSectionIDs.contains(section.id) },
                set: { isExpanded in
                    if isExpanded {
                        expandedSectionIDs.insert(section.id)
                    } else {
                        expandedSectionIDs.remove(section.id)
                    }
                }
            )
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(visibleDuplicateGroups(in: section)) { group in
                    duplicateGroupCard(group)
                }

                if hasMoreGroups(in: section) {
                    Button {
                        visibleGroupLimits[section.id, default: duplicateGroupBatchSize] += duplicateGroupBatchSize
                    } label: {
                        Label("Load More", systemImage: "arrow.down.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.top, 12)
        } label: {
            sectionHeader(section)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.quaternary, lineWidth: 1)
        )
    }

    func sectionHeader(_ section: DuplicateExplorerSection) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(section.tint.opacity(0.14))
                    .frame(width: 48, height: 48)
                Image(systemName: section.symbolName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(section.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(section.title)
                    .font(.headline)
                Text(section.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                summaryPill("\(section.candidateGroupCount) groups", systemImage: "rectangle.3.group")
                summaryPill("\(section.candidateFileCount) files", systemImage: "doc")
                summaryPill(section.estimatedReclaimableDescription, systemImage: "externaldrive")
            }
        }
        .contentShape(Rectangle())
    }

    func duplicateGroupCard(_ group: DuplicateGroup) -> some View {
        let files = sortedFiles(in: group)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(groupHeader(for: group))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(group.fileCount) files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(files) { file in
                    candidateFileRow(file)
                    if file.id != files.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(12)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 12))
    }

    func candidateFileRow(_ file: ScannedFile) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle("", isOn: selectionBinding(for: file))
                .labelsHidden()

            Image(systemName: fileSymbolName(for: file))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(file.filename)
                        .font(.callout)
                        .lineLimit(1)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text(file.path)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if let modificationDate = file.modificationDate {
                        Text("•")
                        Text(modificationDate.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
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
            updateSelection(for: file, isSelected: isSelected)
        }
    }

    var emptyCandidatesMessage: String {
        hasRunScan
        ? "No duplicate candidates found in the latest scan with the current filters."
        : "Run a scan first to calculate duplicate candidates."
    }

    func visibleDuplicateGroups(in section: DuplicateExplorerSection) -> [DuplicateGroup] {
        Array(section.duplicateGroups.prefix(visibleLimit(for: section)))
    }

    func visibleLimit(for section: DuplicateExplorerSection) -> Int {
        visibleGroupLimits[section.id, default: duplicateGroupBatchSize]
    }

    func hasMoreGroups(in section: DuplicateExplorerSection) -> Bool {
        section.duplicateGroups.count > visibleLimit(for: section)
    }

    func sortedDuplicateGroups(_ groups: [DuplicateGroup]) -> [DuplicateGroup] {
        groups.sorted { lhs, rhs in
            switch fileSortMode {
            case .size:
                if lhs.size != rhs.size {
                    return lhs.size > rhs.size
                }
            case .name:
                let comparison = firstSortedFile(in: lhs).filename.localizedStandardCompare(firstSortedFile(in: rhs).filename)
                if comparison != .orderedSame {
                    return comparison == .orderedAscending
                }
            case .modificationDate:
                let lhsDate = newestModificationDate(in: lhs)
                let rhsDate = newestModificationDate(in: rhs)
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
            case .path:
                let comparison = firstSortedFile(in: lhs).path.localizedStandardCompare(firstSortedFile(in: rhs).path)
                if comparison != .orderedSame {
                    return comparison == .orderedAscending
                }
            }

            if lhs.estimatedReclaimableSize != rhs.estimatedReclaimableSize {
                return lhs.estimatedReclaimableSize > rhs.estimatedReclaimableSize
            }
            return lhs.size > rhs.size
        }
    }

    func sortedFiles(in group: DuplicateGroup) -> [ScannedFile] {
        group.files.sorted { lhs, rhs in
            switch fileSortMode {
            case .size:
                if lhs.size != rhs.size {
                    return lhs.size > rhs.size
                }
                return lhs.filename.localizedStandardCompare(rhs.filename) == .orderedAscending
            case .name:
                return lhs.filename.localizedStandardCompare(rhs.filename) == .orderedAscending
            case .modificationDate:
                return (lhs.modificationDate ?? .distantPast) > (rhs.modificationDate ?? .distantPast)
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
        let reclaimableDescription = ByteCountFormatter.string(fromByteCount: group.estimatedReclaimableSize, countStyle: .file)
        return "\(ByteCountFormatter.string(fromByteCount: group.size, countStyle: .file)) each • estimated reclaimable \(reclaimableDescription)"
    }

    func updateSelection(for file: ScannedFile, isSelected: Bool) {
        if isSelected {
            if selectedFileIDs.insert(file.id).inserted {
                selectedTotalSize += file.size
            }
        } else if selectedFileIDs.remove(file.id) != nil {
            selectedTotalSize = max(0, selectedTotalSize - file.size)
        }
    }

    func pruneSelectionForCurrentResults() {
        let currentFiles = scanViewModel.duplicateGroups.flatMap(\.files)
        let currentIDs = Set(currentFiles.map(\.id))
        selectedFileIDs.formIntersection(currentIDs)
        selectedTotalSize = currentFiles.reduce(0) { total, file in
            selectedFileIDs.contains(file.id) ? total + file.size : total
        }
    }

    func resetExplorerState() {
        let sections = buildExplorerSections()
        cachedExplorerSections = sections
        expandedSectionIDs = Set(sections.filter { !$0.isTinyFilesSection }.map(\.id))
        visibleGroupLimits = Dictionary(uniqueKeysWithValues: sections.map { ($0.id, duplicateGroupBatchSize) })
    }

    func sectionDescriptor(for group: DuplicateGroup) -> (id: String, title: String, subtitle: String, symbolName: String, tint: Color, isTiny: Bool) {
        if isTinyDuplicateGroup(group) {
            return (
                id: "special.tiny",
                title: "Tiny Files",
                subtitle: "Small duplicate candidates under \(ByteCountFormatter.string(fromByteCount: tinyFileThreshold, countStyle: .file))",
                symbolName: "sparkles.rectangle.stack",
                tint: .gray,
                isTiny: true
            )
        }

        if isCacheOrTemporaryGroup(group) {
            return (
                id: "special.cache-temp",
                title: "Cache / Temp",
                subtitle: "Candidates from cache-like or temporary paths",
                symbolName: "clock.arrow.circlepath",
                tint: .orange,
                isTiny: false
            )
        }

        switch groupingMode {
        case .fileType:
            return fileTypeDescriptor(for: group)
        case .sizeBucket:
            return sizeBucketDescriptor(for: group)
        case .dateBucket:
            return dateBucketDescriptor(for: group)
        case .locationBucket:
            return locationBucketDescriptor(for: group)
        }
    }

    func fileTypeDescriptor(for group: DuplicateGroup) -> (id: String, title: String, subtitle: String, symbolName: String, tint: Color, isTiny: Bool) {
        let file = firstSortedFile(in: group)
        let ext = file.fileExtension.isEmpty ? "No Extension" : file.fileExtension.uppercased()
        let lowerExtension = file.fileExtension.lowercased()
        return (
            id: "type.\(ext.lowercased())",
            title: ext,
            subtitle: "Grouped by filename extension",
            symbolName: fileTypeSymbol(for: lowerExtension),
            tint: fileTypeTint(for: lowerExtension),
            isTiny: false
        )
    }

    func sizeBucketDescriptor(for group: DuplicateGroup) -> (id: String, title: String, subtitle: String, symbolName: String, tint: Color, isTiny: Bool) {
        switch group.size {
        case 0..<1_048_576:
            return ("size.small", "Small Files", "64 KB to 1 MB", "doc", .teal, false)
        case 1_048_576..<10_485_760:
            return ("size.medium", "Medium Files", "1 MB to 10 MB", "doc.richtext", .blue, false)
        case 10_485_760..<104_857_600:
            return ("size.large", "Large Files", "10 MB to 100 MB", "externaldrive", .purple, false)
        default:
            return ("size.huge", "Huge Files", "100 MB and larger", "externaldrive.fill", .red, false)
        }
    }

    func dateBucketDescriptor(for group: DuplicateGroup) -> (id: String, title: String, subtitle: String, symbolName: String, tint: Color, isTiny: Bool) {
        let date = newestModificationDate(in: group)
        guard date != .distantPast else {
            return ("date.unknown", "Unknown Date", "No modification date available", "calendar.badge.questionmark", .gray, false)
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) || calendar.isDateInYesterday(date) || date > (calendar.date(byAdding: .day, value: -7, to: Date()) ?? date) {
            return ("date.week", "Recent", "Modified in the last week", "calendar.badge.clock", .green, false)
        }
        if date > (calendar.date(byAdding: .month, value: -1, to: Date()) ?? date) {
            return ("date.month", "This Month", "Modified in the last month", "calendar", .blue, false)
        }
        if date > (calendar.date(byAdding: .year, value: -1, to: Date()) ?? date) {
            return ("date.year", "This Year", "Modified in the last year", "calendar.circle", .purple, false)
        }
        return ("date.older", "Older", "Modified more than a year ago", "archivebox", .brown, false)
    }

    func locationBucketDescriptor(for group: DuplicateGroup) -> (id: String, title: String, subtitle: String, symbolName: String, tint: Color, isTiny: Bool) {
        let path = firstSortedFile(in: group).path.lowercased()
        if path.contains("/desktop/") {
            return ("location.desktop", "Desktop", "Candidates in Desktop", "desktopcomputer", .blue, false)
        }
        if path.contains("/documents/") {
            return ("location.documents", "Documents", "Candidates in Documents", "folder", .indigo, false)
        }
        if path.contains("/downloads/") {
            return ("location.downloads", "Downloads", "Candidates in Downloads", "arrow.down.circle", .orange, false)
        }
        if path.contains("/pictures/") || path.contains("/photos") {
            return ("location.pictures", "Pictures", "Candidates in Pictures or Photos", "photo", .pink, false)
        }
        if path.contains("/movies/") || path.contains("/videos/") {
            return ("location.movies", "Movies", "Candidates in Movies or Videos", "film", .purple, false)
        }
        return ("location.other", "Other Locations", "Candidates outside common user folders", "folder.badge.questionmark", .gray, false)
    }

    func isTinyDuplicateGroup(_ group: DuplicateGroup) -> Bool {
        group.size < tinyFileThreshold
    }

    func isCacheOrTemporaryGroup(_ group: DuplicateGroup) -> Bool {
        group.files.contains { file in
            let path = file.path.lowercased()
            return path.contains("/caches/")
            || path.contains("/cache/")
            || path.contains("/tmp/")
            || path.contains("/temp/")
            || path.contains("/temporaryitems/")
            || path.contains("/deriveddata/")
        }
    }

    func fileTypeSymbol(for fileExtension: String) -> String {
        switch fileExtension {
        case "jpg", "jpeg", "png", "gif", "heic", "tiff", "webp":
            return "photo"
        case "mov", "mp4", "m4v", "avi", "mkv":
            return "film"
        case "mp3", "m4a", "wav", "aiff", "flac":
            return "music.note"
        case "pdf":
            return "doc.richtext"
        case "zip", "dmg", "pkg", "gz", "rar", "7z":
            return "archivebox"
        default:
            return "doc"
        }
    }

    func fileTypeTint(for fileExtension: String) -> Color {
        switch fileExtension {
        case "jpg", "jpeg", "png", "gif", "heic", "tiff", "webp":
            return .pink
        case "mov", "mp4", "m4v", "avi", "mkv":
            return .purple
        case "mp3", "m4a", "wav", "aiff", "flac":
            return .mint
        case "pdf":
            return .red
        case "zip", "dmg", "pkg", "gz", "rar", "7z":
            return .brown
        default:
            return .blue
        }
    }

    func fileSymbolName(for file: ScannedFile) -> String {
        fileTypeSymbol(for: file.fileExtension.lowercased())
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

    func metricCard(title: String, value: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(tint.opacity(0.14))
                    .frame(width: 42, height: 42)
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.quaternary, lineWidth: 1)
        )
    }

    func summaryPill(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.quaternary, in: Capsule())
    }
}

#Preview {
    DuplicatesView(scanViewModel: ScanViewModel(), runAnotherScan: {})
}
