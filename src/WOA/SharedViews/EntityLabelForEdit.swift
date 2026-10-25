//
//  EntityLabelForEdit.swift
//  WOA
//
//  Created by Cristiano Degiorgis on 24/09/2026.
//
import SwiftUI

struct EntityLabelForEdit : View {
    let name: String
    let id: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(name, systemImage: "clipboard.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text("ID \(id)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
