//
//  SaveResultModal.swift
//  WOA
//
//  Created by Cristiano Degiorgis on 21/09/2026.
//

import SwiftUI


struct SaveResultModal: View {
    let state: SaveResultState
    let target: String
    let parent: String
    let onDismiss: () -> Void

    private var isSuccess: Bool {
        if case .success = state {
            return true
        }
        return false
    }

    private var title: String {
        isSuccess ? "\(target) saved" : "Unable to save"
    }

    private var message: String {
        switch state {
        case .success:
            return "\(target) was saved successfully."
        case .failure(let detail):
            return detail
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 36))
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)

            Button(isSuccess ? "Back to \(parent)" : "Close") {
                onDismiss()
            }
            .appPrimaryButton()
            .frame(maxWidth: .infinity)
        }
        .padding(28)
        .frame(width: 420)
        .background(isSuccess ? Color.green.opacity(0.12) : Color.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: AppDesignSystem.cardRadius, style: .continuous))
    }
}
