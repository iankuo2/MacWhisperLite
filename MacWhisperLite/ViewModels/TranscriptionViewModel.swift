//
//  TranscriptionViewModel.swift
//  MacWhisperLite
//
//  Modified by ian kuo on 2026-07-11
//


import Foundation
internal import Combine
import AVFAudio
import SwiftData

@MainActor
class TranscriptionViewModel: ObservableObject {
    
    private let whisper = WhisperService()
    private lazy var liveInputManager = LiveInputManager(whisperService: whisper)
    
    @Published var isTranscribing = false
    @Published var isLiveRecording = false
    @Published var transcript = ""
    @Published var selectedModel: WhisperModel = .tiny
    @Published var currentFileName: String = "Untitled Audio"
    
    init() {
        // Connect the manager callback to our UI text publisher
        liveInputManager.onTextReceived = { [weak self] liveText in
            guard let self = self else { return }
            // Filter out internal whisper noise artifacts like " [BLANK_AUDIO] " or empty strings
            let cleanedText = liveText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanedText.isEmpty {
                self.transcript = cleanedText
            }
        }
    }
    
    // Existing static file transcriber
    // Update existing TranscriptionViewModel with 30 sec Segemented File Streaming
    func transcribe(url: URL, context: ModelContext) async {
        isTranscribing = true
        transcript = "" // Clear canvas for live streaming updates
        
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let totalDuration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
            
            let segmentDuration: TimeInterval = 30.0 // 30-second sweet spot for Whisper
            var currentTime: TimeInterval = 0.0
            
            while currentTime < totalDuration {
                // Calculate how much time is left in the file
                let remainingTime = totalDuration - currentTime
                let currentChunkDuration = min(segmentDuration, remainingTime)
                
                // Transcribe just this slice
                let segmentText = try await whisper.transcribeSegment(
                    audioURL: url,
                    model: selectedModel,
                    startTime: currentTime,
                    duration: currentChunkDuration
                )
                
                let cleanedSegment = segmentText.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !cleanedSegment.isEmpty {
                    // Stream text directly to the UI view model string state
                    if transcript.isEmpty {
                        transcript = cleanedSegment
                    } else {
                        transcript += " " + cleanedSegment
                    }
                }
                
                // Advance window time index forward
                currentTime += segmentDuration
            }
            // ✅ PLACE CALL 1: File transcription finished successfully
            finalizeTranscription(context: context, url: url)
            
        } catch {
            transcript = "File transcription error: \(error.localizedDescription)"
        }
        
        isTranscribing = false
    }

    
    // New Live Streaming Transcriber controls
    func toggleLiveRecording(context: ModelContext) {
        if isLiveRecording {
            liveInputManager.stopStreaming()
            isLiveRecording = false
            
        // Live recording stopped, save the stream result
    // Wrap in a tiny delay if  WhisperService handles trailing text buffers asynchronously
            finalizeTranscription(context: context, url: nil)
        } else {
            transcript = "Listening..."
            isLiveRecording = true
            do {
                try liveInputManager.startStreaming(withModel: selectedModel)
            } catch {
                transcript = "Microphone access failed: \(error.localizedDescription)"
                isLiveRecording = false
            }
        }
    }
    
    // Call this function when a transcription successfully finishes
       // Make url optional (URL?) to cleanly accommodate live recordings
       func finalizeTranscription(context: ModelContext, url: URL?) {
           guard !transcript.isEmpty else { return }
           
           // Extract filename from URL or generate a timestamped one for live input
           if let fileURL = url {
               self.currentFileName = fileURL.lastPathComponent
           } else {
               let timestamp = Date().formatted(date: .abbreviated, time: .shortened)
               self.currentFileName = "Live Recording (\(timestamp))"
           }
           
           // Create the record
           let newRecord = TranscriptItem(
               fileName: currentFileName,
               text: transcript
           )
           
           // Insert into database
           context.insert(newRecord)
           
           do {
               try context.save()
           } catch {
               print("Failed to save transcript: \(error.localizedDescription)")
           }
       }
}
