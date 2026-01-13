//
//  HandleNormalizer.swift
//  status sync app
//
//  Created by James Futhey on 1/14/26.
//

import Foundation

/// Normalize an iMessage/FaceTime handle (email or phone).
/// - Emails: trimmed, lowercased.
/// - Phones: keep leading '+', strip non-digits elsewhere.
func normalizeHandle(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }
    
    if trimmed.contains("@") {
        return trimmed.lowercased()
    }
    
    var result = ""
    for (idx, ch) in trimmed.enumerated() {
        if ch == "+" && idx == 0 {
            result.append(ch)
        } else if ch.isNumber {
            result.append(ch)
        }
    }
    return result
}
