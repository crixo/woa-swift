//
//  SaveResultState.swift
//  WOA
//
//  Created by Cristiano Degiorgis on 21/09/2026.
//

enum SaveResultState: Identifiable {
    case success
    case failure(String)

    var id: String {
        switch self {
        case .success:
            return "success"
        case .failure(let message):
            return "failure_\(message)"
        }
    }
}
