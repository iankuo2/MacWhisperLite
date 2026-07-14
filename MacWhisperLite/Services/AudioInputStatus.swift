//
//  AudioInputStatus.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-07-14.
//


import Foundation
import AVFoundation

struct AudioInputStatus {
    let hasInputDevice: Bool
    let isExternal: Bool
    let deviceName: String?
}

class AudioDeviceDetector {
    
    static func checkAudioInputStatus() -> AudioInputStatus {
        // 1. Fetch all available audio devices capable of recording
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown], 
            mediaType: .audio, 
            position: .unspecified
        )
        
        let devices = discoverySession.devices
        
        // 2. If the list is empty, there is absolutely no audio input device
        guard !devices.isEmpty else {
            return AudioInputStatus(hasInputDevice: false, isExternal: false, deviceName: nil)
        }
        
        // 3. Look for an external device
        // Built-in microphones usually contain "built-in" or match specific types, 
        // while USB/Bluetooth/Line-in devices are considered external.
        let externalDevice = devices.first { device in
            let type = device.deviceType
            return type != .builtInMicrophone
        }
        
        if let external = externalDevice {
            return AudioInputStatus(hasInputDevice: true, isExternal: true, deviceName: external.localizedName)
        } else {
            // Only built-in microphone is available
            let builtIn = devices.first
            return AudioInputStatus(hasInputDevice: true, isExternal: false, deviceName: builtIn?.localizedName)
        }
    }
}