import Foundation

/// Typed change event published after a successful database mutation.
/// Includes entity type, operation, ID, and database identity for scoped filtering.
enum DataChangeEvent: Equatable, Sendable {
    case patientCreated(patientID: Int, databaseURL: URL)
    case patientUpdated(patientID: Int, databaseURL: URL)
    case patientDeleted(patientID: Int, databaseURL: URL)
    case consultationCreated(consultationID: Int, patientID: Int, databaseURL: URL)
    case consultationUpdated(consultationID: Int, patientID: Int, databaseURL: URL)
    case consultationDeleted(consultationID: Int, patientID: Int, databaseURL: URL)
    case remoteHistoryCreated(historyID: Int, patientID: Int, databaseURL: URL)
    case remoteHistoryUpdated(historyID: Int, patientID: Int, databaseURL: URL)
    case remoteHistoryDeleted(historyID: Int, patientID: Int, databaseURL: URL)
    case treatmentCreated(treatmentID: Int, consultoID: Int, databaseURL: URL)
    case treatmentUpdated(treatmentID: Int, consultoID: Int, databaseURL: URL)
    case treatmentDeleted(treatmentID: Int, consultoID: Int, databaseURL: URL)
    case evaluationCreated(evaluationID: Int, consultoID: Int, databaseURL: URL)
    case evaluationUpdated(evaluationID: Int, consultoID: Int, databaseURL: URL)
    case evaluationDeleted(evaluationID: Int, consultoID: Int, databaseURL: URL)
    case examCreated(examID: Int, consultoID: Int, databaseURL: URL)
    case examUpdated(examID: Int, consultoID: Int, databaseURL: URL)
    case examDeleted(examID: Int, consultoID: Int, databaseURL: URL)
    
    /// Extracts the database URL from any event for identity checking.
    var databaseURL: URL {
        switch self {
        case .patientCreated(_, let url),
             .patientUpdated(_, let url),
             .patientDeleted(_, let url),
             .consultationCreated(_, _, let url),
             .consultationUpdated(_, _, let url),
             .consultationDeleted(_, _, let url),
             .remoteHistoryCreated(_, _, let url),
             .remoteHistoryUpdated(_, _, let url),
             .remoteHistoryDeleted(_, _, let url),
             .treatmentCreated(_, _, let url),
             .treatmentUpdated(_, _, let url),
             .treatmentDeleted(_, _, let url),
             .evaluationCreated(_, _, let url),
             .evaluationUpdated(_, _, let url),
             .evaluationDeleted(_, _, let url),
             .examCreated(_, _, let url),
             .examUpdated(_, _, let url),
             .examDeleted(_, _, let url):
            return url
        }
    }
}

/// App-scoped coordinator managing data change events.
/// Mutation view models publish events after successful database operations.
/// Detail and list view models subscribe to events and reload only when affected by a change.
@MainActor final class DataChangeCoordinator: ObservableObject {
    private let (eventStream, eventContinuation) = AsyncStream.makeStream(of: DataChangeEvent.self)
    
    init() {}
    
    /// Publishes a data change event after a successful mutation.
    /// Call only after repository operations succeed.
    func publishChange(_ event: DataChangeEvent) {
        eventContinuation.yield(event)
    }
    
    /// Subscribes to data change events with a filter predicate.
    /// Returns an AsyncStream that filters events based on the provided predicate.
    func subscribe(
        where predicate: @escaping (DataChangeEvent) -> Bool
    ) -> AsyncStream<DataChangeEvent> {
        AsyncStream { continuation in
            let task = Task {
                for await event in eventStream {
                    if predicate(event) {
                        continuation.yield(event)
                    }
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    /// Convenience subscription for patient-scoped changes (patient detail view).
    /// Reloads when the specified patient is affected in the specified database.
    func subscribeToPatientChanges(patientID: Int, databaseURL: URL) -> AsyncStream<DataChangeEvent> {
        subscribe { event in
            guard event.databaseURL == databaseURL else { return false }
            switch event {
            case .patientUpdated(let id, _), .patientDeleted(let id, _):
                return id == patientID
            case .consultationCreated(_, let pid, _), .consultationUpdated(_, let pid, _), .consultationDeleted(_, let pid, _),
                 .remoteHistoryCreated(_, let pid, _), .remoteHistoryUpdated(_, let pid, _), .remoteHistoryDeleted(_, let pid, _):
                return pid == patientID
            default:
                return false
            }
        }
    }
    
    /// Convenience subscription for consulto-scoped changes (consulto detail view).
    /// Reloads when the specified consulto or any related record (treatment/evaluation/exam) is affected.
    func subscribeToConsultoChanges(consultoID: Int, databaseURL: URL) -> AsyncStream<DataChangeEvent> {
        subscribe { event in
            guard event.databaseURL == databaseURL else { return false }
            switch event {
            case .consultationUpdated(let cid, _, _), .consultationDeleted(let cid, _, _):
                return cid == consultoID
            case .treatmentCreated(_, let cid, _), .treatmentUpdated(_, let cid, _), .treatmentDeleted(_, let cid, _),
                 .evaluationCreated(_, let cid, _), .evaluationUpdated(_, let cid, _), .evaluationDeleted(_, let cid, _),
                 .examCreated(_, let cid, _), .examUpdated(_, let cid, _), .examDeleted(_, let cid, _):
                return cid == consultoID
            default:
                return false
            }
        }
    }
}
