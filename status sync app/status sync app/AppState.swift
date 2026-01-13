//
//  AppState.swift
//  status sync app
//
//  Created by James Futhey on 1/14/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var settings: AppSettings
    @Published var incomingRequests: [PresenceRequest] = []
    @Published var isOnline: Bool = true
    
    var profileNeedsSetup: Bool {
        settings.myDisplayName.isEmpty || settings.myHandle.isEmpty
    }
    
    let storage: StorageManager
    private var apiClient: APIClient
    let presenceMonitor: PresenceMonitor
    private var updateTimer: Timer?
    private var pollTimer: Timer?
    private var lastOnlineSuccess: Date? = Date()
    
    init(storage: StorageManager) {
        self.storage = storage
        self.settings = storage.settings
        let serverURL = storage.settings.serverBaseURL
        let threshold = storage.settings.presenceThresholdSeconds
        self.apiClient = APIClient(baseURL: serverURL)
        self.presenceMonitor = PresenceMonitor(thresholdSeconds: threshold)
        
        startTimers()
    }
    
    func updateSettings() {
        settings = storage.settings
        apiClient = APIClient(baseURL: settings.serverBaseURL)
        presenceMonitor.updateThreshold(settings.presenceThresholdSeconds)
        startTimers()
    }
    
    private func startTimers() {
        updateTimer?.invalidate()
        pollTimer?.invalidate()
        
        // Update presence every 30 seconds
        updateTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(settings.pollIntervalSeconds), repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.updateMyPresence()
            }
        }
        
        // Poll for requests and tokens every 30 seconds
        pollTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(settings.pollIntervalSeconds), repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.pollInbox()
            }
        }
        
        // Initial updates
        Task {
            await updateMyPresence()
            await pollInbox()
            
            // Sync profile to server on startup (if profile is set up)
            if !settings.myDisplayName.isEmpty || !settings.myHandle.isEmpty {
                syncMyProfileToServer()
            }
        }
        
        // Sync profile periodically (every 5 minutes) to keep server updated
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, !self.settings.myDisplayName.isEmpty || !self.settings.myHandle.isEmpty else { return }
                self.syncMyProfileToServer()
            }
        }
    }
    
    private func updateMyPresence() async {
        do {
            try await apiClient.updatePresence(
                userId: settings.myUserId,
                state: presenceMonitor.currentState
            )
            lastOnlineSuccess = Date()
            isOnline = true
        } catch {
            if let last = lastOnlineSuccess {
                let cutoff = last.addingTimeInterval(TimeInterval(settings.pollIntervalSeconds * 2))
                if Date() > cutoff {
                    isOnline = false
                }
            } else {
                isOnline = false
            }
        }
    }
    
    private func pollInbox() async {
        // Poll requests
        do {
            let requests = try await apiClient.getRequestsInbox(userId: settings.myUserId)
            incomingRequests = requests.filter { $0.status == "pending" }
        } catch {
            // Quiet error handling
        }
        
        // Poll tokens
        do {
            let tokens = try await apiClient.getTokensInbox(userId: settings.myUserId)
            for token in tokens {
                // Find peer by 'from' user_id and update capability token
                if let index = settings.peers.firstIndex(where: { $0.peerUserId == token.from }) {
                    var peer = settings.peers[index]
                    peer.capabilityToken = token.token
                    storage.updatePeer(peer)
                    settings.peers[index] = peer
                    
                    // Acknowledge token
                    try? await apiClient.ackToken(userId: settings.myUserId, token: token.token)
                }
            }
        } catch {
            // Quiet error handling
        }
        
        // Poll peer presence for peers with tokens
        for peer in settings.peers {
            guard let token = peer.capabilityToken else { continue }
            await pollPeerPresence(peer: peer, token: token)
        }
        
        // Poll peer profiles for all contacts
        for peer in settings.peers {
            await fetchPeerProfile(peerUserId: peer.peerUserId)
        }
    }
    
    private func pollPeerPresence(peer: Peer, token: String) async {
        do {
            if let presence = try await apiClient.getPeerPresence(
                requesterUserId: settings.myUserId,
                targetUserId: peer.peerUserId,
                capabilityToken: token
            ) {
                if let index = settings.peers.firstIndex(where: { $0.peerUserId == peer.peerUserId }) {
                    var updatedPeer = settings.peers[index]
                    updatedPeer.lastKnownPresence = Peer.PeerPresence(
                        state: PresenceState(rawValue: presence.state) ?? .away,
                        device: presence.device,
                        timestamp: presence.timestamp
                    )
                    storage.updatePeer(updatedPeer)
                    settings.peers[index] = updatedPeer
                }
            }
        } catch {
            // Quiet error handling
        }
    }
    
    func respondToRequest(_ request: PresenceRequest, decision: String) async {
        do {
            try await apiClient.respondToRequest(
                toUserId: settings.myUserId,
                requestId: request.id,
                decision: decision
            )
            await pollInbox()
        } catch {
            // Quiet error handling
        }
    }
    
    func createRequest(toUserId: String) async {
        do {
            try await apiClient.createRequest(
                fromUserId: settings.myUserId,
                toUserId: toUserId
            )
        } catch {
            // Quiet error handling
        }
    }
    
    func addPeer(_ peer: Peer) {
        storage.addPeer(peer)
        settings = storage.settings
        
        // Fetch profile from server
        Task {
            print("DEBUG: fetchPeerProfile start peer_id=\(peer.peerUserId)")
            await fetchPeerProfile(peerUserId: peer.peerUserId)
            // Create request to peer
            await createRequest(toUserId: peer.peerUserId)
        }
    }
    
    private func fetchPeerProfile(peerUserId: String) async {
        do {
            if let profile = try await apiClient.getProfile(userId: peerUserId) {
                if let index = settings.peers.firstIndex(where: { $0.peerUserId == peerUserId }) {
                    var updatedPeer = settings.peers[index]
                    updatedPeer.displayName = profile.displayName
                    updatedPeer.handle = profile.handle
                    if let avatarBase64 = profile.avatarData,
                       let avatarData = Data(base64Encoded: avatarBase64) {
                        updatedPeer.avatarData = avatarData
                    }
                    storage.updatePeer(updatedPeer)
                    settings.peers[index] = updatedPeer
                    print("DEBUG: fetchPeerProfile success peer_id=\(peerUserId) displayName=\(updatedPeer.displayName) handle=\(updatedPeer.handle)")
                } else {
                    print("DEBUG: fetchPeerProfile received profile but peer not found locally peer_id=\(peerUserId)")
                }
            } else {
                print("DEBUG: fetchPeerProfile returned nil profile peer_id=\(peerUserId)")
            }
        } catch {
            print("DEBUG: fetchPeerProfile error peer_id=\(peerUserId) error=\(error)")
        }
    }
    
    func syncMyProfileToServer() {
        print("DEBUG: syncMyProfileToServer CALLED user_id=\(settings.myUserId) displayName='\(settings.myDisplayName)' handle='\(settings.myHandle)'")
        Task {
            do {
                print("DEBUG: syncMyProfileToServer starting API call...")
                try await apiClient.updateProfile(
                    userId: settings.myUserId,
                    displayName: settings.myDisplayName,
                    handle: settings.myHandle,
                    avatarData: settings.myAvatarData
                )
                print("DEBUG: syncMyProfileToServer SUCCESS user_id=\(settings.myUserId) displayName='\(settings.myDisplayName)' handle='\(settings.myHandle)'")
            } catch {
                print("DEBUG: syncMyProfileToServer ERROR user_id=\(settings.myUserId) error=\(error)")
            }
        }
    }
    
    func updatePeer(_ peer: Peer) {
        storage.updatePeer(peer)
        settings = storage.settings
    }
    
    func removePeer(_ peerUserId: String) {
        storage.removePeer(peerUserId)
        settings = storage.settings
    }
}
