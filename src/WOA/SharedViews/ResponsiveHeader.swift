//
//  ResponsiveHeader.swift
//  WOA
//
//  Created by Cristiano Degiorgis on 21/09/2026.
//

import SwiftUI

struct ResponsiveHeader<Info: View, Actions: View>: View {
    @ViewBuilder let info: () -> Info
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        //ViewThatFits(in: .horizontal) {
            HStack(alignment: .top) {
                info()
                Spacer()
                actions()
            }

        //     VStack(alignment: .leading, spacing: 8) {
        //         info()

        //         HStack {
        //             actions()
        //         }
        //     }
        // }
    }
}

struct ResponsiveHeaderActions: View {
    @Binding var isEditMode: Bool
    @Binding var showDeleteConfirmation: Bool
    let isDeleting: Bool

    var body: some View {
        HStack(spacing: AppDesignSystem.spacingSM) {
            Button {
                isEditMode = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .appEditButton()

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .appDeleteButton()
            .disabled(isDeleting)
        }
    }
}
