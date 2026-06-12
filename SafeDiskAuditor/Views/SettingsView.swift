import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Safety") {
                LabeledContent("Deletion behavior", value: "Not implemented")
                LabeledContent("Cleaner module", value: "Disabled for MVP shell")
                Text("Cleanup, Trash, merge, rename, and deletion actions remain disabled until hash verification is implemented.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About SafeDisk Auditor") {
                LabeledContent("Creator", value: "OptiWisdom LLC")
                Link("www.optiwisdom.com", destination: URL(string: "https://www.optiwisdom.com")!)
                Text("SafeDisk Auditor helps review size-based duplicate candidates safely. No files are modified by scan, review, or persistence features.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
}
