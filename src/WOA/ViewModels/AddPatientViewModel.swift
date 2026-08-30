import Foundation

/// ViewModel managing the add patient form state, validation, and submission.
/// Handles real-time validation as user types and orchestrates the patient creation flow.
@MainActor final class AddPatientViewModel: ObservableObject {
    let databaseFileURL: URL
    
    @Published var formData: PatientCreateRequest = .init()
    @Published var selectedProvince: LookupProvince?
    @Published var allProvinces: [LookupProvince] = []
    @Published var isSubmitting: Bool = false
    @Published var validationErrors: [String: String] = [:]
    @Published var globalErrorMessage: String?
    @Published var didSubmitSuccessfully: Bool = false
    
    init(databaseFileURL: URL) {
        self.databaseFileURL = databaseFileURL
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
    
    /// Validates all required fields before form submission.
    /// Populates validationErrors dict; returns true if form is valid.
    private func validateAllFields() -> Bool {
        validationErrors = [:]
        
        // Validate nome
        if let error = validateField("nome") {
            validationErrors["nome"] = error
        }
        
        // Validate cognome
        if let error = validateField("cognome") {
            validationErrors["cognome"] = error
        }
        
        // Validate prov (required for submission)
        if formData.prov == nil || formData.prov?.isEmpty ?? true {
            validationErrors["prov"] = "Province is required"
        }
        
        // Validate data_nascita
        if let error = validateField("data_nascita") {
            validationErrors["data_nascita"] = error
        }
        
        return validationErrors.isEmpty
    }
    
    // MARK: - Submission
    
    /// Orchestrates form submission: validates all fields, then creates patient in DB.
    /// On success, sets didSubmitSuccessfully (triggers alert and dismissal).
    /// On error, sets globalErrorMessage (form remains open).
    func submitForm() async {
        // First validate all fields
        guard validateAllFields() else {
            return
        }
        
        isSubmitting = true
        globalErrorMessage = nil
        
        do {
            _ = try PatientRepository.createPatient(formData, databaseFileURL: databaseFileURL)
            didSubmitSuccessfully = true
        } catch {
            AppLogger.error("❌ Failed to add patient: \(error.localizedDescription)")
            globalErrorMessage = error.localizedDescription
        }
        
        isSubmitting = false
    }
}
