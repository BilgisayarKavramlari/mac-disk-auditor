import Foundation

/// Top-level destinations shown in the app sidebar.
enum AppSection: String, CaseIterable, Identifiable {
    case scan
    case duplicates
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scan:
            "Scan"
        case .duplicates:
            "Duplicates"
        case .settings:
            "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .scan:
            "folder.badge.magnifyingglass"
        case .duplicates:
            "doc.on.doc"
        case .settings:
            "gearshape"
        }
    }
}
