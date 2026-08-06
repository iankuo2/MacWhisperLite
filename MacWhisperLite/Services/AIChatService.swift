import Foundation
internal import Combine
#if canImport(FoundationModels)
import FoundationModels
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
    4. Remove unnecessary filler words (e.g., "um", "uh", "like", "you know") while strictly preserving the original meaning and natural tone.
    5. Do NOT summarize or omit important content. Output ONLY the refined transcript text.
    """
    
    /// Entry point: Processes raw text by breaking it into ~500-word segments and refining each.
    func processTranscript(_ rawText: String) async -> String {
        let trimmedInput = rawText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return "" }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // 1. Break text into ~500-word segments
        let segments = segmentInto500Words(trimmedInput)
        var processedSegments: [String] = []
        
        // 2. Process each segment
        for segment in segments {
            let processed = await processSingleSegment(segment)
            if !processed.isEmpty {
                processedSegments.append(processed)
            }
        }
        
        // 3. Combine processed segments with double newline spacing
        return processedSegments.joined(separator: "\n\n")
    }
    
    /// Internal helper to refine a single text segment using Apple Foundation Models or local rules.
    private func processSingleSegment(_ segmentText: String) async -> String {
        let prompt = """
        \(systemPrompt)
        
        Raw Transcript:
        "\(segmentText)"
        
        Refined Transcript:
        """
        
        // Approach A: Native Apple Foundation Models API (Apple Intelligence)
        #if canImport(FoundationModels)
        if #available(macOS 15.0, iOS 18.0, *) {
            do {
                let session = LanguageModelSession()
                let response = try await session.respond(to: prompt)
                return response.content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            } catch {
                print("Apple Foundation Model generation failed: \(error.localizedDescription)")
                self.errorMessage = "Local AI generation failed: \(error.localizedDescription)"
            }
        }
        #endif
        
        // Approach B: Fallback basic rule-based cleanup
        return fallbackBasicCleanup(segmentText)
    }
    
    /// Helper: Segments text into blocks of roughly 500 words based on whitespace boundaries.
    private func segmentInto500Words(_ text: String) -> [String] {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard !words.isEmpty else { return [] }
        
        let targetWordCount = 500
        var segments: [String] = []
        var currentChunk: [String] = []
        
        for word in words {
            currentChunk.append(word)
            if currentChunk.count >= targetWordCount {
                segments.append(currentChunk.joined(separator: " "))
                currentChunk.removeAll(keepingCapacity: true)
            }
        }
        
        // Append any remaining words in the final chunk
        if !currentChunk.isEmpty {
            segments.append(currentChunk.joined(separator: " "))
        }
        
        return segments
    }
    
    /// Fallback rule-based cleanup for devices without Apple Intelligence
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
        return cleaned.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
}
