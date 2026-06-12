import Combine
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var selectedSection: AppSection? = .scan

    private let scanService: ScanService

    init(scanService: ScanService = ScanService()) {
        self.scanService = scanService
    }

    var scanStatusMessage: String {
        scanService.statusMessage()
    }
}
