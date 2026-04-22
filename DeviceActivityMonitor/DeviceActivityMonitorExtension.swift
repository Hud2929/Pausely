//
//  DeviceActivityMonitorExtension.swift
//  DeviceActivityMonitor
//
//  Screen Time API Extension for Pausely
//

import DeviceActivity
import FamilyControls

// MARK: - Device Activity Monitor Extension
// This extension is required by Apple to monitor device activity
// It runs in the background and receives callbacks when monitoring events fire
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        
        // Handle the start of the interval
        #if DEBUG
        print("📱 DeviceActivityMonitor: Interval started for \(activity)")
        #endif
        
        // You can perform actions here when the monitoring interval starts
        // For example: schedule local notifications, update app badges, etc.
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        
        // Handle the end of the interval
        #if DEBUG
        print("📱 DeviceActivityMonitor: Interval ended for \(activity)")
        #endif
        
        // Process the device activity data
        // This is where you would fetch usage data and update your app
    }
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        
        // Handle when a specific event threshold is reached
        #if DEBUG
        print("📱 DeviceActivityMonitor: Event threshold reached - \(event)")
        #endif
    }
    
    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
        
        // Handle warning before interval starts
        #if DEBUG
        print("📱 DeviceActivityMonitor: Interval will start warning for \(activity)")
        #endif
    }
    
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        
        // Handle warning before interval ends
        #if DEBUG
        print("📱 DeviceActivityMonitor: Interval will end warning for \(activity)")
        #endif
    }
    
    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        
        // Handle warning before event threshold is reached
        #if DEBUG
        print("📱 DeviceActivityMonitor: Event will reach threshold warning - \(event)")
        #endif
    }
}
