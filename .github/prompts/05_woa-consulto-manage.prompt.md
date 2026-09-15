---
name: woa-consulto-manage
description: Use it to scaffold a view that allows the user to edit an existing consulto and to delete it.
---


## Request
Allow the user to view details of an existing consulto in the database. The view should display the consulto's attributes. The view should also allow the user to edit the consulto's details and delete the consulto from the database.

The request's criteria are the following:
1. User should browse all available information for the selected consulto, including all attributes and a list of related records if applicable such as `trattamenti`, `valutazioni`, and `esami`.
2. User should be able to access the related records for the selected consulto, such as `trattamenti`, `valutazioni`, and `esami` from the related list within the consulto detail view.
3. The view for these related records should display the relevant information for each record in a clear and organized manner and should allow the user to interact with each record as needed: edit, delete, and view details.
4. Each list should should provide a button to add a new related record.
5. User should be able to edit the consulto's details and save the changes to the database.
6. User should be able to delete the consulto from the database, with a confirmation prompt before deletion.

## Features
- The consulto detail view should be accessible from the `PatientDetailView` of the main view of the application, and it should be presented as a separate view that can be dismissed to return to the main view.
- The consulto detail view is composed of the consulto's attributes. The consulto's main attributes should be displayed prominently at the top of the view.All the attributes should be displayed in a clear and organized manner, with labels for each attribute.
- Initially, the main consulto attributes are simply displayed as text, but the user can click an edit icon `✏️` to switch to an editable mode where they can modify the consulto's details. In editable mode, the user should be able to change the consulto's attributes. The user should be able to save the changes or cancel the edit operation. The edit mode should be equivalent to the "Add Consulto" view, but with pre-filled values for the selected consulto. The user should be able to save the changes or cancel the edit operation.
- A delete icon `🗑️` should be present in the consulto detail view. When the user clicks the delete icon, a confirmation prompt should appear to confirm the deletion. If the user confirms, the consulto should be deleted from the database.
- The same edit and delete functionality should be available for the related records within their respective lists.
- Each related record list should provide a button to add a new related record, which opens a form similar to the "Add Consulto" view but pre-filled with the current consulto's context.
- On adding or editing a related record, the corresponding view should be displayed within the main window. When the operation is completed, a message should be shown to inform the user of the result (use different types of messages for success and failure, such as a green checkmark for success and a red cross for failure). The messages should be clearly visible and distinguishable from other UI elements to ensure the user notices them. A button allows the user to navigate back to the main consulto detail view. The main consulto detail view should remain consistent and reflect any changes made to the related records. 


## Required Views
- A view that allows the user to display the details of an existing consulto in the database, including the consulto's attributes. The same view allows also the user to edit the consulto's details, delete the consulto from the database, and manage related records such as `trattamenti`, `valutazioni`, and `esami`.
- The `ConsultoPatientDetailView` contains the following sections or views:
  - A view to display the main consulto attributes in read-only mode
  - A view to edit the main consulto attributes
  - A view to display the related records section for `trattamenti`
  - A view to display the related records section for `valutazioni`
- A dedicated view for add each related record, such as `trattamenti`, `valutazioni`, and `esami`. These views are displayed into the main window.
- A dedicated view for editing and deleting each related record, such as `trattamenti`, `valutazioni`, and `esami`. These views are displayed into the main window.
