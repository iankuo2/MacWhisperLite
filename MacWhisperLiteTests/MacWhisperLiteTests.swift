//
//  MacWhisperLiteTests.swift
//  MacWhisperLiteTests
//
//  Created by ian kuo on 2026-07-11
//

import Testing
import Foundation
import QuartzCore // For CACurrentMediaTime()
@testable import MacWhisperLite

struct MacWhisperLiteTests {

    @Test("Test WhisperBridge Transcription with Static Audio File")
    func testWhisperBridgeTranscription() async throws {
        // 1. Locate your model and test audio files in the application bundle
        let bundle = Bundle(for: WhisperBridge.self) // Or Bundle.main depending on setup
        
        let modelPath = bundle.path(forResource: "ggml-base.en", ofType: "bin")
        let audioPath = bundle.path(forResource: "test_speech", ofType: "wav") // or .mp3, .m4a
        
        // Assert that files exist before proceeding using Swift Testing requirements
        let verifiedModelPath = try #require(modelPath, "Missing model file (ggml-base.en.bin) in bundle resources.")
        let verifiedAudioPath = try #require(audioPath, "Missing audio file (test_speech.wav) in bundle resources.")
        
        // 2. Initialize the Whisper bridge
        print("Initializing Whisper model...")
        let bridge = WhisperBridge(modelPath: verifiedModelPath)
        let verifiedBridge = try #require(bridge, "Failed to initialize WhisperBridge.")
        
        // 3. Decode audio file to 16kHz raw PCM floats
        print("Decoding and resampling audio file...")
        var sampleCount: Int32 = 0
        let audioURL = URL(fileURLWithPath: verifiedAudioPath)
        
        // Call the Objective-C utility function
        let rawPCMBuffer = AudioDecoder.decodeAudioFile(at: audioURL, outSamples: &sampleCount)
        let verifiedBuffer = try #require(rawPCMBuffer, "Failed to extract PCM audio data.")
        
        // Safely free the buffer memory once the test scope finishes executing
        defer {
            free(verifiedBuffer)
        }
        
        try #require(sampleCount > 0, "Audio decoded successfully but sample count is zero.")
        
        // 4. Run the transcription execution
        print("Processing transcription for \(sampleCount) samples...")
        let startTime = CACurrentMediaTime() * 1000
        
        let transcript = verifiedBridge.transcribePCMBuffer(verifiedBuffer, samples: sampleCount)
        
        let endTime = CACurrentMediaTime() * 1000
        print("--- Performance: Took \(Int(endTime - startTime)) ms ---")
        
        // 5. Output results and validate content conditions
        let finalTranscript = try #require(transcript, "Whisper bridge returned a nil transcript string.")
        print("--- Transcription Result ---")
        print(finalTranscript)
        print("----------------------------")
        
        // Verify that the transcription isn't empty
        #expect(!finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
