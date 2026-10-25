---
name: woa-auditing
description: Create an auditing system for the application to track and entities changes, including the modified entity, the timestamp of the change, and the type of change (create, added, update, delete).
---

## Request
Create an auditing system for the application to track and entities changes, including the modified entity, the timestamp of the change, and the type of change (create, added, update, delete). The auditing system should be able to log changes made to entities in the application.

## Features
- Store into a dedicated table named `woa_auditing` the following information for each change made to an entity:
  - The modified entity based on the related database table.
  - The entity `id` of the modified entity. If a table does not have an `id` column, use the primary key of the table as the entity identifier and/or the combination of the foreign keys that uniquely identify the entity.
  - The timestamp of the change
  - The type of change (create, added, update, delete)
- The number of last modified patients to be displayed in the `LastModifiedPatientsView` should be configurable through a constant in the code, with a default value of 5. The constant should be defined in a central location, such as a configuration file or a constants class, to allow for easy modification if needed.
- The new table must be part of the migrations process and should be also created a dedicated file into the `data\migrations` folder, named `{next-3-digit-number-000-pattern}_create-auditing-table.sql`. The migration file should include the necessary SQL statements to create the `woa_auditing` table with the required columns and constraints. The migration file should also include any necessary indexes to optimize query performance on the `woa_auditing` table.

## Required Views
- `LastModifiedPatientsView`: A sub-view in the main view that displays the last X modified patients, regardless of the modified entities or the type of change. The sub-view should simply display the last modified patients as full names and the timestamp of the change as `dd mmm yyyy`, without any additional information about the changes made to the entities.
- Add a button in `PatientSearchView` to show the last X modified patients.

## Restrictions
- Reduce as much as possible the impact of the auditing system on the exiting code and performance of the application. The auditing system should be designed to minimize any potential performance overhead, and should not significantly impact the overall performance of the application. The audinting system should be implemented in a way that is efficient and does not introduce any unnecessary complexity or overhead to the existing codebase. The auditing system should be designed to be as lightweight as possible, while still providing the necessary functionality to track changes made to entities in the application.
