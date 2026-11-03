//
//  FormActionBar.swift
//  WOA
//
//  Created by Cristiano Degiorgis on 23/09/2026.
//

import SwiftUI

enum FormActionSubmissionStyle {
    case add
    case save
}

struct FormActionBar: View {
    let title: String
    let systemImage: String?
    let submissionStyle: FormActionSubmissionStyle
    let isLoading: Bool

    let onCancel: () -> Void
    let onSubmit: () async -> Void

    var body: some View {
        HStack(spacing: AppDesignSystem.spacingSM) {
            cancelButton
            Spacer(minLength: AppDesignSystem.spacingSM)
            submitButton
        }
    }

    private var cancelButton: some View {
        Button("Annulla", action: onCancel)
            .appSecondaryButton()
    }

    @ViewBuilder
    private var submitButton: some View {
        Button {
            Task {
                await onSubmit()
            }
        } label: {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .disabled(isLoading)
        .modifier(SubmissionButtonStyle(style: submissionStyle))
    }
}

private struct SubmissionButtonStyle: ViewModifier {
    let style: FormActionSubmissionStyle

    @ViewBuilder
    func body(content: Content) -> some View {
        switch style {
        case .add:
            content.appAddButton()
        case .save:
            content.appPrimaryButton()
        }
    }

}

#Preview {
    FormActionBar(
        title: "Aggiungi paziente",
        systemImage: "person.badge.plus",
        submissionStyle: .add,
        isLoading: false,
        onCancel: {},
        onSubmit: {}
    )
    .padding()
}
