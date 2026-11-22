# Application architecture

WOA is a macOS SwiftUI app with a single-window navigation experience. Feature
screens are destinations in the main view's typed `NavigationStack`.

## Layers

```text
View → ViewModel → Service → Repository → Storage
```

- **Views** present state and forward user actions.
- **ViewModels** own presentation state, validation state, and user flows.
- **Services** coordinate application operations such as configuration,
  migrations, and in-memory change notifications.
- **Repositories** own SQLite queries and mutations.
- **Storage utilities** centralize paths and low-level SQLite/file operations.

Not every operation currently has a separate service; some view models call
repositories directly. Keep SQL and persistence out of SwiftUI views and use
the closest established layer rather than adding unnecessary indirection.

## Navigation

[`MainView`](../src/WOA/Views/MainView.swift) owns the navigation path and the
shared `DataChangeCoordinator`. [`MainNavigationView`](../src/WOA/Views/MainNavigationView.swift)
uses a `NavigationStack` and the `Hashable` `NavigationRoute` enum. Routes carry
concrete IDs and database URLs. The toolbar provides Home and patient search;
the stack supplies back navigation.

Patient details link to consultations and remote history. Consultation details
link to treatments, evaluations, and exams. CRUD and settings views render
inline in the same navigation stack. Brief results and confirmations can use
transient presentations; these do not host feature-level navigation.

When adding a destination, extend the typed route and destination switch, and
use only `Hashable` payloads.

## Entity-change events

[`DataChangeCoordinator`](../src/WOA/Services/DataChangeCoordinator.swift)
broadcasts typed, in-memory events after successful mutations. Events include
the entity operation and IDs, plus the database URL. Subscribers filter by
entity scope and database identity so unrelated writes do not trigger reloads.
Patient and consultation details use these events to refresh data.

This event bus is not persistent history. Persistent entity audit records are
described in [Migrations and audit history](migrations.md).

## Shared forms

Components in [`src/WOA/SharedViews/`](../src/WOA/SharedViews/) provide shared
field presentation, add/edit/detail templates, date controls, action bars,
responsive headers, and save-result presentation. `FormValidators` in
[`src/WOA/Utils/`](../src/WOA/Utils/) provides validation helpers. Feature
views compose these components; entity rules belong in view models.

## SQLite and auditing

The reference schema is [`data/woa-schema.sql`](../data/woa-schema.sql).
Patient records (`paziente`) relate to consultations (`consulto`) and remote
history (`anamnesi_remota`); consultations are associated with treatments,
evaluations, and exams.

The [`woa_auditing` migration](../data/migrations/001_create-auditing-table.sql)
creates indexed change metadata. `PatientRepository` records the entity change
and audit row within the same transaction. `AuditRepository` queries the most
recent patient changes across supported related entities. The preference
`lastModifiedPatientsLimit` defaults to 5 when absent or invalid. Audit rows do
not contain before/after field values. The `woa_migration` ledger is separate.

See [Migrations and audit history](migrations.md) for the schema and runtime
behavior.
