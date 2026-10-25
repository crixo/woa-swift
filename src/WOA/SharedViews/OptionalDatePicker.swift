import SwiftUI

struct OptionalDatePicker: View {
    let title: String
    @Binding var date: Date?
    var placeholder: String = "Non impostata"

    var body: some View {
        HStack {
            Text(title)
            Spacer()

            if let current = date {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { current },
                        set: { date = $0 }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
                .labelsHidden()

                Button {
                    date = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Button(placeholder) {
                    date = Date()
                }
                .foregroundStyle(.secondary)
            }
        }
    }
}
