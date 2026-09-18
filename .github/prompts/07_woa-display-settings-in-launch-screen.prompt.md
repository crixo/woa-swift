---
name: woa-display-settings-in-launch-screen
description: Use it to scaffold a view that allows the user to view display settings in the launch screen.
---

## Request
Allow the user to view application settings within the launch screen of the application. The view should display the settings' attributes including the full path of the settings file. 

## Features
- The main view of the launch screen should display the application settings in a clear and organized manner. At the top of the settings view, the full path of the settings file should be displayed prominently. All the settings attributes should be displayed in a clear and organized manner, with labels for each attribute.
- The main view of the launch screen should display 2 views: the existing one listing the tables of the selected database that remains unchange and one for displaying the application settings.
- The 2 subviews should be displayed in the center of the launch screen, one on the left and the other on the right, with a clear separation between them.
- The "Re-select Database" currently displayed in navigatin bar should be moved under the table list and requires a confirmation prompt before re-selecting the database.

## Required Views
- A view named `ApplicationSettingsView` that allows the user to display the application settings in the launch screen of the application, including the full path of the settings file. 
- The existing `TableStatusView` allows also the user to re-select the database with a confirmation prompt.
- An explict `LaunchScreenView` should be created to host the 2 subviews, the `TableStatusView` and the new `ApplicationSettingsView`, and to manage their layout in the launch screen.

## Guidelines
- Use always `AGENTS.md` file to provide instructions to the agents for generating code.
- Use always `.github/copilot-instructions.md` file to provide instructions to GitHub Copilot for generating code.
- Do not forget to use the appropriate instruction files in the `.github/instructions/` folder.