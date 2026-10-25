import SwiftUI

@MainActor
protocol EntityAddViewModel: ObservableObject {
    var isSaving: Bool { get }
    var errorMessage: String? { get }
    var shortErrorMessage: String? { get }
    func save() async -> Bool
}
