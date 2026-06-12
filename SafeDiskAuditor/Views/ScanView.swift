import SwiftUI

struct ScanView: View {
    let statusMessage: String

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "externaldrive.badge.magnifyingglass")
                .font(.system(size: 64, weight: .regular))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("Start with a safe, focused scan")
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                Text("SafeDisk Auditor will help you choose folders, review results, and keep control before any future cleanup action. Folder selection and duplicate detection are not enabled in this initial project shell.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
            }

            Text(statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.quaternary, in: Capsule())
        }
        .padding(40)
    }
}

#Preview {
    ScanView(statusMessage: "Ready to configure safe folder scanning.")
}
