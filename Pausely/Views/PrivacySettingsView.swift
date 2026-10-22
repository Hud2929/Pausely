import SwiftUI
import Combine
import FamilyControls


struct DeviceSession: Identifiable {
    let id: String
    let deviceName: String
    let location: String
    let lastActive: Date
    
    static var current: DeviceSession {
        DeviceSession(
            id: "current",
            deviceName: UIDevice.current.name,
            location: "Current Location",
            lastActive: Date()
        )
    }
}


