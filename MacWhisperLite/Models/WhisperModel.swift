//
//  WhisperModel.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-06-30.
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
            return "Best Accuracy"
        }
    }
    var memoryRequirement: String {

        switch self {

        case .tiny:
            return "≈75 MB"

        case .base:
            return "≈150 MB"

        case .small:
            return "≈500 MB"

        case .medium:
            return "≈1.5 GB"

        case .large:
            return "≈3 GB"
        }
    }
}
