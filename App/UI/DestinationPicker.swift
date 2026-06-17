import SwiftUI

/// A small reusable labelled text field, used for origin and destination entry.
struct DestinationPicker: View {
    let title: String
    @Binding var text: String

    init(_ title: String = "Destination", text: Binding<String>) {
        self.title = title
        self._text = text
    }

    var body: some View {
        TextField(title, text: $text)
            .textFieldStyle(.roundedBorder)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
    }
}
