---
name: woa-refactor-folder-structure.prompt
description: Refactor the folder structure of the WOA project to prioritize functionalities over architectural patterns.
---
Refactor the project structure of  `/src/WOA`. 
Currently the structure follows the architecture strategy using Views, Model, ViewModels... folder approach. I want to invertet the current strategy giving priority to functionalities instead of architectural patterns for folder naming and organization. Files name will still follow the current architectural pattern, but the folders should be named around functionalities: business first and then also technical functionality if apply.
As result each folder eg. `Consulto` will contains all the related file for that functionality/Entitity/tecnicality
Update also docs and files in `.github` such as `copiloto-instructions.md` and any other instructions file with an opinion on this matter to have future generation implementing the new strategy

The files in `/src/WOA` itself should not be changed, only the folder structure and the related instructions files.

As part of the paln provide a list of the new folder structure and the files that will be contained in each folder. The output must be a tree structure. The new structure should be clear, logical, and easy to navigate for developers working on the project.

For docs and instructions files, provide a summary of the changes made and the rationale behind them. The plan should include the list of changes you are planning to make to the docs and instructions files, along with a brief explanation of why each change is necessary.