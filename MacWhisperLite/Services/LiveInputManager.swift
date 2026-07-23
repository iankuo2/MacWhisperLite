//
//  LiveInputManager.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-07-22.
//

import Foundation
import AVFoundation

enum LiveAudioSource {
    case microphone
    case systemAudio
}

class LiveInputManager {
    private let audioEngine = AVAudioEngine()
    private var engine: any TranscriptionEngine
    private let systemAudioCapture = SystemAudioCaptureManager()
    
    private var rollingAudioBuffer: [Float] = []
    private var isProcessing = false
    private var activeSource: LiveAudioSource?
    
    var onTextReceived: (@MainActor (String) -> Void)?
    
    // MARK: - Initializer & Engine Management
    init(engine: any TranscriptionEngine) {
        self.engine = engine
    }
    
    /// Updates the underlying engine when the user switches backends
    func updateEngine(_ engine: any TranscriptionEngine) {
        self.engine = engine
    }
    
    // MARK: - Streaming Controls
    @MainActor
    func startStreaming(source: LiveAudioSource) throws {
        rollingAudioBuffer.removeAll()
        self.activeSource = source
        
        if source == .microphone {
            // --- SOURCE A: MICROPHONE ---
            let inputNode = audioEngine.inputNode
            let hardwareFormat = inputNode.inputFormat(forBus: 0)
            
            guard let whisperFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false) else { return }
            guard let converter = AVAudioConverter(from: hardwareFormat, to: whisperFormat) else { return }
            
            inputNode.installTap(onBus: 0, bufferSize: 4000, format: hardwareFormat) { [weak self] buffer, time in
                guard let self = self else { return }
                
                let ratio = 16000.0 / hardwareFormat.sampleRate
                let targetCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
                guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: whisperFormat, frameCapacity: targetCapacity) else { return }
                
                var error: NSError?
                converter.convert(to: outputBuffer, error: &error) { _, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }
                
                guard let channelData = outputBuffer.floatChannelData else { return }
                let frameCount = Int(outputBuffer.frameLength)
                let newSamples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
                
                // Route samples to central processing pipeline
                self.processNewSamples(newSamples)
            }
            try audioEngine.start()
            
        } else {
            // --- SOURCE B: SYSTEM AUDIO ---
            systemAudioCapture.onSamplesCaptured = { [weak self] newSamples in
                guard let self = self else { return }
                self.processNewSamples(newSamples)
            }
            
            Task {
                do {
                    try await systemAudioCapture.startCapture()
                } catch {
                    print("Failed to initiate ScreenCaptureKit: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Centralized parsing & transcription orchestration via TranscriptionEngine Actor
    private func processNewSamples(_ samples: [Float]) {
        let currentSnapshot = synchronizedAppendAndGetSnapshot(with: samples)
        
        guard !getIsProcessing() else { return }
        setIsProcessing(true)

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            do {
                // Call the actor method directly on whatever TranscriptionEngine is active
                let liveText = try await self.engine.transcribe(pcmBuffer: currentSnapshot)
                
                await MainActor.run {
                    self.onTextReceived?(liveText)
                    self.setIsProcessing(false)
                }
            } catch {
                await MainActor.run { self.setIsProcessing(false) }
            }
        }
    }
    
    @MainActor
    func stopStreaming() {
        if activeSource == .microphone {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        } else if activeSource == .systemAudio {
            Task { try? await systemAudioCapture.stopCapture() }
        }
        
        clearBuffer()
        setIsProcessing(false)
        activeSource = nil
    }
    
    @MainActor func flushBuffer() { clearBuffer() }
    
    // MARK: - Thread Safe State Helpers
    private let queue = DispatchQueue(label: "com.whisper.live.buffer.sync")
    private func synchronizedAppendAndGetSnapshot(with samples: [Float]) -> [Float] {
        queue.sync {
            self.rollingAudioBuffer.append(contentsOf: samples)
            return self.rollingAudioBuffer
        }
    }
    private func clearBuffer() { queue.sync { self.rollingAudioBuffer.removeAll() } }
    private func getIsProcessing() -> Bool { queue.sync { self.isProcessing } }
    private func setIsProcessing(_ value: Bool) { queue.sync { self.isProcessing = value } }
}
