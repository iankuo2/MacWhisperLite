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

@MainActor
class TranscriptionViewModel: ObservableObject {
    
    private let whisper = WhisperService()
    private lazy var liveInputManager = LiveInputManager(whisperService: whisper)
    
    @Published var isTranscribing = false
    @Published var isLiveRecording = false
    @Published var transcript = ""
    @Published var selectedModel: WhisperModel = .tiny
    @Published var currentFileName: String = "Untitled Audio"
    
    // 1. Give your selectedDevice a safe default type or value matching your setup
    @Published var selectedDevice: LiveAudioSource = .microphone
    
    // 2. Alert properties for the SwiftUI layer to observe hardware failures
    @Published var alertMessage: String? = nil
    @Published var showAlert = false
    
    init() {
        // Connect the manager callback to our UI text publisher
        liveInputManager.onTextReceived = { [weak self] liveText in
            guard let self = self else { return }
            // Filter out internal whisper noise artifacts like " [BLANK_AUDIO] " or empty strings
            let cleanedText = liveText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanedText.isEmpty {
                self.transcript = cleanedText
            }
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

    // New Live Streaming Transcriber controls
    func toggleLiveRecording(context: ModelContext) {
        if isLiveRecording {
            liveInputManager.stopStreaming()
            isLiveRecording = false
            finalizeTranscription(context: context, url: nil)
        } else {
            // 3. Hardware check before activating stream
            let status = AudioDeviceDetector.checkAudioInputStatus()
            
            if !status.hasInputDevice {
                // Trigger the alert instead of locking up or failing silently
                self.alertMessage = "No microphone detected. Please plug in or enable an audio input device to use Live Captions."
                self.showAlert = true
                return
            }
            
            // Optional: Log what kind of microphone we are using
            print("Starting live captioning with: \(status.deviceName ?? "Unknown Device") (External: \(status.isExternal))")
            
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
