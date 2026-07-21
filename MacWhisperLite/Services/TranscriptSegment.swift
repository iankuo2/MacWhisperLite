//
//  TranscriptSegment.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-07-20.
//


//
//  TranscriptSegment.swift
//  MacWhisperLite
//

import Foundation

struct TranscriptSegment: Identifiable, Hashable {
    let id = UUID()
    let index: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
    
    var formattedTimestamp: String {
        let startMinutes = Int(startTime) / 60
        let startSeconds = Int(startTime) % 60
        let endMinutes = Int(endTime) / 60
        let endSeconds = Int(endTime) % 60
        
        return String(format: "%02d:%02d - %02d:%02d", startMinutes, startSeconds, endMinutes, endSeconds)
    }
}