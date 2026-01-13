//
//  PresenceMonitor.swift
//  status sync app
//
//  Created by James Futhey on 1/14/26.
//

import Foundation
import CoreGraphics
import Combine

class PresenceMonitor: ObservableObject {
    @Published var currentState: PresenceState = .away
    private var timer: Timer?
    private let thresholdSeconds: Int
    
    init(thresholdSeconds: Int = 120) {
        self.thresholdSeconds = thresholdSeconds
        updateState()
        startMonitoring()
    }
    
    func updateThreshold(_ seconds: Int) {
        // Will restart with new threshold on next cycle
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateState()
        }
    }
    
    private func updateState() {
        let idleTime = CGEventSource.secondsSinceLastEventType(.combinedSessionState)
        let state: PresenceState = idleTime < Double(thresholdSeconds) ? .active : .away
        DispatchQueue.main.async {
            self.currentState = state
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}
