//
//  TranscriptionEngineFactory.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-07-22.
//

//
//  TranscriptionEngineFactory.swift
//  MacWhisperLite
//

enum EngineType: String, CaseIterable, Identifiable {
    case whisperCpp = "whisper.cpp (CPU/Metal)"
    case whisperKit = "WhisperKit (Core ML / ANE)"
    
    var id: String { rawValue }
}

struct TranscriptionEngineFactory {
    static func createEngine(for type: EngineType) -> any TranscriptionEngine {
        switch type {
        case .whisperCpp:
            return WhisperCppEngine()
        case .whisperKit:
            return WhisperKitEngine()
        }
    }
}
