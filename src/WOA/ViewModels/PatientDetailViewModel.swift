import Foundation

@MainActor final class PatientDetailViewModel: ObservableObject {
    let patientID: Int
    let databaseFileURL: URL

    @Published private(set) var patient: PatientDetail?
    @Published private(set) var consultations: [ConsultationSummary] = []
    @Published private(set) var remoteHistory: [RemoteHistorySummary] = []
    @Published var editForm = PatientCreateRequest()
    @Published var provinces: [LookupProvince] = []
    @Published var validationErrors: [String: String] = [:]
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isDeleting = false
    @Published var isEditing = false
    @Published var showDeleteConfirmation = false
    @Published var isAttributesExpanded = true
    @Published var isConsultationsExpanded = true
    @Published var isHistoryExpanded = true

    init(patientID: Int, databaseFileURL: URL) {
        self.patientID = patientID
        self.databaseFileURL = databaseFileURL
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            patient = try PatientRepository.fetchPatient(by: patientID, databaseFileURL: databaseFileURL)
            consultations = try PatientRepository.fetchConsultations(for: patientID, databaseFileURL: databaseFileURL)
            remoteHistory = try PatientRepository.fetchRemoteHistory(for: patientID, databaseFileURL: databaseFileURL)
            provinces = try PatientRepository.fetchProvinces(databaseFileURL: databaseFileURL)
            if let patient {
                editForm = patient.formData
            }
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.error("Failed to load patient \(patientID): \(error.localizedDescription)")
        }
        isLoading = false
    }

    func beginEditing() {
        guard let patient else { return }
        editForm = patient.formData
        validationErrors = [:]
        isEditing = true
    }

    func cancelEditing() {
        if let patient {
            editForm = patient.formData
        }
        validationErrors = [:]
        isEditing = false
    }

    func validate() -> Bool {
        validationErrors = [:]
        if editForm.nome.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
            validationErrors["nome"] = "First name must be at least 2 characters"
        }
        if editForm.cognome.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
            validationErrors["cognome"] = "Last name must be at least 2 characters"
        }
        if let date = editForm.data_nascita, date > Date() {
            validationErrors["data_nascita"] = "Date of birth cannot be in the future"
        }
        return validationErrors.isEmpty
    }

    func save() async {
        guard validate() else { return }
        isSaving = true
        errorMessage = nil
        do {
            try PatientRepository.updatePatient(editForm, patientID: patientID, databaseFileURL: databaseFileURL)
            isEditing = false
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    func delete() async -> Bool {
        isDeleting = true
        errorMessage = nil
        do {
            try PatientRepository.deletePatient(id: patientID, databaseFileURL: databaseFileURL)
            isDeleting = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isDeleting = false
            return false
        }
    }
}

@MainActor final class ConsultationDetailViewModel: ObservableObject {
    let consultationID: Int
    let databaseFileURL: URL
    @Published private(set) var consultation: ConsultationDetail?
    @Published var errorMessage: String?
    @Published var isLoading = false

    init(consultationID: Int, databaseFileURL: URL) {
        self.consultationID = consultationID
        self.databaseFileURL = databaseFileURL
    }

    func load() async {
        isLoading = true
        do {
            consultation = try PatientRepository.fetchConsultation(by: consultationID, databaseFileURL: databaseFileURL)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

@MainActor final class RemoteHistoryDetailViewModel: ObservableObject {
    let historyID: Int
    let databaseFileURL: URL
    @Published private(set) var history: RemoteHistoryDetail?
    @Published var errorMessage: String?
    @Published var isLoading = false

    init(historyID: Int, databaseFileURL: URL) {
        self.historyID = historyID
        self.databaseFileURL = databaseFileURL
    }

    func load() async {
        isLoading = true
        do {
            history = try PatientRepository.fetchRemoteHistoryItem(by: historyID, databaseFileURL: databaseFileURL)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

@MainActor final class ConsultationCreateViewModel: ObservableObject {
    let databaseFileURL: URL
    @Published var request: ConsultationCreateRequest
    @Published var errorMessage: String?
    @Published var isSubmitting = false

    init(patientID: Int, databaseFileURL: URL) {
        self.databaseFileURL = databaseFileURL
        request = ConsultationCreateRequest(patientID: patientID)
    }

    func submit() async -> Bool {
        guard !request.initialProblem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Appointment reason is required"
            return false
        }
        isSubmitting = true
        do {
            _ = try PatientRepository.createConsultation(request, databaseFileURL: databaseFileURL)
            isSubmitting = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
            return false
        }
    }
}

@MainActor final class RemoteHistoryCreateViewModel: ObservableObject {
    let databaseFileURL: URL
    @Published var request: RemoteHistoryCreateRequest
    @Published var types: [AnamnesisType] = []
    @Published var errorMessage: String?
    @Published var isSubmitting = false

    init(patientID: Int, databaseFileURL: URL) {
        self.databaseFileURL = databaseFileURL
        request = RemoteHistoryCreateRequest(patientID: patientID)
        do {
            types = try PatientRepository.fetchAnamnesisTypes(databaseFileURL: databaseFileURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submit() async -> Bool {
        isSubmitting = true
        do {
            _ = try PatientRepository.createRemoteHistory(request, databaseFileURL: databaseFileURL)
            isSubmitting = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
            return false
        }
    }
}
