---
name: woa-edit-settings
description: Create a view to edit the application settings.
---

## Request
Allow the user to edit the application settings through a dedicated view. The view should provide an intuitive interface for modifying various configuration options and preferences within the application. The settings structure should be devide into two sections: editable and system settings. The editable settings should be modifiable by the user, while the system settings should be read-only and not editable by the user.

## Features
- Add a button in the main view to open the settings view.
- The settings view should display the editable settings in a user-friendly format, allowing users to modify the values as needed. The editable settings should be presented in a clear and organized manner, with appropriate labels and input fields for each setting. The user should be able to save the changes made to the editable settings, and the application should persist the updated values accordingly.
- The system settings should be displayed in a read-only format, providing users with information about the current configuration without allowing modifications. The system settings should be clearly distinguished from the editable settings, and users should be able to view the values without the ability to make changes. The system settings should be presented in a way that is easy to understand, with appropriate labels and descriptions for each setting.
- Add `lastModifiedPatientsLimit` setting to the editable settings, allowing users to configure the number of last modified patients to be displayed in the `LastModifiedPatientsView`. The default value for this setting should be 5, and users should be able to modify it as needed. The application should validate the input for this setting to ensure that it is a valid integer value, and should provide appropriate feedback if the input is invalid.

## Required Views
- `SettingsView`: A view for editing application settings. A button should be added in the main view to open the `SettingsView`. 

## Restrictions
- do not modify the existing code structure or introduce any breaking changes to the application. The settings view should be implemented in a way that is compatible with the existing codebase and does not disrupt the overall functionality of the application beside the adjustements required by the new settings structure.