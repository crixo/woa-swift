//
//  SaveResultCard.swift
//  WOA
//
//  Created by Cristiano Degiorgis on 21/09/2026.
//

import SwiftUI

struct SaveResultCard: View {
    let succeeded: Bool
    let successMessage: String
    let failureMessage: String
    let backLabel: String
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: succeeded
                    ? "checkmark.circle.fill"
                    : "xmark.circle.fill"
                )
                .foregroundStyle(
                    succeeded ? .green : .red
                )
                .font(.title2)

                Text(
                    succeeded
                    ? successMessage
                    : failureMessage
                )
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                succeeded
                ? Color.green.opacity(0.1)
                : Color.red.opacity(0.1)
            )
            .cornerRadius(8)

            Spacer()

            Button(action: onBack) {
                Text(backLabel)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding()
        }
        .padding()
    }
}
