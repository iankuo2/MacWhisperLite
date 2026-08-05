//
//  TranscriptionViewModel.swift
//  MacWhisperLite
//
//  Modified by ian kuo on 2026-07-22
//

import Foundation
internal import Combine
import AVFAudio
import SwiftData
import AVFoundation

@MainActor
class TranscriptionViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isTranscribing = false
    @Published var isLiveRecording = false
    @Published var transcript = ""
    
    // Default to WhisperKit as requested
    @Published var selectedEngineType: EngineType = .whisperKit {
        didSet {
            Task {
                await updateEngine(for: selectedEngineType)
            }
        }
    }
    
    @Published var selectedModel: WhisperModel = .tiny {
        didSet {
            Task {
                try? await currentEngine.loadModel(selectedModel)
            }
        }
    }
    
    @Published var currentFileName: String = "Untitled Audio"
    @Published var selectedDevice: LiveAudioSource = .microphone
    
    @Published var alertMessage: String? = nil
    @Published var showAlert = false
    
    // Hardware monitoring
    @Published var hasMicrophoneConnected: Bool = false
    @Published var activeMicrophoneName: String = "No Microphone"
    
    // MARK: - Private Engine & Manager References
    private var currentEngine: any TranscriptionEngine
    private lazy var liveInputManager = LiveInputManager(engine: currentEngine)
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initializer
        init() {
            // Initialize default engine (WhisperKit) via factory
            let initialEngine = TranscriptionEngineFactory.createEngine(for: .whisperKit)
            self.currentEngine = initialEngine
            
            // Load default model into memory
            Task {
                try? await initialEngine.loadModel(.tiny)
            }
            
            // Initial hardware check
            refreshAudioHardware()
            
            // Connect LiveInputManager text output directly to the UI transcript property
            liveInputManager.onTextReceived = { [weak self] liveText in
                let cleaned = liveText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty {
                    self?.transcript = cleaned
                }
            }
            
            // Listen to hardware plug/unplug events
            NotificationCenter.default.publisher(for: AVCaptureDevice.wasConnectedNotification)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.refreshAudioHardware() }
                .store(in: &cancellables)
                
            NotificationCenter.default.publisher(for: AVCaptureDevice.wasDisconnectedNotification)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.refreshAudioHardware() }
                .store(in: &cancellables)
        }
    
    // MARK: - Dynamic Engine Switcher
        private func updateEngine(for type: EngineType) async {
            if isLiveRecording {
                liveInputManager.stopStreaming()
                isLiveRecording = false
            }
            
            // Instantiate the new engine actor
            let newEngine = TranscriptionEngineFactory.createEngine(for: type)
            self.currentEngine = newEngine
            
            // Keep LiveInputManager in sync with the active engine
            self.liveInputManager.updateEngine(newEngine)
            
            // Load the currently selected model into the new engine
            try? await self.currentEngine.loadModel(selectedModel)
        }
    
    // MARK: - Audio Hardware Management
    func refreshAudioHardware() {
        let status = AudioDeviceDetector.checkAudioInputStatus()
        self.hasMicrophoneConnected = status.hasInputDevice
        self.activeMicrophoneName = status.deviceName ?? "No Microphone"
        
        if !status.hasInputDevice && isLiveRecording {
            liveInputManager.stopStreaming()
            isLiveRecording = false
            alertMessage = "Your microphone was unplugged. Live captioning has stopped."
            showAlert = true
        }
    }
    
    // MARK: - File Transcription
    func transcribe(url: URL, context: ModelContext) async {
        isTranscribing = true
        transcript = ""
        
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let totalDuration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
            
            let segmentDuration: TimeInterval = 30.0
            var currentTime: TimeInterval = 0.0
 
            while currentTime < totalDuration {
                let remainingTime = totalDuration - currentTime
                let currentChunkDuration = min(segmentDuration, remainingTime)
                
                // Transcribe chunk using active engine actor instance
                let segmentText = try await currentEngine.transcribeSegment(
                    audioURL: url,
                    startTime: currentTime,
                    duration: currentChunkDuration
                )
                
                let cleanedSegment = segmentText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                
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

    // MARK: - Live Recording Management
    func toggleLiveRecording(context: ModelContext) {
        if isLiveRecording {
            liveInputManager.stopStreaming()
            isLiveRecording = false
            finalizeTranscription(context: context, url: nil)
        } else {
            refreshAudioHardware()
            
            if !hasMicrophoneConnected {
                self.alertMessage = "No microphone detected. Please plug in an audio input device to use Live Captions."
                self.showAlert = true
                return
            }
        
            transcript = "Listening..."
            isLiveRecording = true
            
            do {
                try liveInputManager.startStreaming(source: selectedDevice)
            } catch {
                transcript = "Microphone access failed: \(error.localizedDescription)"
                isLiveRecording = false
            }
        }
    }
    
    // MARK: - Save Transcript
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
