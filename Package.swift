// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WOATesting",
    platforms: [.macOS(.v14)],
    products: [],
    targets: [
        .target(
            name: "WOARegressionSubject",
            path: "src/WOA",
            exclude: [
                "DesignSystem",
                "Resources",
                "Services",
                "SharedViews",
                "Views",
                "ViewModels",
                "WOA.swift",
                "Models/DatabaseMigration.swift",
                "Models/TableInfo.swift",
                "Repositories/DatabaseMigrationRepository.swift",
                "Repositories/TableRepository.swift",
                "Utils/AppPaths.swift",
                "Utils/DatabaseInstaller.swift",
                "Utils/DatabaseMigrator.swift",
                "Utils/DatabaseURLProvider.swift",
                "Utils/FormValidators.swift",
                "Utils/NullUtils.swift",
                "Utils/StringExtensions.swift"
            ],
            sources: [
                "Models/AppSettings.swift",
                "Models/DatabaseConnection.swift",
                "Models/PatientCreateRequest.swift",
                "Models/PatientDetail.swift",
                "Models/LookupProvince.swift",
                "Models/PatientSearchResult.swift",
                "Repositories/PatientRepository.swift",
                "Utils/AppLogger.swift",
                "Utils/DatabaseValidator.swift",
                "Utils/SQLiteConnection.swift"
            ],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "WOATests",
            dependencies: ["WOARegressionSubject"],
            path: "tests"
        )
    ]
)
