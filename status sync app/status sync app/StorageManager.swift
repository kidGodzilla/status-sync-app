//
//  StorageManager.swift
//  status sync app
//
//  Created by James Futhey on 1/14/26.
//

import Foundation
import Combine

class StorageManager: ObservableObject {
    private let settingsKey = "com.jamesfuthey.status-sync-app.settings"
    
    @Published var settings: AppSettings
    
    init() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = AppSettings.default
            save()
        }
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }
    
    func addPeer(_ peer: Peer) {
        settings.peers.append(peer)
        save()
    }
    
    func updatePeer(_ peer: Peer) {
        if let index = settings.peers.firstIndex(where: { $0.peerUserId == peer.peerUserId }) {
            settings.peers[index] = peer
            save()
        }
    }
    
    func removePeer(_ peerUserId: String) {
        settings.peers.removeAll { $0.peerUserId == peerUserId }
        save()
    }
}
