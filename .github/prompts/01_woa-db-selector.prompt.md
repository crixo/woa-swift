---
name: woa-db-selector
description: Use it to scaffold the database selector allowing the user to identify the DB to be copied within the application container space.
---

<!-- Tip: Use /create-prompt in chat to generate content with agent assistance -->
## Context
The WOA Application must comply with the rules and guidelines defined at ./00_woa-architecture.prompt.md. That file also includes the main database schema of the application.

## Request
Allow the user to select a SQLite database file from his home directory to have the WOA application copy it into the `Application Container` space as described by project architecture guidelines.

## Features
- Database Selection: 
If the database connection setting has not been configured, the starting page should provide a UI component to select the database file, copy it and store into a Sandbox-friendly location and configure the connection settings. If the database connection setting has been configured, the starting page should provide a UI component to test the connection to the database and display the connection status.
The connections status includes the list of all table with the number of records present in each of them in the manner of:
```
- paziente (100)
- consulto (332)
...
```
- Display settings: A starting page that provides a list of all configuration settings including the database connection settings, logging settings, and any other relevant application settings.

## Required Views
- A that allow to list all configuration settings and should be available for the entire application lifecycle as entry page

- A view to show the list and record count of each table. This view is a one-time show as result of the succesful database selection process.

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

