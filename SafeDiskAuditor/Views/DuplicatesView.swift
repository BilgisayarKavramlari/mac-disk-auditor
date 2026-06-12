import SwiftUI

struct DuplicatesView: View {
    var body: some View {
        ContentUnavailableView(
            "No Duplicates Yet",
            systemImage: "doc.on.doc",
            description: Text("Duplicate detection will be added after the scanning foundation is in place.")
        )
        .padding()
    }
}

#Preview {
    DuplicatesView()
}
