import Foundation

/// ViewModel managing the add patient form state, validation, and submission.
/// Handles real-time validation as user types and orchestrates the patient creation flow.
@MainActor final class PazienteAddViewModel: ModelFormValidator<PatientCreateRequest>, EntityAddViewModel {
    let databaseFileURL: URL
    let dataChangeCoordinator: DataChangeCoordinator
    
    @Published var formData: PatientCreateRequest = .init()
    @Published var selectedProvince: LookupProvince?
    @Published var allProvinces: [LookupProvince] = []
    var hasRealValidationErrors: Bool {
        let res = validationErrors.values.contains { !$0.isEmpty }
        return res
    }
    @Published var validationErrors: [String: String] = [:]
    @Published var didSubmitSuccessfully: Bool = false
    
    @Published var errorMessage: String?
    @Published var shortErrorMessage: String?
    @Published var isSaving = false
    
    
    init(databaseFileURL: URL, dataChangeCoordinator: DataChangeCoordinator) {
        self.databaseFileURL = databaseFileURL
        self.dataChangeCoordinator = dataChangeCoordinator

        super.init(trigger: .onChangeAndSubmit)
        
        bindModel { [unowned self] in self.formData }
        register(\.nome, value: { [weak self] in self?.formData.nome ?? "" },
                 rules: [.required("Nome è richiesto"), .minLength(2)])
        
        register(\.cognome, value: { [weak self] in self?.formData.cognome ?? "" },
                 rules: [.required("Cognome è richiesto"), .minLength(2)])
        
        register(\.email, value: { [weak self] in self?.formData.email ?? "" },
                 rules: [.email()])//.required(),
        
        Task {
            await loadProvinces()
        }
        
    }
    // MARK: - Loading
    
    /// Loads all provinces from the database for the dropdown.
    /// Called on ViewModel initialization.
    func loadProvinces() async {
        do {
            allProvinces = try PatientRepository.fetchProvinces(databaseFileURL: databaseFileURL)
        } catch {
            AppLogger.error("Failed to load provinces: \(error.localizedDescription)")
            allProvinces = []
        }
    }
    
    // MARK: - Validation
    
    /// Validates a single field and returns an error message if invalid, or nil if valid.
    /// Called via onChange on TextFields for real-time validation.
    func validateField(_ fieldName: String) -> String? {
        switch fieldName {
        case "nome":
            if formData.nome.isEmpty {
                return "First name is required"
            }
            if formData.nome.count < 2 {
                return "First name must be at least 2 characters"
            }
            return nil
            
        case "cognome":
            if formData.cognome.isEmpty {
                return "Last name is required"
            }
            if formData.cognome.count < 2 {
                return "Last name must be at least 2 characters"
            }
            return nil
            
        case "data_nascita":
            if let date = formData.data_nascita {
                if date > Date() {
                    return "Date of birth cannot be in the future"
                }
            }
            return nil
            
        case "prov":
            // Only validated during submit, not on onChange
            return nil
            
        default:
            return nil
        }
    }
    
    
    // MARK: - Submission
    
    /// Orchestrates form submission: validates all fields, then creates patient in DB.
    /// On success, sets didSubmitSuccessfully (triggers alert and dismissal).
    /// On error, sets globalErrorMessage (form remains open).
    func save() async -> Bool {
        // First validate all fields
//        guard validateAllFields() else {
//            return false
//        }
        guard validateAll() else { return false}
//
        isSaving = true
        errorMessage = nil
        
        do {
            let patientID = try PatientRepository.createPatient(formData, databaseFileURL: databaseFileURL)
            dataChangeCoordinator.publishChange(.patientCreated(patientID: patientID, databaseURL: databaseFileURL))
            didSubmitSuccessfully = true
            isSaving = false
            return true
        } catch {
            AppLogger.error("❌ Failed to add patient: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }
}
