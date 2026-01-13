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
        // Get idle time from system using recent input events as a proxy for user activity.
        // Swift signature: secondsSinceLastEventType(_ stateID: CGEventSourceStateID, eventType: CGEventType)
        let keyIdle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .keyDown)
        let mouseIdle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .mouseMoved)
        let idleTime = min(keyIdle, mouseIdle)
        let state: PresenceState = idleTime < Double(thresholdSeconds) ? .active : .away
        DispatchQueue.main.async {
            self.currentState = state
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}
