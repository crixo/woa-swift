//
//  DateOfBirthComplexField.swift
//  WOA
//
//  Created by Cristiano Degiorgis on 26/09/2026.
//

import SwiftUI

struct DateOfBirthComplexField: View {
        @Binding var date: Date?
        @Binding var validationError: String?
        var validate: () -> String?

        @State private var manualDateText: String = ""

        private let dateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "dd/MM/yyyy"
            f.locale = Locale(identifier: "it_IT")
            return f
        }()

        var body: some View {
            VStack(alignment: .leading) {
                DatePicker(
                    "Select Date",
                    selection: Binding(
                        get: { date ?? Date() },
                        set: { date = $0 }
                    ),
                    displayedComponents: .date
                )
                .onChange(of: date) { _, _ in
                    updateManualDateText()
                }

                TextField("dd/MM/yyyy", text: $manualDateText)
                    .onAppear {
                        updateManualDateText()
                    }
                    .onChange(of: manualDateText) { _, _ in
                        parseManualDate()
                    }

                if let validationError, !validationError.isEmpty {
                    Text(validationError)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }

        private func updateManualDateText() {
            if let date {
                manualDateText = dateFormatter.string(from: date)
            } else {
                manualDateText = ""
            }
        }

        private func parseManualDate() {
            guard !manualDateText.isEmpty else {
                date = nil
                return
            }

            if let parsed = dateFormatter.date(from: manualDateText) {
                date = parsed
                validationError = validate() ?? ""
            } else {
                validationError = "Invalid date format (use dd/MM/yyyy)"
            }
        }
    }
