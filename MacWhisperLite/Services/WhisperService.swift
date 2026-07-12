//
//  WhisperService.swift
//  MacWhisperLite
//
import Foundation
import AVFoundation

/// A high-level Swift wrapper managing the underlying Objective-C++ Whisper bridge.
 actor WhisperService {
    
    // MARK: - Errors
     enum WhisperError: Error {
        case modelNotFound
        case initializationFailed
        case processingFailed
    }
    
    // MARK: - Properties
    private var bridge: WhisperBridge?
    /// Keeps track of which model path is currently loaded in memory to prevent reloading the same one.
    private var loadedModelPath: String?
    private let dispatchQueue = DispatchQueue(label: "com.whisper.service.processing", qos: .userInitiated)
    
    // MARK: - Initialization
    public init() {}
    
    // MARK: - Legacy Interface Support
    
    /// Transcribes a file from a URL using a bundle-packaged model.
    /// - Parameters:
    ///   - audioURL: The file URL of the audio file to transcribe.
    ///   - model: The model structure containing filename properties.
    /// - Returns: The transcribed text string.
     func transcribe(audioURL: URL, model: WhisperModel) async throws -> String {
        // 1. Ensure security-scoped resources (like sandbox URLs) are released safely
        defer { audioURL.stopAccessingSecurityScopedResource() }
        
        // 2. Locate and dynamic-load the model from the main app bundle if needed
        guard let bundleModelPath = Bundle.main.path(forResource: model.filename, ofType: "bin") else {
            throw WhisperError.modelNotFound
        }
        try ensureModelLoaded(atPath: bundleModelPath)
        
        // 3. Decode the file into the exact 16kHz Float32 structure Whisper expects
        let pcmSamples = try decodeAudioFileToPCM(at: audioURL)
        
        // 4. Pass the float array to the primary transcription engine
        return try await transcribe(pcmBuffer: pcmSamples)
    }
    
    // MARK: - Core Methods
    
    /// Ensures the correct Whisper model context is instantiated in memory.
    private func ensureModelLoaded(atPath modelPath: String) throws {
        if loadedModelPath == modelPath && bridge != nil { return }
        
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw WhisperError.modelNotFound
        }
        
        guard let initializedBridge = WhisperBridge(modelPath: modelPath) else {
            throw WhisperError.initializationFailed
        }
        
        self.bridge = initializedBridge
        self.loadedModelPath = modelPath
    }
    
    /// Transcribes a raw PCM float array asynchronously.
    /// Accessible by both file reading logic and upcoming microphone streaming engines.
     func transcribe(pcmBuffer: [Float]) async throws -> String {
        guard let bridge = self.bridge else {
            throw WhisperError.initializationFailed
        }
        
        let audioSamples = pcmBuffer
        let sampleCount = Int32(audioSamples.count)
        
        return try await withCheckedThrowingContinuation { continuation in
            dispatchQueue.async {
                var mutableSamples = audioSamples
                
                let result: String? = mutableSamples.withUnsafeMutableBufferPointer { pointer in
                    guard let baseAddress = pointer.baseAddress else { return nil }
                    return bridge.transcribePCMBuffer(baseAddress, samples: sampleCount)
                }

                
                if let transcribedText = result {
                    continuation.resume(returning: transcribedText)
                } else {
                    continuation.resume(throwing: WhisperError.processingFailed)
                }
            }
        }
    }
    
    // MARK: - Private Decoding Helpers
    
    /// Reads any standard audio file format (mp3, m4a, wav) and standardizes it to 16kHz Mono Float32 PCM.
    private func decodeAudioFileToPCM(at url: URL) throws -> [Float] {
        let audioFile = try AVAudioFile(forReading: url)
        
        // Establish standard target structure required by the Whisper engine
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw WhisperError.processingFailed
        }
        
        // Build conversion graph from native file format to 16kHz target
        guard let converter = AVAudioConverter(from: audioFile.processingFormat, to: targetFormat) else {
            throw WhisperError.processingFailed
        }
        
        let sampleCount = AVAudioFrameCount(audioFile.length)
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: sampleCount) else {
            throw WhisperError.processingFailed
        }
        try audioFile.read(into: inputBuffer)
        
        // Calculate output buffer capacity allowing for sampling frequency discrepancies
        let capacityRatio = targetFormat.sampleRate / audioFile.processingFormat.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * capacityRatio)
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
            throw WhisperError.processingFailed
        }
        
        var conversionError: NSError?
        converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            outStatus.pointee = .haveData
            return inputBuffer
        }
        
        if let conversionError = conversionError { throw conversionError }
        
        // Convert safe structured memory directly to primitive Swift elements
        guard let floatData = outputBuffer.floatChannelData? [0] else {
            throw WhisperError.processingFailed
        }
        
        let frameCount = Int(outputBuffer.frameLength)
        return Array(UnsafeBufferPointer(start: floatData, count: frameCount))
    }
     // MARK: - LiveStream method for Live Caption feature
     // Add Streaming method inside  WhisperService actor
     /*/Whisper performs best on live streams when you give it the entire audio chunk from the current sentence, rather than small 100ms fragments.
      It accepts the full model parameter so it can auto-load the bundle model files ("ggml-tiny", "ggml-base", etc.) if needed:*/
     func transcribeLiveStream(pcmBuffer: [Float], model: WhisperModel) async throws -> String {
         // 1. Automatically load the model if it hasn't been loaded yet
         guard let bundleModelPath = Bundle.main.path(forResource: model.filename, ofType: "bin") else {
             throw WhisperError.modelNotFound
         }
         try ensureModelLoaded(atPath: bundleModelPath)
         
         // 2. Reuse your existing core logic to transcribe the rolling buffer window
         return try await transcribe(pcmBuffer: pcmBuffer)
     }
     
     // MARK: - Update WhisperService with a Segment Transcriber
     //Helper method allows the ViewModel to request transcription for a specific slice of the file without loading the entire audio into RAM at once.
     //Transcribes a specific time-slice of an audio file
     func transcribeSegment(audioURL: URL, model: WhisperModel, startTime: TimeInterval, duration: TimeInterval) async throws -> String {
         // 1. Locate and load model if needed
         guard let bundleModelPath = Bundle.main.path(forResource: model.filename, ofType: "bin") else {
             throw WhisperError.modelNotFound
         }
         try ensureModelLoaded(atPath: bundleModelPath)
         
         // 2. Load the audio file
         let audioFile = try AVAudioFile(forReading: audioURL)
         
         guard let targetFormat = AVAudioFormat(
             commonFormat: .pcmFormatFloat32,
             sampleRate: 16000,
             channels: 1,
             interleaved: false
         ) else { throw WhisperError.processingFailed }
         
         guard let converter = AVAudioConverter(from: audioFile.processingFormat, to: targetFormat) else {
             throw WhisperError.processingFailed
         }
         
         // 3. Calculate frame offsets for the segment
         let sampleRate = audioFile.processingFormat.sampleRate
         let startFrame = AVAudioFramePosition(startTime * sampleRate)
         let frameCountToRead = AVAudioFrameCount(duration * sampleRate)
         
         // Ensure we don't read past the end of the file
         let totalFrames = audioFile.length
         guard startFrame < totalFrames else { return "" }
         let safeFrameCount = min(frameCountToRead, AVAudioFrameCount(totalFrames - startFrame))
         
         audioFile.framePosition = startFrame
         
         guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: safeFrameCount) else {
             throw WhisperError.processingFailed
         }
         try audioFile.read(into: inputBuffer, frameCount: safeFrameCount)
         
         // 4. Convert segment buffer to 16kHz
         let capacityRatio = targetFormat.sampleRate / audioFile.processingFormat.sampleRate
         let outputFrameCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * capacityRatio)
         
         guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
             throw WhisperError.processingFailed
         }
         
         var conversionError: NSError?
         converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
             outStatus.pointee = .haveData
             return inputBuffer
         }
         if let conversionError = conversionError { throw conversionError }
         
         // 5. Convert safe structured memory directly to primitive Swift elements
         guard let floatData = outputBuffer.floatChannelData else {
             throw WhisperError.processingFailed
         }
         let frameCount = Int(outputBuffer.frameLength)

         // FIX: Pass the first channel pointer (floatData[0]) into the buffer initializer
         let pcmSamples = Array(UnsafeBufferPointer(start: floatData[0], count: frameCount))

         // 6. Run inference on this segment
         return try await transcribe(pcmBuffer: pcmSamples)
     }


}

