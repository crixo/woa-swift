import SwiftUI

struct DateOfBirthField: View {
    let onChange: (Date) -> Void

    // Internal "day/month" carrier date — its year is irrelevant here,
    // we always pull the real year from `yearText`. Using a fixed leap
    // year (2000) avoids Feb 29 disappearing depending on the carrier's year.
    @State private var dayMonthDate: Date
    @State private var yearText: String

    private let calendar = Calendar.current

    init(initialDate: Date, onChange: @escaping (Date) -> Void) {
        self.onChange = onChange
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: initialDate)

        var carrierComps = DateComponents()
        carrierComps.year = 2000 // fixed leap year so Feb 29 is always valid in the picker
        carrierComps.month = comps.month ?? 1
        carrierComps.day = comps.day ?? 1
        _dayMonthDate = State(initialValue: cal.date(from: carrierComps) ?? Date())

        _yearText = State(initialValue: String(comps.year ?? 2000))
    }

    var body: some View {
        HStack(spacing: 8) {
            DatePicker(
                "Date of birth",
                selection: $dayMonthDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .onChange(of: dayMonthDate) { commit() }

            TextField("Year", text: $yearText)
                .frame(width: 60)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .onChange(of: yearText) { _, newValue in
                    // Keep only digits, cap at 4 characters
                    let filtered = newValue.filter { $0.isNumber }
                    let capped = String(filtered.prefix(4))
                    if capped != newValue {
                        yearText = capped
                    }
                    if capped.count == 4 {
                        commit()
                    }
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func commit() {
        guard let year = Int(yearText), yearText.count == 4 else { return }

        let dmComps = calendar.dateComponents([.month, .day], from: dayMonthDate)
        var finalComps = DateComponents()
        finalComps.year = year
        finalComps.month = dmComps.month
        finalComps.day = dmComps.day

        // Clamp day if the combination is invalid (e.g. Feb 29 on a non-leap year)
        if let candidate = calendar.date(from: finalComps) {
            onChange(candidate)
        } else {
            finalComps.day = 28
            if let fallback = calendar.date(from: finalComps) {
                onChange(fallback)
            }
        }
    }
}

// Child view — no StateObject, just plain state, safe to init
//struct DateOfBirthField: View {
//    let onChange: (Date) -> Void
//    @State private var selectedDate: Date
//
//    init(initialDate: Date, onChange: @escaping (Date) -> Void) {
//        self._selectedDate = State(initialValue: initialDate)
//        self.onChange = onChange
//    }
//
//    var body: some View {
//        DatePicker("Date of birth", selection: $selectedDate, displayedComponents: .date)
//            .datePickerStyle(.compact)
//            .frame(maxWidth: .infinity, alignment: .leading)
//            .onChange(of: selectedDate) { _, newValue in
//                onChange(newValue)
//            }
//    }
//}
