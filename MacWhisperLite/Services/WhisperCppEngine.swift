//
//  WhisperCppEngine.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-07-22.
//


//
//  WhisperCppEngine.swift
//  MacWhisperLite
//
// MARK: - Whisper Engine Errors
enum WhisperError: Error, LocalizedError {
    case modelNotFound
    case initializationFailed
    case processingFailed
    case transcriptionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "The requested Whisper model file could not be found."
        case .initializationFailed:
            return "Failed to initialize the Whisper context."
        case .processingFailed:
            return "Failed to process audio or retrieve PCM samples."
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        }
    }
}
import Foundation
import AVFoundation

actor WhisperCppEngine: TranscriptionEngine {
    let name = "whisper.cpp (C++)"
    
    private var bridge: WhisperBridge?
    private var loadedModelPath: String?
    private let dispatchQueue = DispatchQueue(label: "com.whisper.cpp.processing", qos: .userInitiated)
    
    
    func loadModel(_ model: WhisperModel) async throws {
        let filename = await MainActor.run { model.filename }
        guard let bundleModelPath = Bundle.main.path(forResource: filename, ofType: "bin") else {
            throw WhisperError.modelNotFound
        }
        
        if loadedModelPath == bundleModelPath && bridge != nil { return }
        
        guard FileManager.default.fileExists(atPath: bundleModelPath) else {
            throw WhisperError.modelNotFound
        }
        
        guard let initializedBridge = WhisperBridge(modelPath: bundleModelPath) else {
            throw WhisperError.initializationFailed
        }
        
        self.bridge = initializedBridge
        self.loadedModelPath = bundleModelPath
    }
    
    func transcribe(audioURL: URL) async throws -> String {
        defer { audioURL.stopAccessingSecurityScopedResource() }
        let pcmSamples = try decodeAudioFileToPCM(at: audioURL)
        return try await transcribe(pcmBuffer: pcmSamples)
    }
    
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
                
                if let text = result {
                    continuation.resume(returning: text)
                } else {
                    continuation.resume(throwing: WhisperError.processingFailed)
                }
            }
        }
    }
    
    func transcribeSegment(audioURL: URL, startTime: TimeInterval, duration: TimeInterval) async throws -> String {
        let audioFile = try AVAudioFile(forReading: audioURL)
        guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false) else {
            throw WhisperError.processingFailed
        }
        guard let converter = AVAudioConverter(from: audioFile.processingFormat, to: targetFormat) else {
            throw WhisperError.processingFailed
        }
        
        let sampleRate = audioFile.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(startTime * sampleRate)
        let frameCountToRead = AVAudioFrameCount(duration * sampleRate)
        let totalFrames = audioFile.length
        guard startFrame < totalFrames else { return "" }
        
        let safeFrameCount = min(frameCountToRead, AVAudioFrameCount(totalFrames - startFrame))
        audioFile.framePosition = startFrame
        
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: safeFrameCount) else {
            throw WhisperError.processingFailed
        }
        try audioFile.read(into: inputBuffer, frameCount: safeFrameCount)
        
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
        
        guard let floatData = outputBuffer.floatChannelData else {
            throw WhisperError.processingFailed
        }
        let pcmSamples = Array(UnsafeBufferPointer(start: floatData[0], count: Int(outputBuffer.frameLength)))
        return try await transcribe(pcmBuffer: pcmSamples)
    }

    
    // Private audio decoding helpers stay inside this implementation file...
}
import AVFoundation

extension WhisperCppEngine {
    
    /// Converts an audio file at the given URL to 16kHz mono Float PCM samples required by whisper.cpp
    func decodeAudioFileToPCM(at url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        
        // whisper.cpp expects 16kHz, 1 channel (mono), Float32 PCM
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw WhisperError.processingFailed
        }
        
        guard let converter = AVAudioConverter(from: file.processingFormat, to: targetFormat) else {
            throw WhisperError.processingFailed
        }
        
        let frameCount = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else {
            throw WhisperError.processingFailed
        }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return file.processingFormat == file.fileFormat ? nil : nil
        }
        
        // Perform conversion
        let status = converter.convert(to: buffer, error: &error, withInputFrom: inputBlock)
        if status == .error || error != nil {
            throw WhisperError.processingFailed
        }
        
        guard let floatData = buffer.floatChannelData?[0] else {
            throw WhisperError.processingFailed
        }
        
        return Array(UnsafeBufferPointer(start: floatData, count: Int(buffer.frameLength)))
    }
    
    /// Converts a specific section/segment of an audio file to 16kHz mono Float PCM samples
    func decodeSegmentToPCM(at url: URL, startTime: Double, duration: Double) throws -> [Float] {
        let allSamples = try decodeAudioFileToPCM(at: url)
        
        // 16,000 samples per second
        let sampleRate = 16000.0
        let startIndex = Int(startTime * sampleRate)
        let count = Int(duration * sampleRate)
        
        guard startIndex < allSamples.count else { return [] }
        let endIndex = min(startIndex + count, allSamples.count)
        
        return Array(allSamples[startIndex..<endIndex])
    }
}
