# AI-assisted development journey

- `DB selector` inverted 2 calls that GHCP was not able to identify. Due to the inversion in sequence, validation was executed before assets were moved. Manual fix required

- `Add Patient` field validation was wrong leading to an inconsistent submit button validation that did not allow the submission. Manual intervention needed because of access issues.

- `Navigation refactor` all builds errors were fixed by GHCP. 

- `Patient detail` has been almost fully scaffolded by GHCP. It requires 2 manual interventions to fix the navigation and the validation of the form. The errors were shared in chat and fix was implemented in 2 steps. The navigation is not working as expected, and the validation is not consistent with the requirements. Manual intervention needed to fix these issues. I have added a refresh token to the patient detail view to force a reload of the data after a successful save. This is a temporary fix until we can implement a more robust state management solution.

- Refactoring for state management was successful in most parts, the only manual adjustments required were in the `Add Patient` view commenting out the PreviewProvider section to avoid build errors.

- `Manage consulto` required manual intervention to fix the sql statement composition and the list refresh after updates and additions. Two fixes but few effort and easy to resolve by GHCP.

- `Manage anamnesi remota`. No issue just an extra curly bracket that has been removed after Xcode build.

- Refactoring for responsivness required an additional prompt to finalize the initial request that was partially accomplished. The generate code was working, simply some views did not implemented the initial request

- Display settings in launch screen contained 1 bug fixed simply providing build error.

- Found a bug in the Patient View where the Picker Province did not retain the user selection. Bug has been fixed describing the issue at the first attempt

- Beautify plan has been executed succesfully requireing only 1 fix for the FS structure regarding the new file with designing facilities and 1 minimal fix for the code. The problem is that beuatify has been applied only to the launch page and the Navigation bar has been duplicated in that page. All other views have been updated with same minimal prompt and no code generated check. No errors occurred.