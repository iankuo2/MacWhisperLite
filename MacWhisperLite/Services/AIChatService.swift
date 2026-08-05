//
//  AIChatService.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-08-05.
//


import Foundation
#if canImport(FoundationModels)
import FoundationModels // macOS 15+ / Apple Intelligence Frameworks
#endif

@MainActor
class AIChatService: ObservableObject {
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    /// System prompt tailored for transcription cleanup
    private let systemPrompt = """
    You are an expert editor for speech-to-text transcriptions. Your task is to refine the provided raw transcript:
    1. Correct any obvious spelling, grammar, or speech-to-text typos.
    2. Format the text into natural, human-readable paragraphs.
    3. Fix missing or improper punctuation.
    4. Remove unnecessary filler words (e.g., "um", "uh", "like", "you know", "like I said") while strictly preserving the original meaning and natural tone.
    5. Do NOT summarize or omit important content. Output ONLY the refined transcript text.
    """
    
    /// Process transcript text using local Apple Foundation Models
    func processTranscript(_ rawText: String) async -> String {
        guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let prompt = """
        \(systemPrompt)
        
        Raw Transcript:
        "\(rawText)"
        
        Refined Transcript:
        """
        
        // Approach A: macOS 15+ Native Foundation Model API (Apple Intelligence)
        if #available(macOS 15.0, iOS 18.0, *) {
            do {
                // Initialize the local System Language Model Session
                let session = try await SystemLanguageModel.Session()
                let response = try await session.generateResponse(for: prompt)
                return response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                print("Apple Foundation Model generation failed: \(error.localizedDescription)")
                self.errorMessage = "Local AI generation failed: \(error.localizedDescription)"
            }
        }
        
        // Approach B: Fallback heuristic cleanup if local Apple Intelligence is unavailable
        return fallbackBasicCleanup(rawText)
    }
    
    /// Fallback rule-based cleanup for older macOS systems or devices without Apple Intelligence
    private func fallbackBasicCleanup(_ text: String) -> String {
        var cleaned = text
        
        // Remove common speech fillers via regex
        let fillers = ["\\bum\\b", "\\buh\\b", "\\buhh\\b", "\\blike\\b", "\\byou know\\b"]
        for filler in fillers {
            cleaned = cleaned.replacingOccurrences(
                of: filler,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        // Clean up redundant spaces left by removed filler words
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}