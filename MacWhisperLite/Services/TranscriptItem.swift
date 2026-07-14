//
//  TranscriptItem.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-07-13.
//


import Foundation
import SwiftData

@Model
final class TranscriptItem {
    var id: UUID
    var timestamp: Date
    var fileName: String
    var text: String
    
    init(id: UUID = UUID(), timestamp: Date = Date(), fileName: String, text: String) {
        self.id = id
        self.timestamp = timestamp
        self.fileName = fileName
        self.text = text
    }
}
