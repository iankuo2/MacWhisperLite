//
//  TranscriptExporter.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-07-18.
//

import AppKit
import UniformTypeIdentifiers
import AVFoundation

struct TranscriptExporter {
    
    enum ExportFormat {
        case txt
        case srt
    }
    
    /// Opens a native macOS Save panel and exports the transcript data.
    /// Note: Generating SRT now requires the source audioURL and model configuration.
    static func export(
        text: String,
        defaultFileName: String,
        format: ExportFormat,
        audioURL: URL? = nil,
        model: WhisperModel? = nil,
        whisperService: WhisperService? = nil
    ) {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        
        let cleanedName = defaultFileName
            .replacingOccurrences(of: ".audio", with: "")
            .replacingOccurrences(of: ".mp3", with: "")
            .replacingOccurrences(of: ".wav", with: "")
            .replacingOccurrences(of: ".m4a", with: "")
        
        switch format {
        case .txt:
            savePanel.allowedContentTypes = [.text]
            savePanel.nameFieldStringValue = "\(cleanedName).txt"
        case .srt:
            if let srtType = UTType(filenameExtension: "srt") {
                savePanel.allowedContentTypes = [srtType]
            } else {
                savePanel.allowedContentTypes = [.text]
            }
            savePanel.nameFieldStringValue = "\(cleanedName).srt"
        }
        
        savePanel.begin { response in
            guard response == .OK, let saveURL = savePanel.url else { return }
            
            Task {
                var contentToWrite = text
                
                // If requesting an SRT and we have access to the source file asset details:
                if format == .srt, let audioURL = audioURL, let model = model, let service = whisperService {
                    // Start security access if sandboxed
                    let didAccess = audioURL.startAccessingSecurityScopedResource()
                    contentToWrite = await generateTrueSRT(audioURL: audioURL, model: model, service: service)
                    if didAccess { audioURL.stopAccessingSecurityScopedResource() }
                } else if format == .srt {
                    // Fallback block if audio data isn't provided
                    contentToWrite = convertToMockSRT(text: text)
                }
                
                do {
                    try contentToWrite.write(to: saveURL, atomically: true, encoding: .utf8)
                    print("Successfully saved file to: \(saveURL.path)")
                } catch {
                    print("Failed to save file: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Core Timed SRT Logic
    
    /// Splits the original file into structured audio intervals and generates realistic timed captions.
    private static func generateTrueSRT(audioURL: URL, model: WhisperModel, service: WhisperService) async -> String {
        guard let audioFile = try? AVAudioFile(forReading: audioURL) else {
            return "1\n00:00:00,000 --> 00:00:05,000\n[Error reading source audio file details]"
        }
        
        let totalDuration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        let segmentDuration: TimeInterval = 5.0 // Time slice increment resolution (5 seconds per window card)
        
        var startTimes: [TimeInterval] = []
        var currentTime: TimeInterval = 0.0
        
        while currentTime < totalDuration {
            startTimes.append(currentTime)
            currentTime += segmentDuration
        }
        
        // Use a TaskGroup to process all time segments concurrently through the Whisper Service Actor
        var results: [TimeInterval: String] = [:]
        await withTaskGroup(of: (TimeInterval, String).self) { group in
            for startTime in startTimes {
                group.addTask {
                    do {
                        let text = try await service.transcribeSegment(
                            audioURL: audioURL,
                            model: model,
                            startTime: startTime,
                            duration: segmentDuration
                        )
                        return (startTime, text.trimmingCharacters(in: .whitespacesAndNewlines))
                    } catch {
                        return (startTime, "")
                    }
                }
            }
            
            for await (time, text) in group {
                results[time] = text
            }
        }
        
        // Sort and build out the timeline layout string systematically
        var srtOutput = ""
        var srtIndex = 1
        
        let sortedStarts = startTimes.sorted()
        for startTime in sortedStarts {
            guard let phraseText = results[startTime], !phraseText.isEmpty else { continue }
            
            let endTime = min(startTime + segmentDuration, totalDuration)
            
            srtOutput += "\(srtIndex)\n"
            srtOutput += "\(formatSRTTime(startTime)) --> \(formatSRTTime(endTime))\n"
            srtOutput += "\(phraseText)\n\n"
            
            srtIndex += 1
        }
        
        return srtOutput.isEmpty ? "1\n00:00:00,000 --> 00:00:05,000\n[No text elements detected]" : srtOutput
    }
    
    // MARK: - Format Utilities
    
    private static func formatSRTTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
    }
    
    /// Fallback string layout algorithm if source asset parameters are absent
    private static func convertToMockSRT(text: String) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var srtOutput = ""
        var currentTime: TimeInterval = 0.0
        
        for (index, sentence) in sentences.enumerated() {
            srtOutput += "\(index + 1)\n"
            srtOutput += "\(formatSRTTime(currentTime)) --> \(formatSRTTime(currentTime + 4.0))\n"
            srtOutput += "\(sentence).\n\n"
            currentTime += 4.5
        }
        return srtOutput
    }
}
