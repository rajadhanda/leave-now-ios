import SwiftUI

struct DestinationPicker: View {
    @Binding var destination: String

    var body: some View {
        TextField("Destination", text: $destination)
            .textFieldStyle(.roundedBorder)
    }
}
