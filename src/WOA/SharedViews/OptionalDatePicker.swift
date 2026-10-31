import SwiftUI

struct OptionalDatePicker: View {
    let title: String
    @Binding var date: Date?
    var placeholder: String = "Non impostata"

    var body: some View {
        if let current = date {
            HStack(spacing: AppDesignSystem.spacingSM) {
                DatePicker(
                    title,
                    selection: Binding(
                        get: { current },
                        set: { date = $0 }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )

                Button {
                    date = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        } else {
            VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                Text(title)
                    .font(.subheadline.weight(.medium))

                Button(placeholder) {
                    date = Date()
                }
                .foregroundStyle(.secondary)
            }
        }

    }
}

#Preview {
    OptionalDatePicker(
        title: "Data di nascita",
        date: .constant(Date())
    )
    .padding()
}
