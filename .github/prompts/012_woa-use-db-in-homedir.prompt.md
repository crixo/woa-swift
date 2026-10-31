---
name: woa-use-db-in-homedir
description: Allow the user to select a SQLite database file from his home directory and use it in the WOA application. 
---

## Request
Currently, the WOA application allows the user to select a SQLite database file from his home directory and copy it into the application support location. This is not ideal for users who want to use their own database file living in their home directory. The request is to allow the user to select a SQLite database file from his home directory and use it in the WOA application without copying it into the application support location.

## Features
- Allow the user to select a SQLite database file from his home directory and use it in the WOA application without copying it into the application support location.
- Do not change current UI behavior of selecting a database file and the process of mandatory selection of a database file. Same for the post selction process of showing the list and record count of each table and the ability of re-selecting a database file. IOW UI should remain the same, only the underlying process of using the database file should change.
- Maintain in the codebase also the current process of copying the database file into the application support location. Add a checkbox in the UI to allow the user to choose whether to copy the database file into the application support location or not. The default behavior should be to use the selected database file from the home directory without copying it into the application support location. The user should be able to change this behavior by checking the checkbox in the UI.
- As of now, the selected db file path should be stored in the application settings and should be used for the entire application lifecycle. The user should be able to change the selected db file path at any time by re-selecting a database file from his home directory or by changing the checkbox in the UI.

## Required Views
- Ui remains the same as it is now, the only change is the checkbox to allow the user to choose whether to copy the database file into the application support location or not. The default behavior should be to use the selected database file from the home directory without copying it into the application support location. The user should be able to change this behavior by checking the checkbox in the UI.


