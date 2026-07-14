/*
 Refactor LiveInputManager to support both paths
Now update your LiveInputManager to accept a LiveAudioSource parameter and route the incoming buffer processing into a shared utility function.
*/
import Foundation
import AVFoundation

enum LiveAudioSource {
    case microphone
    case systemAudio
}

class LiveInputManager {
    private let audioEngine = AVAudioEngine()
    private let whisperService: WhisperService
    private let systemAudioCapture = SystemAudioCaptureManager() // Added SCKit Manager
    
    private var rollingAudioBuffer: [Float] = []
    private var isProcessing = false
    private var activeSource: LiveAudioSource?
    
    var onTextReceived: (@MainActor (String) -> Void)?
    
    init(whisperService: WhisperService) {
        self.whisperService = whisperService
    }
    
    @MainActor
    func startStreaming(withModel model: WhisperModel, source: LiveAudioSource) throws {
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
                self.processNewSamples(newSamples, model: model)
            }
            try audioEngine.start()
            
        } else {
            // --- SOURCE B: SYSTEM AUDIO ---
            systemAudioCapture.onSamplesCaptured = { [weak self] newSamples in
                guard let self = self else { return }
                self.processNewSamples(newSamples, model: model)
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
    
    /// Centralized parsing & transcription orchestration
    private func processNewSamples(_ samples: [Float], model: WhisperModel) {
        let currentSnapshot = synchronizedAppendAndGetSnapshot(with: samples)
        
        guard !getIsProcessing() else { return }
        setIsProcessing(true)

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            do {
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
    
    // --- Thread Safe State Helpers Remain Unchanged ---
    private let queue = DispatchQueue(label: "com.whisper.live.buffer.sync")
    private func synchronizedAppendAndGetSnapshot(with samples: [Float]) -> [Float] { queue.sync { self.rollingAudioBuffer.append(contentsOf: samples); return self.rollingAudioBuffer } }
    private func clearBuffer() { queue.sync { self.rollingAudioBuffer.removeAll() } }
    private func getIsProcessing() -> Bool { queue.sync { self.isProcessing } }
    private func setIsProcessing(_ value: Bool) { queue.sync { self.isProcessing = value } }
}

