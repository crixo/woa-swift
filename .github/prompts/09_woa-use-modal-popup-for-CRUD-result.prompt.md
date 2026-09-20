---
name: woa-use-modal-popup-for-CRUD-result
description: Use modal popups to display the result of CRUD operations in the application, including success and error messages.
---

## Request
After performing a CRUD operation (Create, Read, Update, Delete) in the application, display the result of the operation in a modal popup. The modal popup should provide clear feedback to the user regarding the success or failure of the operation.

## Features
- After performing a CRUD operation, a modal popup should appear to inform the user of the result.
- The modal popup should display a success message if the operation was successful, or an error message if the operation failed.
- The modal popup should include a button to dismiss the popup and return to the previous view if the operation was successful, or to stay on the current view if the operation failed.
- In case of an error, the modal popup should the minimal error message if that help the user to understand what went wrong and how to fix it. The long message should instead be logged in the console and/or in a log file for debugging purposes.
- In case of error the modal popup should use the purple as color to indicate the error state, while in case of success it should use the green color to indicate the success state. Use background color or text color to indicate the state, but avoid using both at the same time to prevent visual clutter.

## Required Views
- Remove current views that display the result of CRUD operations and replace them with a modal popup view. Use modal popups to display the result of CRUD operations in the application, including success and error messages.

## Restrictions
- Execute this request only for the following views: `ExamDetailEditView`.