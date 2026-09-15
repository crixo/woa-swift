---
name: woa-anamnesi-remota-manage
description: Use it to scaffold a view that allows the user to edit an existing anamnesi remota and to delete it.
---


## Request
Allow the user to view details of an existing anamnesi remota in the database. The view should display the anamnesi remota's attributes. The view should also allow the user to edit the anamnesi remota's details and delete the anamnesi remota from the database.

The request's criteria are the following:
1. User should be able to access the anamnesi remota detail view from the `PatientDetailView` of the main view of the application.
2. User should browse all available information for the selected anamnesi remota.
3. User should be able to edit the anamnesi remota's details and save the changes to the database.
4. User should be able to delete the anamnesi remota from the database, with a confirmation prompt before deletion.

## Features
- The anamnesi remota detail view should be accessible from the `PatientDetailView` of the main view of the application, and it should be presented as a separate view that can be dismissed to return to the main view.
- The anamnesi remota detail view is composed of the anamnesi remota's attributes. The anamnesi remota's main attributes should be displayed prominently at the top of the view.All the attributes should be displayed in a clear and organized manner, with labels for each attribute.
- Initially, the main anamnesi remota attributes are simply displayed as text, but the user can click an edit icon `✏️` to switch to an editable mode where they can modify the anamnesi remota's details. In editable mode, the user should be able to change the anamnesi remota's attributes. The user should be able to save the changes or cancel the edit operation. The edit mode should be equivalent to the "Add Anamnesi Remota" view, but with pre-filled values for the selected anamnesi remota. The user should be able to save the changes or cancel the edit operation.
- A delete icon `🗑️` should be present in the anamnesi remota detail view. When the user clicks the delete icon, a confirmation prompt should appear to confirm the deletion. If the user confirms, the anamnesi remota should be deleted from the database.

## Required Views
- A view that allows the user to display the details of an existing anamnesi remota in the database, including the anamnesi remota's attributes. The same view allows also the user to edit the anamnesi remota's details and delete the anamnesi remota from the database. This view lives into its own file, separate from the `PatientDetailView`, following the 1:1 View/file rule.