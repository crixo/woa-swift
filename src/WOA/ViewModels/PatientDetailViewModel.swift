import Foundation

@MainActor final class PatientDetailViewModel: ObservableObject {
    let patientID: Int
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator

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
    
    private var changeEventTask: Task<Void, Never>?

    init(patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator) {
        self.patientID = patientID
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator
        
        // Subscribe to patient change events
        subscribeToChanges()
    }
    
    deinit {
        changeEventTask?.cancel()
    }
    
    private func subscribeToChanges() {
        changeEventTask?.cancel()
        changeEventTask = Task {
            for await _ in dataChangeCoordinator.subscribeToPatientChanges(patientID: patientID, databaseURL: databaseFileURL) {
                await load()
            }
        }
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
            dataChangeCoordinator.publishChange(.patientUpdated(patientID: patientID, databaseURL: databaseFileURL))
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
            dataChangeCoordinator.publishChange(.patientDeleted(patientID: patientID, databaseURL: databaseFileURL))
            isDeleting = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isDeleting = false
            return false
        }
    }
}

@MainActor final class ConsultoDetailViewModel: ObservableObject {
    let consultoID: Int
    let patientID: Int
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator
    
    @Published private(set) var consultation: ConsultationDetail?
    @Published private(set) var treatments: [TreatmentSummary] = []
    @Published private(set) var evaluations: [EvaluationSummary] = []
    @Published private(set) var exams: [ExamSummary] = []
    
    @Published var editForm = ConsultationCreateRequest(patientID: 0)
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isDeleting = false
    @Published var isEditing = false
    @Published var showDeleteConfirmation = false
    @Published var isTreatmentsExpanded = true
    @Published var isEvaluationsExpanded = true
    @Published var isExamsExpanded = true
    
    private var changeEventTask: Task<Void, Never>?

    init(consultoID: Int, patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator) {
        self.consultoID = consultoID
        self.patientID = patientID
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator
        editForm = ConsultationCreateRequest(patientID: patientID)
        subscribeToChanges()
    }
    
    deinit {
        changeEventTask?.cancel()
    }
    
    private func subscribeToChanges() {
        changeEventTask?.cancel()
        changeEventTask = Task {
            for await _ in dataChangeCoordinator.subscribeToConsultoChanges(consultoID: consultoID, databaseURL: databaseFileURL) {
                await load()
            }
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            consultation = try PatientRepository.fetchConsultation(by: consultoID, databaseFileURL: databaseFileURL)
            treatments = try PatientRepository.fetchTreatments(for: consultoID, databaseFileURL: databaseFileURL)
            evaluations = try PatientRepository.fetchEvaluations(for: consultoID, databaseFileURL: databaseFileURL)
            exams = try PatientRepository.fetchExams(for: consultoID, databaseFileURL: databaseFileURL)
            if let consultation {
                editForm = ConsultationCreateRequest(patientID: consultation.patientID, date: consultation.date ?? Date(), initialProblem: consultation.initialProblem ?? "")
            }
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.error("Failed to load consulto \(consultoID): \(error.localizedDescription)")
        }
        isLoading = false
    }

    func beginEditing() {
        guard let consultation else { return }
        editForm = ConsultationCreateRequest(patientID: consultation.patientID, date: consultation.date ?? Date(), initialProblem: consultation.initialProblem ?? "")
        isEditing = true
    }

    func cancelEditing() {
        if let consultation {
            editForm = ConsultationCreateRequest(patientID: consultation.patientID, date: consultation.date ?? Date(), initialProblem: consultation.initialProblem ?? "")
        }
        isEditing = false
    }

    func save() async {
        isSaving = true
        errorMessage = nil
        do {
            try PatientRepository.updateConsultation(editForm, consultationID: consultoID, databaseFileURL: databaseFileURL)
            isEditing = false
            dataChangeCoordinator.publishChange(.consultationUpdated(consultationID: consultoID, patientID: patientID, databaseURL: databaseFileURL))
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
            try PatientRepository.deleteConsultation(id: consultoID, databaseFileURL: databaseFileURL)
            dataChangeCoordinator.publishChange(.consultationDeleted(consultationID: consultoID, patientID: patientID, databaseURL: databaseFileURL))
            isDeleting = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isDeleting = false
            return false
        }
    }
}

@MainActor final class TreatmentCreateViewModel: ObservableObject {
    let consultoID: Int
    let patientID: Int
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator
    @Published var request: TreatmentCreateRequest
    @Published var errorMessage: String?
    @Published var isSubmitting = false

    init(consultoID: Int, patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator) {
        self.consultoID = consultoID
        self.patientID = patientID
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator
        request = TreatmentCreateRequest(consultoID: consultoID, patientID: patientID)
    }

