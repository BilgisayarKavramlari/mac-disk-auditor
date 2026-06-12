import Combine
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var selectedSection: AppSection? = .scan

    let scanViewModel: ScanViewModel

    init() {
        self.scanViewModel = ScanViewModel()
    }

    init(scanViewModel: ScanViewModel) {
        self.scanViewModel = scanViewModel
    }
}
