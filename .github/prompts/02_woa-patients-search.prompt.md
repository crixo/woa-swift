---
name: woa-patients-search
description: Use it to scaffold a view that allows the user to search for patients in the database and display their details.
---


## Context
The WOA Application must comply with the rules and guidelines defined at ./00_woa-architecture.prompt.md. That file also includes the main database schema of the application.

## Request
Allow the user to search for patients in the database and display their details.

The search criteria are the following:
1. the input text is matched against the `nome` and `cognome` fields of the `paziente` table
2. the input text is case-insensitive and can match any part of the `nome` or `cognome` fields
3. Search starts after the user has typed at least 3 characters in the search field

## Features
- From the DatabaseSelectionView, the user can navigate to the PatientsSearchView when the database is selected and connected.
- Text Search: A text field that allows the user to input a search query. The search query is matched against the `nome` and `cognome` fields of the `paziente` table.
- The search results are displayed in a list below the search field. Each result displays the `nome`, `cognome`, age(computed on the fly leveraging the `data_nascita` field), and address (combined from `indirizzo`, `citta`, and `provincia` fields).
- A counter that shows the number of search results found.
- A link to view the details of each patient. For now the link simply shows a popup with the patient's details, but in the future it will navigate to a dedicated patient details view.

## Required Views
- A view that allows the user to input a search query and displays the search results in a list. Each result displays the `nome`, `cognome`, age, and address of the patient. The view also includes a counter that shows the number of search results found.


## Constraints
Constraints:
- Maintain consistency with the architecture, naming conventions, and structure of the prompt file 00_woa-architecture.prompt.md
- Update only the necessary files
- Preserve the existing functionality of the application.
- If new models are needed, update the data model and migrations
- If new views are needed, maintain the existing style

## Required Output:
- Complete code for each file, no TODO placeholders.
- DB migrations (if necessary)
- All the generated code must be compatible with Xcode and the SwiftUI framework, and should be stored into the src directory at the root of the repository. 
- Note: propose changes to the prompt file if needed to support the new features.

## Current stack
SwiftUI, Swift, Vapor, Fluent, SQLite

