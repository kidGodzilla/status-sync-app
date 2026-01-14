//
//  LoginItemManager.swift
//  status sync app
//
//  Created by James Futhey on 1/14/26.
//

import Foundation
import ServiceManagement

@MainActor
final class LoginItemManager {
    static let shared = LoginItemManager()

    private init() {}

    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return false
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        guard #available(macOS 13.0, *) else { return }
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

