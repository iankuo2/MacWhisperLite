//
//  WhisperModel.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-06-30.
//  Modified on 2026-07-22.
//

import Foundation

enum WhisperModel: String, CaseIterable, Identifiable {

    case tiny
    case base
    case small
    case medium
    case large

    var id: String {
        rawValue
    }

    /// Resolves the specific model repository/filename required by the selected engine.
    func modelName(for engineType: EngineType) -> String {
        switch engineType {
        case .whisperKit:
            switch self {
            case .large:
                return "openai_whisper-large-v3-v20240930_turbo"
            default:
                // Defaults to the 626MB quantized model for all other cases (tiny, base, small, medium)
                return "openai_whisper-large-v3-v20240930_626MB"
            }
            
        case .whisperCpp:
            return self.filename
        }
    }

    var displayName: String {
        switch self {
        case .tiny:
            return "Tiny"
        case .base:
            return "Base"
        case .small:
            return "Small"
        case .medium:
            return "Medium"
        case .large:
            return "Large"
        }
    }

    var filename: String {
        switch self {
        case .tiny:
            return "ggml-tiny"
        case .base:
            return "ggml-base"
        case .small:
            return "ggml-small"
        case .medium:
            return "ggml-medium"
        case .large:
            return "ggml-large-v3"
        }
    }

    var description: String {
        switch self {
        case .tiny:
            return "Fastest"
        case .base:
            return "Balanced"
        case .small:
            return "Better Accuracy"
        case .medium:
            return "High Accuracy"
        case .large:
            return "Best Accuracy (Turbo)"
        }
    }

    var memoryRequirement: String {
        switch self {
        case .tiny:
            return "≈626 MB"
        case .base:
            return "≈626 MB"
        case .small:
            return "≈626 MB"
        case .medium:
            return "≈626 MB"
        case .large:
            return "≈1.5 GB"
        }
    }
}
