---
name: woa-patient-add
description: Use it to scaffold a view that allows the user to add a new patient to the database.
---


## Request
Allow the user to add a new patient to the database.

The add criteria are the following:
1. User can add a new patient by providing `nome`, `cognome`, `professione`, `indirizzo`, `citta`, `telefono`, `cellulare`, `prov`, `cap`, `email`, and `data_nascita` in the `paziente` table.
2. `nome` and `cognome` are required fields, while the other fields are optional.


## Features
- The PatientsSearchView should have a button to navigate to the AddPatientView.
- The `prov` field should be a dropdown list populated with the table `lkp_provincia` in the database.
- The `data_nascita` field should be a date picker but should also allow the user to input the date manually in the format `dd/MM/yyyy`.
- After the user submits the form, the new patient should be added to the database and the user should be navigated back to the PatientsSearchView with a success message displayed or an error message if the operation fails and the user should remain on the AddPatientView.

## Required Views
- A view that allows the user to add a new patient to the database, with the required fields and validation as specified above.

