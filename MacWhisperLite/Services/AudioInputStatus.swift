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
        // Query the system's active audio input devices
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        )
        
        let devices = discoverySession.devices
        
        guard !devices.isEmpty else {
            return AudioInputStatus(hasInputDevice: false, isExternal: false, deviceName: nil)
        }
        
        let externalDevice = devices.first { device in
            return device.deviceType != .builtInMicrophone
        }
        
        if let external = externalDevice {
            return AudioInputStatus(hasInputDevice: true, isExternal: true, deviceName: external.localizedName)
        } else {
            let builtIn = devices.first
            return AudioInputStatus(hasInputDevice: true, isExternal: false, deviceName: builtIn?.localizedName)
        }
    }
}
