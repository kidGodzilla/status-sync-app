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
    var avatarData: Data?
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
    var myDisplayName: String
    var myHandle: String
    var myAvatarData: Data?
    var serverBaseURL: String
    var presenceThresholdSeconds: Int
    var pollIntervalSeconds: Int
    var peers: [Peer]
    var startAtLogin: Bool

    enum CodingKeys: String, CodingKey {
        case myUserId, myDisplayName, myHandle, myAvatarData
        case serverBaseURL, presenceThresholdSeconds, pollIntervalSeconds
        case peers
        case startAtLogin
    }

    init(
        myUserId: String,
        myDisplayName: String,
        myHandle: String,
        myAvatarData: Data?,
        serverBaseURL: String,
        presenceThresholdSeconds: Int,
        pollIntervalSeconds: Int,
        peers: [Peer],
        startAtLogin: Bool
    ) {
        self.myUserId = myUserId
        self.myDisplayName = myDisplayName
        self.myHandle = myHandle
        self.myAvatarData = myAvatarData
        self.serverBaseURL = serverBaseURL
        self.presenceThresholdSeconds = presenceThresholdSeconds
        self.pollIntervalSeconds = pollIntervalSeconds
        self.peers = peers
        self.startAtLogin = startAtLogin
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        myUserId = try c.decode(String.self, forKey: .myUserId)
        myDisplayName = try c.decode(String.self, forKey: .myDisplayName)
        myHandle = try c.decode(String.self, forKey: .myHandle)
        myAvatarData = try c.decodeIfPresent(Data.self, forKey: .myAvatarData)
        serverBaseURL = try c.decode(String.self, forKey: .serverBaseURL)
        presenceThresholdSeconds = try c.decode(Int.self, forKey: .presenceThresholdSeconds)
        pollIntervalSeconds = try c.decode(Int.self, forKey: .pollIntervalSeconds)
        peers = try c.decode([Peer].self, forKey: .peers)
        // Backward-compatible default for existing installs.
        startAtLogin = try c.decodeIfPresent(Bool.self, forKey: .startAtLogin) ?? false
    }
    
    static let `default` = AppSettings(
        myUserId: UUID().uuidString,
        myDisplayName: "",
        myHandle: "",
        myAvatarData: nil,
        serverBaseURL: "https://statussync.jamesfuthey.com",
        presenceThresholdSeconds: 120,
        pollIntervalSeconds: 30,
        peers: [],
        startAtLogin: false
    )
}
