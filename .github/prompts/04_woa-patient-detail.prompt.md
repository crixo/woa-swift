---
name: woa-patient-detail
description: Use it to scaffold a view that allows the user to view details of an existing patient in the database. Details include the patient's attributes, as well as a list of the patient's appointments(consulti) and the overall health history(anamnesi remota). The view should also allow the user to edit the patient's details and delete the patient from the database.
---


## Request
Allow the user to view details of an existing patient in the database. The view should display the patient's attributes, as well as a list of the patient's appointments (consulti) and the overall health history (anamnesi remota). The view should also allow the user to edit the patient's details and delete the patient from the database.

The view criteria are the following:
1. User can view an existing patient by providing the patient's ID in the `paziente` table.
2. The view should display all available information for the selected patient.
3. The view should allow the user to edit the patient's details and save the changes to the database.
4. The view should allow the user to delete the patient from the database, with a confirmation prompt before deletion.
5. The view should display a list of the patient's appointments (consulti) with minimal details (date and appointment reason) and allow the user to view more details for each appointment with a separate view. From this view, the user should be able to add a new appointment for the patient.
6. The view should display the patient's overall health history (anamnesi remota) with minimal details (date and kind) and allow the user to view more details for each health issue with a separate view. From this view, the user should be able to add a new health issue to the patient's anamnesi remota.

## Features
- The patient detail view should be accessible from the main view of the application, and it should be presented as a separate view that can be dismissed to return to the main view.
- The patient detail view is composed of three main sections: the patient's attributes, the list of appointments (consulti), and the overall health history (anamnesi remota). All three sections should be collapsible to allow the user to focus on the section they are interested in.
- The patient name and surname should be displayed prominently at the top of the view, along with the patient's ID. Same for the patient's age and profession. The patient's attributes should be displayed in a clear and organized manner, with labels for each attribute.
- initially main patient attributes are simply displayed as text, but the user can click an edit icon `✏️` to switch to an editable mode where they can modify the patient's details. In editable mode, the user should be able to change the patient's name, surname, age, profession, and any other relevant attributes. The user should be able to save the changes or cancel the edit operation. The edit mode should be equivalent to the "Add Patient" view, but with pre-filled values for the selected patient. The user should be able to save the changes or cancel the edit operation.

## Required Views
- A view that allows the user to display the details of an existing patient in the database, including the patient's attributes, a list of the patient's appointments (consulti), and the overall health history (anamnesi remota).