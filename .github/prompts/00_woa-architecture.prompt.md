---
name: woa-architecture
description: Use it to scaffold the swift application for the WOA project. This file describes the overall project. It contains data model description and guidelines to build application's features. 
---

<!-- Tip: Use /create-prompt in chat to generate content with agent assistance -->
## Project Overview
The WOA project is a desktop application designed for physical therapists to manage patient records.  The application will be built using SwiftUI and targeted for macOS platforms. The application will allow therapists to add, edit, and view patient records, including personal information, medical history, and treatment plans.

## Features
This file does not contain any specific feature, but will be referred by any future prompt file to drive the development of each feature.
The application features will be addressed using multiple prompt files one per each feature. 

## Data Models
`data/woa-schema.sql` contains the SQL schema for the SQLite database in use by WOA project, which defines the structure of the database and the relationships between entities. This schema will be the reference for future data models aimed to represent entities and their relationships. Use the SQL schema to build the data models and ensure that the scaffold reflects the structure defined in the SQL schema.
The WOA project will be a SwiftUI application targeted to desktop platforms that provides a user-friendly interface for a physical therapist to manage the database described within the SQL schema. The upcoming feature prompt file will link this architecture prompt and this schema will be the reference for any specific feature development. In case a feature requires to extend this schema, the related prompt file will provide the required additional schema.

## Shared Rules for All Feature Prompt Files
Any feature-specific prompt in this repository must inherit these rules unless a feature prompt explicitly overrides them.

### Shared Context and Compliance Rules
- The WOA Application must comply with the rules and guidelines defined in this architecture prompt.
- This prompt also defines the main database schema of the application.
- Feature prompts should be scoped to one feature only and should build on the architecture defined here.

### Shared Constraints
- Maintain consistency with the architecture, naming conventions, and structure of this architecture prompt.
- Update only the necessary files.
- Preserve the existing functionality of the application.
- Never validate, query, or migrate the user-selected source database in its original folder; always validate the copied file stored inside the Application Support sandbox.
- Ensure imported databases are normalized before validation: stale WAL sidecars and journal mode problems must be cleaned up on the copied sandbox database before table metadata is read.
- If new models are needed, update the data model and migrations.
- If new views are needed, maintain the existing style.
- Keep database initialization and import logic outside Views. Views may trigger the onboarding workflow but should not implement validation, import, migration, or persistence logic.
- Keep SQL queries in the repository layer and domain logic in the service/viewmodel layer.

### Shared Output Contract
- Complete code for each file, with no TODO placeholders.
- DB migrations if necessary.
- All generated code must be compatible with Xcode and the SwiftUI framework and should be stored into the `src` directory at the repository root.
- Note: propose changes to the prompt file if needed to support the new features.

### Current Stack
SwiftUI, Swift, SQLite, macOS desktop focus.

### Final Validation Checklist (Required in Output)
Before concluding, include this checklist and mark each item pass/fail:
- All required entities as described within the *Features* section implemented end-to-end
- No missing views/repositories/viewmodels for any required entity
- No unresolved TODO placeholders in required CRUD paths

This validation is required by each prompt file that requires a Feature implementation.

## Scaffold Requirements
Scaffold the app keep in mind the following requirements:
- The application should be built using SwiftUI
- Store the generated scaffold into the src directory at the root of the repository. Organize the scaffolding as a valid Xcode project with a clear and logical directory structure, including separate directories for views, models, controllers, and any other relevant components of the application.
- Skip testing and unit tests for now, but scaffold the project in a way that allows for easy addition of tests in the future.
- Target is **only** desktop platforms (macOS): do not scaffold for iOS or any other platforms.
- Give priority to code simplicity and maintainability by a developer with no previous experience with Swift language.
- Prefer following code simplicity and maintainability over best practices for Swift development.
- Setup a robust and human-readable logging system to log errors and important events within the application. The logging system should be easy to use and understand for a developer with no previous experience with Swift language. The log output should be the console in the Xcode IDE and also on file, and the log messages should be clear and informative, providing context about the events being logged.
- Application settings should be stored in a configuration file that should be in a human-readable format, use JSON, and should include settings for the database connection, logging, entity fields constraints, and any other relevant application settings.
- Make sure application sandboxing is properly configured to ensure that the application has the necessary permissions to access the database and any other required resources, while also adhering to macOS security guidelines. Describe the configuration of the sandboxing settings in the README file, including any necessary entitlements or permissions that need to be set for the application to function correctly.
- Keep all application related files organized in a clear and logical directory structure, with separate directories for views, models, controllers, and any other relevant components of the application. Describe how to maintain the directory structure generated by the scaffold during the import into Xcode, and how to add new files to the project while keeping the directory structure intact.
- Document each code file with comments explaining the purpose of the file and the functionality of the code within it. Add extra comments to explain the code logic and flow, especially for complex sections of code. Use special comments that could help a developer with no previous experience with Swift language to understand the code and its functionality.
- Make app's scaffold compatible with Xcode including any necessary project files or configurations to facilitate development within this IDE. README file must contain in a step-by-step manner any necessary instructions for setting up the project, with screenshots if necessary, to assist a developer with no previous experience with Swift language in setting up the project within Xcode.
- Create a script to build the app in Release mode and package it for distribution. Provide clear instructions in the README file on how to use the script to build and package the application including any neccessary dependencies or configurations, within Xcode or via terminal, required to run the script successfully.

While coding make sure to follow the following guidelines:
- **Never hide error messages or stack traces**, always log them to the console and to a log file while providing a user-friendly error message to the user.
- **Pointer safety:** Avoid unsafe C-string conversions; treat SQLite column pointers as optional and handle nils rather than calling `String(cString:)` directly on possibly-null pointers.
- **No iOS-specific code:** Keep platform guidance macOS-focused; remove or avoid iOS-only APIs in scaffolding and examples.
- **Consistent helper:** Use a single helper (e.g. `sqliteErrorString(_:)`) in examples to format errors and `errno` consistently across the codebase.
- **Sample log style:** `✅ Database connected: /Users/alice/Library/Application Support/WOA/woa.db` and `❌ SQL execution error: no such table: paziente`


## Database Initialization

Implement a first-run database onboarding flow.

### Requirements

- The application database is stored in:

```text
Application Support/<AppName>/database/application.db
```

- The application does not ship with a bundled database.
- On first run, if the internal database does not exist, require the user to select a SQLite database using `NSOpenPanel`.
- Validate the selected database before import.
- Copy the selected database into Application Support.
- Use the copied database as the application's working database.
- Run migrations after import if needed.
- Future runs must use only the internal database.
- Do not require the user to reselect the database.
- Do not continue using the external database after import.
- Keep the implementation App Sandbox compliant.

### Preferred Components

```text
DatabaseInstaller
DatabaseValidator
DatabaseMigrator
DatabaseURLProvider
```

Keep database initialization and import logic outside Views. Views may trigger the onboarding workflow but should not implement validation, import, migration, or persistence logic.