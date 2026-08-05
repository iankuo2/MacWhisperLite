//
//  SegmenterService.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-07-20.
//


//
//  SegmenterService.swift
//  MacWhisperLite
//

import Foundation

struct SegmenterService {
    
    /// Breaks a block of text into structured, human-readable segments with estimated timing.
    static func segment(text: String, secondsPerSegment: TimeInterval = 4.0) -> [TranscriptSegment] {
        guard !text.isEmpty else { return [] }
        
        // Split by sentence terminators (. ! ?)
        let rawSentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var segments: [TranscriptSegment] = []
        var currentTime: TimeInterval = 0.0
        
        if rawSentences.isEmpty {
            // Fallback if there is no punctuation
            return [TranscriptSegment(index: 1, startTime: 0, endTime: 5.0, text: text)]
        }
        
        for (index, sentence) in rawSentences.enumerated() {
            let startTime = currentTime
            let endTime = currentTime + secondsPerSegment
            
            segments.append(
                TranscriptSegment(
                    index: index + 1,
                    startTime: startTime,
                    endTime: endTime,
                    text: "\(sentence)."
                )
            )
            
            currentTime = endTime
        }
        
        return segments
    }
}