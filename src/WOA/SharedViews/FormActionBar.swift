//
//  FormActionBar.swift
//  WOA
//
//  Created by Cristiano Degiorgis on 23/09/2026.
//

import SwiftUI

struct FormActionBar: View {
    let title: String
    let systemImage: String
    let isLoading: Bool

    let onCancel: () -> Void
    let onSubmit: () async -> Void

    var body: some View {
        HStack(spacing: AppDesignSystem.spacingSM) {
            Button("Cancel", action: onCancel)
                .appSecondaryButton()

            Spacer()

            Button {
                Task {
                    await onSubmit()
                }
            } label: {
                Label(title, systemImage: systemImage)
            }
            .appAddButton()
            .disabled(isLoading)
        }
    }
}
