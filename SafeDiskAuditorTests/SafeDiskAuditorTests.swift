import XCTest
@testable import SafeDiskAuditor

final class SafeDiskAuditorTests: XCTestCase {
    @MainActor
    func testAppViewModelDefaultsToScanSection() {
        let viewModel = AppViewModel()

        XCTAssertEqual(viewModel.selectedSection, .scan)
    }

    func testScanServiceProvidesInitialStatusMessage() {
        let service = ScanService()

        XCTAssertEqual(service.statusMessage(), "Ready to configure safe folder scanning.")
    }
}
