import SwiftUI

enum AppDesignSystem {
    static let spacingXS: CGFloat = 8
    static let spacingSM: CGFloat = 12
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 20
    static let spacingXL: CGFloat = 24

    static let cardRadius: CGFloat = 16
    static let controlRadius: CGFloat = 12
    static let panelMaxWidth: CGFloat = 980
    static let formMaxWidth: CGFloat = 560
}

private struct AppCardModifier: ViewModifier {
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppDesignSystem.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppDesignSystem.cardRadius, style: .continuous)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
    }
}

private struct AppPanelModifier: ViewModifier {
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppDesignSystem.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppDesignSystem.cardRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}

private struct AppSectionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppDesignSystem.spacingMD)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: AppDesignSystem.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppDesignSystem.controlRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }
}

private struct AppPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(minHeight: 32)
            .foregroundStyle(.white)
            .background(configuration.isPressed ? Color.accentColor.opacity(0.8) : Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.controlRadius, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
    }
}

private struct AppSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(minHeight: 32)
            .foregroundStyle(Color.primary)
            .background(configuration.isPressed ? Color.secondary.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppDesignSystem.controlRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.18), lineWidth: 1)
            )
    }
}

private struct AppSemanticButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(minHeight: 32)
            .foregroundStyle(configuration.isPressed ? color.opacity(0.8) : color)
            .background(color.opacity(configuration.isPressed ? 0.18 : 0.1))
            .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppDesignSystem.controlRadius, style: .continuous)
                    .stroke(color.opacity(0.35), lineWidth: 1)
            )
    }
}

extension View {
    func appCard(padding: CGFloat = 18) -> some View {
        modifier(AppCardModifier(padding: padding))
    }

    func appPanel(padding: CGFloat = 20) -> some View {
        modifier(AppPanelModifier(padding: padding))
    }

    func appSection() -> some View {
        modifier(AppSectionModifier())
    }

    func appPrimaryButton() -> some View {
        buttonStyle(AppPrimaryButtonStyle())
    }

    func appSecondaryButton() -> some View {
        buttonStyle(AppSecondaryButtonStyle())
    }

    func appEditButton() -> some View {
        buttonStyle(AppSemanticButtonStyle(color: .orange))
    }

    func appSearchButton() -> some View {
        buttonStyle(AppSemanticButtonStyle(color: .blue))
    }

    func appAddButton() -> some View {
        buttonStyle(AppSemanticButtonStyle(color: .green))
    }

    func appDeleteButton() -> some View {
        buttonStyle(AppSemanticButtonStyle(color: .red))
    }

    func appForm(maxWidth: CGFloat = AppDesignSystem.formMaxWidth) -> some View {
        self
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.primary.opacity(0.025))
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    func appErrorText() -> some View {
        self
            .font(.caption)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
    }
}
