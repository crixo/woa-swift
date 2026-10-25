//
//  StringExtensions.swift
//  WOA
//
//  Created by Cristiano Degiorgis on 25/09/2026.
//

extension String {
    var firstLetterUppercased: String {
        prefix(1).uppercased() + dropFirst()
    }
}
