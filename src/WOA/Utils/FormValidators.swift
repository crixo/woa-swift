import SwiftUI
// MARK: - 1. Validation rules

/// A single validation rule for a value of type `Value`.
/// Returns an error message when invalid, `nil` when valid.
struct ValidationRule<Value> {
    let validate: (Value) -> String?
    init(_ validate: @escaping (Value) -> String?) { self.validate = validate }

    /// Generic escape hatch: `.check("Pick one") { $0 != nil }`
    static func check(_ message: String, _ isValid: @escaping (Value) -> Bool) -> ValidationRule {
        .init { isValid($0) ? nil : message }
    }
}

extension ValidationRule where Value == String {
    static func required(_ message: String = "This field is required") -> ValidationRule {
        .init { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? message : nil }
    }

    static func minLength(_ n: Int, message: String? = nil) -> ValidationRule {
        .init { $0.isEmpty || $0.count >= n ? nil : (message ?? "Must be at least \(n) characters") }
    }

    static func maxLength(_ n: Int, message: String? = nil) -> ValidationRule {
        .init { $0.count <= n ? nil : (message ?? "Must be at most \(n) characters") }
    }

    /// Empty strings pass; combine with `.required()` if the field is mandatory.
    static func matches(_ pattern: String, message: String) -> ValidationRule {
        .init { $0.isEmpty || $0.range(of: pattern, options: .regularExpression) != nil ? nil : message }
    }

    static func email(_ message: String = "Enter a valid email address") -> ValidationRule {
        .matches("^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$", message: message)
    }
}

// MARK: - 2. Validator (base class for the view's ViewModel)

enum ValidationTrigger {
    case onChange           // validate while typing
    case onSubmit           // validate only when the form is submitted
    case onChangeAndSubmit  // both

    var includesChange: Bool { self != .onSubmit }
}

/// Subclass this in your ViewModel (or hold it as a property and observe it).
/// The ViewModel owns the rules; `FormField` only asks "what error should I show for X?".
@MainActor
class FormValidator<ID: Hashable>: ObservableObject {
    @Published private(set) var errors: [ID: String] = [:]
    @Published private(set) var touched: Set<ID> = []
    @Published private(set) var submitAttempted = false

    let trigger: ValidationTrigger
    private var validators: [ID: () -> String?] = [:]

    init(trigger: ValidationTrigger = .onChangeAndSubmit) {
        self.trigger = trigger
    }

    /// Register a field. Rules run in order; the first failure wins.
    /// `value` is a closure so the validator always reads the current value.
    func register<V>(_ id: ID,
                     value: @escaping () -> V,
                     rules: [ValidationRule<V>]) {
        validators[id] = {
            let current = value()
            for rule in rules {
                if let message = rule.validate(current) { return message }
            }
            return nil
        }
    }

    /// Called by `FormField` whenever the field's value changes.
    func fieldDidChange(_ id: ID) {
        // Before the first submit, only react if the trigger includes typing.
        // After a failed submit, always re-validate so errors clear as the user fixes them.
        guard trigger.includesChange || submitAttempted else { return }
        touched.insert(id)
        validate(id)
    }

    func validate(_ id: ID) {
        errors[id] = validators[id]?()
    }

    /// Call on submit. Returns `true` if the whole form is valid.
    @discardableResult
    func validateAll() -> Bool {
        submitAttempted = true
        for id in validators.keys { validate(id) }
        for (id, message) in errors {
            AppLogger.warning("⚠️ Submit blocked. \(String(describing: id)): \(message)")

        }
        return errors.isEmpty
    }

    /// The error `FormField` should display (nil until touched or submitted).
    func error(for id: ID) -> String? {
        guard touched.contains(id) || submitAttempted else { return nil }
        return errors[id]
    }

    var isValid: Bool { validators.keys.allSatisfy { validators[$0]?() == nil } }

    func resetValidation() {
        errors = [:]
        touched = []
        submitAttempted = false
    }
}

// MARK: - Validator for ViewModels that hold a single model object
//
// The "hashtable" inside FormValidator is keyed by `ID: Hashable`.
// KeyPaths are Hashable, so the model's properties can be the IDs directly:
// no enum, and the compiler checks the field names.

@MainActor
class ModelFormValidator<Model>: FormValidator<PartialKeyPath<Model>> {
    private var modelProvider: (() -> Model)?

    /// Tell the validator how to read the CURRENT model.
    /// Call once in the ViewModel's init, after `super.init`.
    func bindModel(_ provider: @escaping () -> Model) {
        modelProvider = provider
    }

    /// Read a property of the current model (used by FormField to observe changes).
    func value<V>(_ keyPath: KeyPath<Model, V>) -> V {
        guard let model = modelProvider?() else {
            preconditionFailure("Call bindModel(_:) in the ViewModel's init")
        }
        return model[keyPath: keyPath]
    }

    /// Register a field by key path. The value is always read live from the model.
    func register<V>(_ keyPath: KeyPath<Model, V>, rules: [ValidationRule<V>]) {
        register(keyPath as PartialKeyPath<Model>,
                 value: { [unowned self] in self.value(keyPath) },
                 rules: rules)
    }
}

// MARK: - FormField convenience init: no `value:` needed, no separate ID type

extension FormField {
    @MainActor
    init<Model>(_ label: String,
                              field keyPath: KeyPath<Model, Value>,
                              form: ModelFormValidator<Model>,
                              isRequired: Bool = false,
                              boxed: Bool = true,
                              @ViewBuilder content: () -> Content)
    where ID == PartialKeyPath<Model>{
        self.init(label,
                  field: keyPath,
                  form: form,
                  value: form.value(keyPath),
                  isRequired: isRequired,
                  boxed: boxed,
                  content: content)
    }
}
