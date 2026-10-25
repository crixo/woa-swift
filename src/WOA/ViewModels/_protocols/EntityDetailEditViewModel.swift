import SwiftUI

@MainActor
protocol EntityDetailEditViewModel: EntityAddViewModel {
    associatedtype Entity

    // Read-only
    var isLoading: Bool { get }
    var isDeleting: Bool { get }
    var entity: Entity? { get }

    // Two-way: the template binds to it, so it must be settable
    var showDeleteConfirmation: Bool { get set }

    func load() async
    func delete() async -> Bool   // adjust to your actual return type
}
