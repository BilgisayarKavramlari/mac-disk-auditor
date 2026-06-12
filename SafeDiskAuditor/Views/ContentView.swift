import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $viewModel.selectedSection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section as AppSection?)
            }
            .navigationTitle(AppConstants.appName)
        } detail: {
            switch viewModel.selectedSection {
            case .scan:
                ScanView(statusMessage: viewModel.scanStatusMessage)
            case .duplicates:
                DuplicatesView()
            case .settings:
                SettingsView()
            case .none:
                ScanView(statusMessage: viewModel.scanStatusMessage)
            }
        }
        .frame(minWidth: 900, minHeight: 560)
    }
}

#Preview {
    ContentView(viewModel: AppViewModel())
}
