//
//  LiveInputManager.swift
//  MacWhisperLite
// This service hooks into Mac's default microphone using Apple's AVAudioEngine, resamples the audio stream to the mandatory 16kHz Mono Float32 format, manages a rolling audio buffer, and streams updates back to the app.
//  Created by ian kuo on 2026-07-11.
//


import Foundation
import AVFoundation

// Removed ': ObservableObject' to fix the protocol conformance error
class LiveInputManager {
    private let audioEngine = AVAudioEngine()
    private let whisperService: WhisperService
    
    // Holds the cumulative audio data for the current listening session
    private var rollingAudioBuffer: [Float] = []
    private var isProcessing = false
    
    /// A closure callback that drops the updated live text straight into your UI pipeline
    /// Marked @MainActor so it always delivers text safely back to the UI thread
    var onTextReceived: (@MainActor (String) -> Void)?
    
    init(whisperService: WhisperService) {
        self.whisperService = whisperService
    }
    
    @MainActor
    func startStreaming(withModel model: WhisperModel) throws {
        // Clear any previous session leftovers
        rollingAudioBuffer.removeAll()
        
        let inputNode = audioEngine.inputNode
        let hardwareFormat = inputNode.inputFormat(forBus: 0)
        
        // Target format required by Whisper
        guard let whisperFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else { return }
        
        guard let converter = AVAudioConverter(from: hardwareFormat, to: whisperFormat) else { return }
        
        // Tap into the microphone bus.
        inputNode.installTap(onBus: 0, bufferSize: 4000, format: hardwareFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            
            // 1. Resample incoming microphone chunk to 16kHz
            let ratio = 16000.0 / hardwareFormat.sampleRate
            let targetCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: whisperFormat, frameCapacity: targetCapacity) else { return }
            
            var error: NSError?
            converter.convert(to: outputBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            // 2. Convert memory pointer to plain Swift [Float] array
            // 2.1 Convert channel 0 pointer to a plain Swift [Float] array
            guard let channelData = outputBuffer.floatChannelData else { return }
            let frameCount = Int(outputBuffer.frameLength)
            // channelData[0] gives you the UnsafeMutablePointer<Float> for the first channel
            let newSamples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
            // 3. Append to our growing session window safely
            let currentSnapshot = synchronizedAppendAndGetSnapshot(with: newSamples)
            
            // Throttle requests so we don't choke the processor while Whisper finishes transcribing
            guard !getIsProcessing() else { return }
            setIsProcessing(true)

            // FIX: Use priority: .userInitiated instead of qos: .userInteractive
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self = self else { return }
                do {
                    // Pass the entire running sentence data to the engine
                    let liveText = try await self.whisperService.transcribeLiveStream(
                        pcmBuffer: currentSnapshot,
                        model: model
                    )
                    
                    await MainActor.run {
                        self.onTextReceived?(liveText)
                        self.setIsProcessing(false)
                    }
                } catch {
                    await MainActor.run { self.setIsProcessing(false) }
                }
            }

        }
        
        try audioEngine.start()
    }
    
    @MainActor
    func stopStreaming() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        clearBuffer()
        setIsProcessing(false)
    }
    
    @MainActor
    func flushBuffer() {
        clearBuffer()
    }
    
    // --- Thread Safe State Helpers ---
    
    private let queue = DispatchQueue(label: "com.whisper.live.buffer.sync")
    
    private func synchronizedAppendAndGetSnapshot(with samples: [Float]) -> [Float] {
        queue.sync {
            self.rollingAudioBuffer.append(contentsOf: samples)
            return self.rollingAudioBuffer
        }
    }
    
    private func clearBuffer() {
        queue.sync {
            self.rollingAudioBuffer.removeAll()
        }
    }
    
    private func getIsProcessing() -> Bool {
        queue.sync { self.isProcessing }
    }
    
    private func setIsProcessing(_ value: Bool) {
        queue.sync { self.isProcessing = value }
    }
}

