# AI-assisted development journey

- `DB selector` inverted 2 calls that GHCP was not able to identify. Due to the inversion in sequence, validation was executed before assets were moved. Manual fix required

- `Add Patient` field validation was wrong leading to an inconsistent submit button validation that did not allow the submission. Manual intervention needed because of access issues.

- `Navigation refactor` all builds errors were fixed by GHCP. 

- `Patient detail` has been almost fully scaffolded by GHCP. It requires 2 manual interventions to fix the navigation and the validation of the form. The errors were shared in chat and fix was implemented in 2 steps. The navigation is not working as expected, and the validation is not consistent with the requirements. Manual intervention needed to fix these issues. I have added a refresh token to the patient detail view to force a reload of the data after a successful save. This is a temporary fix until we can implement a more robust state management solution.

- Refactoring for state management was successful in most parts, the only manual adjustments required were in the `Add Patient` view commenting out the PreviewProvider section to avoid build errors.