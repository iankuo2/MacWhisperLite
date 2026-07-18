//
//  TranscriptExporter.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-07-17.
//


//
//  TranscriptExporter.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-07-17.
//

import AppKit
import UniformTypeIdentifiers

struct TranscriptExporter {
    
    enum ExportFormat {
        case txt
        case srt
    }
    
    /// Opens a native macOS Save panel and exports the text in the requested format.
    static func export(text: String, defaultFileName: String, format: ExportFormat) {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        
        switch format {
        case .txt:
            savePanel.allowedContentTypes = [.text]
            savePanel.nameFieldStringValue = defaultFileName.replacingOccurrences(of: ".audio", with: "") + ".txt"
        case .srt:
            // SubRip (SRT) format uses a plain text identifier extension
            if let srtType = UTType(filenameExtension: "srt") {
                savePanel.allowedContentTypes = [srtType]
            } else {
                savePanel.allowedContentTypes = [.text]
            }
            savePanel.nameFieldStringValue = defaultFileName.replacingOccurrences(of: ".audio", with: "") + ".srt"
        }
        
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            
            let contentToWrite: String
            switch format {
            case .txt:
                contentToWrite = text
            case .srt:
                contentToWrite = convertToSRT(text: text)
            }
            
            do {
                try contentToWrite.write(to: url, atomically: true, encoding: .utf8)
                print("Successfully saved file to: \(url.path)")
            } catch {
                print("Failed to save file: \(error.localizedDescription)")
            }
        }
    }
    
    /// Converts a continuous block of text into a simulated, readable SRT format block.
    /// (Since rolling stream/segment blocks don't match exact phrase timings unless you track exact word structures, 
    /// this breaks text down into clean, mock chronological caption cards).
    private static func convertToSRT(text: String) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var srtOutput = ""
        var currentTime: TimeInterval = 0.0
        let timePerSentence: TimeInterval = 4.0 // Simulated duration anchor per caption segment
        
        for (index, sentence) in sentences.enumerated() {
            let itemNumber = index + 1
            let startTime = currentTime
            let endTime = currentTime + timePerSentence
            
            srtOutput += "\(itemNumber)\n"
            srtOutput += "\(formatSRTTime(startTime)) --> \(formatSRTTime(endTime))\n"
            srtOutput += "\(sentence).\n\n"
            
            currentTime += timePerSentence + 0.5 // Brief interval gap
        }
        
        return srtOutput.isEmpty ? "1\n00:00:00,000 --> 00:00:05,000\n\(text)" : srtOutput
    }
    
    /// Formats time intervals to standard SRT: HH:MM:SS,mmm
    private static func formatSRTTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
    }
}