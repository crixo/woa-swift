import SwiftUI

@MainActor
protocol EntityEditViewModel: EntityAddViewModel {
    associatedtype Entity

    // Read-only
    var isLoading: Bool { get }
    var entity: Entity? { get }
    func load() async
}
