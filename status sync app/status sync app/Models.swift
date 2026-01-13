//
//  Models.swift
//  status sync app
//
//  Created by James Futhey on 1/14/26.
//

import Foundation

struct Peer: Codable, Identifiable {
    var id: String { peerUserId }
    let peerUserId: String
    var displayName: String
    var handle: String // email or phone for iMessage/FaceTime
    var capabilityToken: String?
    var lastKnownPresence: PeerPresence?
    
    struct PeerPresence: Codable {
        let state: PresenceState
        let device: String
        let timestamp: Int64
    }
}

enum PresenceState: String, Codable {
    case active
    case away
    case asleep
}

struct PresenceRequest: Codable, Identifiable {
    let id: String
    let from: String
    let to: String
    let createdAt: Int64
    let expiresAt: Int64
    let status: String
}

struct AppSettings: Codable {
    var myUserId: String
    var serverBaseURL: String
    var presenceThresholdSeconds: Int
    var pollIntervalSeconds: Int
    var peers: [Peer]
    
    static let `default` = AppSettings(
        myUserId: UUID().uuidString,
        serverBaseURL: "https://statussync.jamesfuthey.com/",
        presenceThresholdSeconds: 120,
        pollIntervalSeconds: 30,
        peers: []
    )
}
