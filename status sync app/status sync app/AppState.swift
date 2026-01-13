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
    
    let storage: StorageManager
    private var apiClient: APIClient
    let presenceMonitor: PresenceMonitor
    private var updateTimer: Timer?
    private var pollTimer: Timer?
    
    init(storage: StorageManager) {
        self.storage = storage
        self.settings = storage.settings
        self.apiClient = APIClient(baseURL: settings.serverBaseURL)
        self.presenceMonitor = PresenceMonitor(thresholdSeconds: settings.presenceThresholdSeconds)
        
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
        }
    }
    
    private func updateMyPresence() async {
        do {
            try await apiClient.updatePresence(
                userId: settings.myUserId,
                state: presenceMonitor.currentState
            )
            isOnline = true
        } catch {
            isOnline = false
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
        
        // Create request to peer
        Task {
            await createRequest(toUserId: peer.peerUserId)
        }
    }
    
    func removePeer(_ peerUserId: String) {
        storage.removePeer(peerUserId)
        settings = storage.settings
    }
}
