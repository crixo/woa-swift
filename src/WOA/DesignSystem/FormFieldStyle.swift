import SwiftUI

// MARK: - 3. Styling

struct FormFieldStyle: Sendable {
    var labelFont: Font = .subheadline.weight(.medium)
    var labelColor: Color = .primary
    var requiredMarkerColor: Color = .red

    var background: Color = Color(nsColor: .separatorColor)
    var borderColor: Color = Color(nsColor: .controlBackgroundColor)
    var errorBorderColor: Color = .red
    var borderWidth: CGFloat = 1
    var cornerRadius: CGFloat = 10
    var contentPadding: EdgeInsets = .init(top: 10, leading: 12, bottom: 10, trailing: 12)

    var errorFont: Font = .footnote
    var errorColor: Color = .red

    var spacing: CGFloat = 6
}

private struct FormFieldStyleKey: EnvironmentKey {
    static let defaultValue = FormFieldStyle()
}

extension EnvironmentValues {
    var formFieldStyle: FormFieldStyle {
        get { self[FormFieldStyleKey.self] }
        set { self[FormFieldStyleKey.self] = newValue }
    }
}

extension View {
    /// Set a style for every FormField inside this view hierarchy.
    func formFieldStyle(_ style: FormFieldStyle) -> some View {
        environment(\.formFieldStyle, style)
    }
}