    func submit() async -> Bool {
        guard !request.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Description is required"
            return false
        }
        isSubmitting = true
        do {
            let treatmentID = try PatientRepository.createTreatment(request, databaseFileURL: databaseFileURL)
            dataChangeCoordinator.publishChange(.treatmentCreated(treatmentID: treatmentID, consultoID: consultoID, databaseURL: databaseFileURL))
            isSubmitting = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
            return false
        }
    }
}

@MainActor final class TreatmentEditViewModel: ObservableObject {
    let treatmentID: Int
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator
    
    @Published private(set) var treatment: TreatmentDetail?
    @Published var request: TreatmentCreateRequest
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isDeleting = false
    @Published var showDeleteConfirmation = false
    @Published private(set) var saveSucceeded: Bool?

    init(treatmentID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator) {
        self.treatmentID = treatmentID
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator
        request = TreatmentCreateRequest(consultoID: 0, patientID: 0)
    }

    func load() async {
        isLoading = true
        do {
            treatment = try PatientRepository.fetchTreatment(by: treatmentID, databaseFileURL: databaseFileURL)
            if let treatment {
                request = TreatmentCreateRequest(
                    consultoID: treatment.consultoID,
                    patientID: treatment.patientID,
                    date: treatment.date ?? Date(),
                    description: treatment.description ?? ""
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func save() async {
        guard !request.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Description is required"
            saveSucceeded = false
            return
        }
        isSaving = true
        errorMessage = nil
        do {
            try PatientRepository.updateTreatment(request, id: treatmentID, databaseFileURL: databaseFileURL)
            dataChangeCoordinator.publishChange(.treatmentUpdated(treatmentID: treatmentID, consultoID: request.consultoID, databaseURL: databaseFileURL))
            saveSucceeded = true
            isSaving = false
        } catch {
            errorMessage = error.localizedDescription
            saveSucceeded = false
            isSaving = false
        }
    }

    func delete() async -> Bool {
        isDeleting = true
        errorMessage = nil
        do {
            try PatientRepository.deleteTreatment(id: treatmentID, databaseFileURL: databaseFileURL)
            if let treatment {
                dataChangeCoordinator.publishChange(.treatmentDeleted(treatmentID: treatmentID, consultoID: treatment.consultoID, databaseURL: databaseFileURL))
            }
            isDeleting = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isDeleting = false
            return false
        }
    }
}

@MainActor final class EvaluationCreateViewModel: ObservableObject {
    let consultoID: Int
    let patientID: Int
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator
    @Published var request: EvaluationCreateRequest
    @Published var errorMessage: String?
    @Published var isSubmitting = false

    init(consultoID: Int, patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator) {
        self.consultoID = consultoID
        self.patientID = patientID
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator
        request = EvaluationCreateRequest(consultoID: consultoID, patientID: patientID)
    }

    func submit() async -> Bool {
        isSubmitting = true
        do {
            let evaluationID = try PatientRepository.createEvaluation(request, databaseFileURL: databaseFileURL)
            dataChangeCoordinator.publishChange(.evaluationCreated(evaluationID: evaluationID, consultoID: consultoID, databaseURL: databaseFileURL))
            isSubmitting = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
            return false
        }
    }
}

@MainActor final class EvaluationEditViewModel: ObservableObject {
    let evaluationID: Int
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator
    
    @Published private(set) var evaluation: EvaluationDetail?
    @Published var request: EvaluationCreateRequest
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isDeleting = false
    @Published var showDeleteConfirmation = false
    @Published private(set) var saveSucceeded: Bool?

    init(evaluationID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator) {
        self.evaluationID = evaluationID
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator
        request = EvaluationCreateRequest(consultoID: 0, patientID: 0)
    }

    func load() async {
        isLoading = true
        do {
            evaluation = try PatientRepository.fetchEvaluation(by: evaluationID, databaseFileURL: databaseFileURL)
            if let evaluation {
                request = EvaluationCreateRequest(
                    consultoID: evaluation.consultoID,
                    patientID: evaluation.patientID,
                    structural: evaluation.structural ?? "",
                    cranioSacral: evaluation.cranioSacral ?? "",
                    akOrthodontic: evaluation.akOrthodontic ?? ""
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func save() async {
        isSaving = true
        errorMessage = nil
        do {
            try PatientRepository.updateEvaluation(request, id: evaluationID, databaseFileURL: databaseFileURL)
            dataChangeCoordinator.publishChange(.evaluationUpdated(evaluationID: evaluationID, consultoID: request.consultoID, databaseURL: databaseFileURL))
            saveSucceeded = true
            isSaving = false
        } catch {
            errorMessage = error.localizedDescription
            saveSucceeded = false
            isSaving = false
        }
    }

    func delete() async -> Bool {
        isDeleting = true
        errorMessage = nil
        do {
            try PatientRepository.deleteEvaluation(id: evaluationID, databaseFileURL: databaseFileURL)
            if let evaluation {
                dataChangeCoordinator.publishChange(.evaluationDeleted(evaluationID: evaluationID, consultoID: evaluation.consultoID, databaseURL: databaseFileURL))
            }
            isDeleting = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isDeleting = false
            return false
        }
    }
}

@MainActor final class ExamCreateViewModel: ObservableObject {
    let consultoID: Int
    let patientID: Int
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator
    @Published var request: ExamCreateRequest
    @Published var types: [ExamType] = []
    @Published var errorMessage: String?
    @Published var isSubmitting = false

    init(consultoID: Int, patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator) {
        self.consultoID = consultoID
        self.patientID = patientID
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator
        request = ExamCreateRequest(consultoID: consultoID, patientID: patientID)
        do {
            types = try PatientRepository.fetchExamTypes(databaseFileURL: databaseFileURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submit() async -> Bool {
        isSubmitting = true
        do {
            let examID = try PatientRepository.createExam(request, databaseFileURL: databaseFileURL)
            dataChangeCoordinator.publishChange(.examCreated(examID: examID, consultoID: consultoID, databaseURL: databaseFileURL))
            isSubmitting = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
            return false
        }
    }
}

@MainActor final class ExamEditViewModel: ObservableObject {
    let examID: Int
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator
    
    @Published private(set) var exam: ExamDetail?
    @Published var request: ExamCreateRequest
    @Published var types: [ExamType] = []
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isDeleting = false
    @Published var showDeleteConfirmation = false
    @Published private(set) var saveSucceeded: Bool?

    init(examID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator) {
        self.examID = examID
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator
        request = ExamCreateRequest(consultoID: 0, patientID: 0)
        do {
            types = try PatientRepository.fetchExamTypes(databaseFileURL: databaseFileURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func load() async {
        isLoading = true
        do {
            exam = try PatientRepository.fetchExam(by: examID, databaseFileURL: databaseFileURL)
            if let exam {
                request = ExamCreateRequest(
                    consultoID: exam.consultoID,
                    patientID: exam.patientID,
                    date: exam.date ?? Date(),
                    typeID: exam.typeID,
                    description: exam.description ?? ""
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func save() async {
        isSaving = true
        errorMessage = nil
        do {
            try PatientRepository.updateExam(request, id: examID, databaseFileURL: databaseFileURL)
            dataChangeCoordinator.publishChange(.examUpdated(examID: examID, consultoID: request.consultoID, databaseURL: databaseFileURL))
            saveSucceeded = true
            isSaving = false
        } catch {
            errorMessage = error.localizedDescription
            saveSucceeded = false
            isSaving = false
        }
    }

    func delete() async -> Bool {
        isDeleting = true
        errorMessage = nil
        do {
            try PatientRepository.deleteExam(id: examID, databaseFileURL: databaseFileURL)
            if let exam {
                dataChangeCoordinator.publishChange(.examDeleted(examID: examID, consultoID: exam.consultoID, databaseURL: databaseFileURL))
            }
            isDeleting = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isDeleting = false
            return false
        }
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
    let patientID: Int
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator
    @Published var request: ConsultationCreateRequest
    @Published var errorMessage: String?
    @Published var isSubmitting = false

    init(patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator) {
        self.patientID = patientID
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator
        request = ConsultationCreateRequest(patientID: patientID)
    }

    func submit() async -> Bool {
        guard !request.initialProblem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Appointment reason is required"
            return false
        }
        isSubmitting = true
        do {
            let consultationID = try PatientRepository.createConsultation(request, databaseFileURL: databaseFileURL)
            dataChangeCoordinator.publishChange(.consultationCreated(consultationID: consultationID, patientID: patientID, databaseURL: databaseFileURL))
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
    let patientID: Int
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator
    @Published var request: RemoteHistoryCreateRequest
    @Published var types: [AnamnesisType] = []
    @Published var errorMessage: String?
    @Published var isSubmitting = false

    init(patientID: Int, databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator) {
        self.patientID = patientID
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator
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
            let historyID = try PatientRepository.createRemoteHistory(request, databaseFileURL: databaseFileURL)
            dataChangeCoordinator.publishChange(.remoteHistoryCreated(historyID: historyID, patientID: patientID, databaseURL: databaseFileURL))
            isSubmitting = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
            return false
        }
    }
}
