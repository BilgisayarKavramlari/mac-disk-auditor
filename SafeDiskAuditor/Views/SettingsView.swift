import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Safety") {
                LabeledContent("Deletion behavior", value: "Not implemented")
                LabeledContent("Cleaner module", value: "Disabled for MVP shell")
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
