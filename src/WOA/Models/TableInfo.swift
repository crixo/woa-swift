import Foundation

/// Represents a database table together with its current record count.
struct TableInfo: Identifiable, Codable, Equatable {
    var id: String { name }
    let name: String
    let recordCount: Int
}
