# Application architecture and shared UI behavior

WOA is a macOS desktop SwiftUI app with a single main-window navigation
experience. Features are shown inline in the root navigation stack rather than
opened as separate feature windows.

## Layers and responsibilities

The intended flow is:

```text
View → ViewModel → Service → Repository → Storage
```

- **Views** render state, collect input, and send user actions to view models.
- **ViewModels** own presentation state, validation state, and asynchronous
  user flows. They call services or repositories and expose results to views.
- **Services** coordinate application-wide business operations such as
  database connection, migrations, configuration, and in-memory change events.
- **Repositories** own SQLite queries and mutations. For example,
  [`PatientRepository`](../src/WOA/Repositories/PatientRepository.swift)
  handles patient and related entity queries and writes.
- **Storage utilities** centralize paths and low-level file/SQLite operations;
  for example, [`AppPaths`](../src/WOA/Utils/AppPaths.swift) and
  [`SQLiteConnection`](../src/WOA/Utils/SQLiteConnection.swift).

Not every operation currently has a separate service: some view models call
repositories directly. Keep SQL and persistence out of SwiftUI views, and use
the established layer closest to the operation instead of adding unnecessary
indirection.

## Main navigation

[`MainView`](../src/WOA/Views/MainView.swift) owns the database management
state, a single `DataChangeCoordinator`, and the typed route path.
[`MainNavigationView`](../src/WOA/Views/MainNavigationView.swift) hosts one
`NavigationStack` using the `Hashable` `NavigationRoute` enum.

Routes carry concrete payloads such as entity IDs and database URLs. The root
toolbar provides **Home** and **Patients Search**; the native navigation stack
provides back navigation for pushed destinations. Patient details link to
consultations and remote history; consultation details link to treatments,
evaluations, and exams. Create/edit/detail screens are destinations in the
same stack.

Short-lived interactions may use transient presentations: for example, CRUD
save results use a sheet, and destructive actions use a confirmation dialog.
These are not feature-level navigation destinations.

When adding a destination, extend the typed route enum and its destination
switch, carry only `Hashable` payloads, and keep navigation callbacks focused
on changing the route path.

## Entity-change notifications and refreshes

[`DataChangeCoordinator`](../src/WOA/Services/DataChangeCoordinator.swift) is
an in-memory publisher of typed `DataChangeEvent` values. Events identify the
operation, entity IDs, related parent IDs where relevant, and the database URL.
Mutation view models publish after successful database writes. Subscribers use
`AsyncStream` and filter on both entity scope and database identity, so a write
to another patient or another configured database does not cause unrelated
views to reload.

Patient and consultation detail view models subscribe to their relevant event
scopes and reload affected details or child lists. Navigation callbacks remain
for route changes; they are not the refresh mechanism. This event bus is
runtime-only and is distinct from the persistent audit records described in
[Database migrations and audit history](migrations.md).

When adding a mutation, publish only after persistence succeeds, include the
correct database and parent identifiers, and update the matching subscription
filter if a new event must refresh a detail view. Do not treat these
notifications as a persistent change log.

## Shared forms and validation

Form behavior is shared through components under
[`src/WOA/SharedViews`](../src/WOA/SharedViews/):

- [`FormField`](../src/WOA/SharedViews/FormField.swift) decorates a caller's
  control with a label, required marker, shared styling, and field-level errors.
- [`FormValidators`](../src/WOA/Utils/FormValidators.swift) provides reusable
  rules, `FormValidator`, and `ModelFormValidator`; validation rules are owned
  by the view model and fields identify model properties with key paths.
- [`EntityAddTemplate`](../src/WOA/SharedViews/EntityAddTemplate.swift),
  [`EntityEditTemplate`](../src/WOA/SharedViews/EntityEditTemplate.swift), and
  [`EntityDetailEditTemplate`](../src/WOA/SharedViews/EntityDetailEditTemplate.swift)
  standardize add, edit, and detail/edit presentation and actions.
- Shared date controls, action bars, responsive headers, and save-result
  components provide consistent behavior for common field types and outcomes.

Feature views compose the appropriate template and define entity-specific
fields. Keep field validation rules in the view model, use `FormField` for
consistent input presentation, and avoid reimplementing common CRUD layout or
save-result behavior in each feature.

## SQLite data model and auditing

The reference schema is [`data/woa-schema.sql`](../data/woa-schema.sql).
Patients (`paziente`) have consultations (`consulto`) and remote histories
(`anamnesi_remota`); consultations are associated with treatments, evaluations,
and exams. Lookup tables provide values such as provinces and history types.

The [`woa_auditing` migration](../data/migrations/001_create-auditing-table.sql)
creates an indexed record of the entity table, entity ID,
timestamp, and change type. Repository mutation transactions write the entity
change and audit record together. `AuditRepository` also queries the most
recent patient changes across supported related entities; the display limit
comes from `AppSettings.AppConstants.lastModifiedPatientsLimit` (currently 5).
This is metadata about a change, not a before/after snapshot of field values.
The migration ledger (`woa_migration`) is separate from this entity audit table.

See [Database migrations and audit history](migrations.md) for ledger behavior,
the migration authoring process, and the audit table's schema.

## Views

### Preview
Database used for preview is located at `~/Library/Containers/com.woa.application/Data/tmp/woa-preview.db`
