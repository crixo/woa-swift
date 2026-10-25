import SwiftUI

extension Binding where Value == Date? {
    func withDefault(_ defaultValue: Date = Date()) -> Binding<Date> {
        Binding<Date>(
            get: { self.wrappedValue ?? defaultValue },
            set: { self.wrappedValue = $0 }
        )
    }
}

extension Binding where Value == String? {
    func withDefault(_ defaultValue: String = "") -> Binding<String> {
        Binding<String>(
            get: { self.wrappedValue ?? defaultValue },
            set: { self.wrappedValue = $0 }
        )
    }
}
