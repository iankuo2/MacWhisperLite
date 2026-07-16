//
//  TranscriptionViewModel.swift
//  MacWhisperLite
//
//  Modified by ian kuo on 2026-07-11
//

import Foundation
internal import Combine
import AVFAudio
import SwiftData
import AVFoundation

@MainActor
class TranscriptionViewModel: ObservableObject {
    
    private let whisper = WhisperService()
    private lazy var liveInputManager = LiveInputManager(whisperService: whisper)
    
    @Published var isTranscribing = false
    @Published var isLiveRecording = false
    @Published var transcript = ""
    @Published var selectedModel: WhisperModel = .tiny
    @Published var currentFileName: String = "Untitled Audio"
    @Published var selectedDevice: LiveAudioSource = .microphone
    
    @Published var alertMessage: String? = nil
    @Published var showAlert = false
    
    // Track whether a microphone is physically available right now
    @Published var hasMicrophoneConnected: Bool = false
    @Published var activeMicrophoneName: String = "No Microphone"
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Run an initial hardware check when the app launches
        refreshAudioHardware()
        
        // Connect the manager callback to our UI text publisher
        liveInputManager.onTextReceived = { [weak self] liveText in
            guard let self = self else { return }
            let cleanedText = liveText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanedText.isEmpty {
                self.transcript = cleanedText
            }
        }
        
        // 🚨 LISTEN TO HARDWARE PLUG/UNPLUG EVENTS
        NotificationCenter.default.publisher(for: AVCaptureDevice.wasConnectedNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshAudioHardware()
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: AVCaptureDevice.wasDisconnectedNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshAudioHardware()
            }
            .store(in: &cancellables)
    }
    
    /// Re-evaluates connected devices and updates published states for SwiftUI
    func refreshAudioHardware() {
        let status = AudioDeviceDetector.checkAudioInputStatus()
        self.hasMicrophoneConnected = status.hasInputDevice
        self.activeMicrophoneName = status.deviceName ?? "No Microphone"
        
        // If the mic was unplugged while we were recording, clean up gracefully
        if !status.hasInputDevice && isLiveRecording {
            liveInputManager.stopStreaming()
            isLiveRecording = false
            alertMessage = "Your microphone was unplugged. Live captioning has stopped."
            showAlert = true
        }
    }
    
    // Existing static file transcriber
    func transcribe(url: URL, context: ModelContext) async {
        isTranscribing = true
        transcript = "" // Clear canvas for live streaming updates
        
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let totalDuration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
            
            let segmentDuration: TimeInterval = 30.0 // 30-second sweet spot for Whisper
            var currentTime: TimeInterval = 0.0
            
            while currentTime < totalDuration {
                let remainingTime = totalDuration - currentTime
                let currentChunkDuration = min(segmentDuration, remainingTime)
                
                let segmentText = try await whisper.transcribeSegment(
                    audioURL: url,
                    model: selectedModel,
                    startTime: currentTime,
                    duration: currentChunkDuration
                )
                
                let cleanedSegment = segmentText.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !cleanedSegment.isEmpty {
                    if transcript.isEmpty {
                        transcript = cleanedSegment
                    } else {
                        transcript += " " + cleanedSegment
                    }
                }
                
                currentTime += segmentDuration
            }
            finalizeTranscription(context: context, url: url)
            
        } catch {
            transcript = "File transcription error: \(error.localizedDescription)"
        }
        
        isTranscribing = false
    }

    // Modified toggle incorporating the dynamic property
        func toggleLiveRecording(context: ModelContext) {
            if isLiveRecording {
                liveInputManager.stopStreaming()
                isLiveRecording = false
                finalizeTranscription(context: context, url: nil)
            } else {
                // Re-verify immediately prior to starting stream
                refreshAudioHardware()
                
                if !hasMicrophoneConnected {
                    self.alertMessage = "No microphone detected. Please plug in an audio input device to use Live Captions."
                    self.showAlert = true
                    return
                }
            
                transcript = "Listening..."
                            isLiveRecording = true
                            do {
                                try liveInputManager.startStreaming(withModel: selectedModel, source: selectedDevice)
                            } catch {
                                transcript = "Microphone access failed: \(error.localizedDescription)"
                                isLiveRecording = false
                            }
                        }
                    }
    
    // Call this function when a transcription successfully finishes
    func finalizeTranscription(context: ModelContext, url: URL?) {
        guard !transcript.isEmpty else { return }
        
        if let fileURL = url {
            self.currentFileName = fileURL.lastPathComponent
        } else {
            let timestamp = Date().formatted(date: .abbreviated, time: .shortened)
            self.currentFileName = "Live Recording (\(timestamp))"
        }
        
        let newRecord = TranscriptItem(
            fileName: currentFileName,
            text: transcript
        )
        
        context.insert(newRecord)
        
        do {
            try context.save()
        } catch {
            print("Failed to save transcript: \(error.localizedDescription)")
        }
    }
}
