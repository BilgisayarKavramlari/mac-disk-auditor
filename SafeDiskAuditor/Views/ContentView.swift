import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationTitle(AppConstants.appName)
        } detail: {
            detailView
        }
        .frame(minWidth: 900, minHeight: 560)
    }
}

private extension ContentView {
    var sidebar: some View {
        List {
            ForEach(AppSection.allCases) { section in
                Button {
                    viewModel.selectSection(section)
                } label: {
                    Label(section.title, systemImage: section.systemImage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    viewModel.selectedSection == section
                    ? Color.accentColor.opacity(0.16)
                    : Color.clear
                )
            }
        }
    }

    @ViewBuilder
    var detailView: some View {
        switch viewModel.selectedSection {
        case .scan:
            ScanView(
                viewModel: viewModel.scanViewModel,
                showDuplicateCandidates: { viewModel.selectSection(.duplicates) }
            )
        case .duplicates:
            DuplicatesView(
                scanViewModel: viewModel.scanViewModel,
                runAnotherScan: { viewModel.selectSection(.scan) }
            )
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    ContentView(viewModel: AppViewModel())
}
