import SwiftUI

// MARK: - 4. FormField

/// Wraps ANY control provided by the caller (TextField, Picker, DatePicker,
/// radio group, Toggle...) and adds: label, error text, border/background.
///
/// - `field`: identifies the field in the ViewModel's validator
/// - `value`: the bound value; FormField watches it to trigger validation
/// - `boxed`: draw background + border around the control (turn off for radio groups, toggles...)
struct FormField<ID: Hashable, Value: Equatable, Content: View>: View {
    @ObservedObject private var form: FormValidator<ID>
    @Environment(\.formFieldStyle) private var style

    private let label: String
    private let field: ID
    private let value: Value
    private let isRequired: Bool
    private let boxed: Bool
    private let content: Content

    init(_ label: String,
         field: ID,
         form: FormValidator<ID>,
         value: Value,
         isRequired: Bool = false,
         boxed: Bool = true,
         @ViewBuilder content: () -> Content) {
        self.label = label
        self.field = field
        self._form = ObservedObject(wrappedValue: form)
        self.value = value
        self.isRequired = isRequired
        self.boxed = boxed
        self.content = content()
    }

    private var errorMessage: String? { form.error(for: field) }

    var body: some View {
        VStack(alignment: .leading, spacing: style.spacing) {
            labelView
            controlView
            if let errorMessage {
                Text(errorMessage)
                    .font(style.errorFont)
                    .foregroundStyle(style.errorColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .accessibilityLabel("Error: \(errorMessage)")
            }
        }
        .animation(.easeInOut(duration: 0.15), value: errorMessage)
        .onChange(of: value) { form.fieldDidChange(field) }
    }

    private var labelView: some View {
        HStack(spacing: 2) {
            Text(label)
            if isRequired {
                Text("*").foregroundStyle(style.requiredMarkerColor)
            }
        }
        .font(style.labelFont)
        .foregroundStyle(style.labelColor)
    }

    @ViewBuilder
    private var controlView: some View {
        if boxed {
            content
                .padding(style.contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(style.background, in: RoundedRectangle(cornerRadius: style.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: style.cornerRadius)
                        .strokeBorder(errorMessage == nil ? style.borderColor : style.errorBorderColor,
                                      lineWidth: style.borderWidth)
                )
        } else {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
