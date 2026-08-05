//
//  TranscriptionEngine.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-07-22.
//


//
//  TranscriptionEngine.swift
//  MacWhisperLite
//

import Foundation

/// Universal interface for any transcription backend (whisper.cpp, WhisperKit, API, etc.)
protocol TranscriptionEngine: Actor {
    /// Identifies the engine backend type for display or telemetry
    var name: String { get }
    
    /// Prepares/loads the specified model variant in memory
    func loadModel(_ model: WhisperModel) async throws
    
    /// Transcribes a full audio file given its URL
    func transcribe(audioURL: URL) async throws -> String
    
    /// Transcribes a raw 16kHz float PCM buffer (used for live streaming/captions)
    func transcribe(pcmBuffer: [Float]) async throws -> String
    
    /// Transcribes a specific slice of an audio file (used for timed SRT exports)
    func transcribeSegment(
        audioURL: URL,
        startTime: TimeInterval,
        duration: TimeInterval
    ) async throws -> String
}