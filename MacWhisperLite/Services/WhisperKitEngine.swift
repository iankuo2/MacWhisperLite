//
//  WhisperKitEngine.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-07-22.
//


//
//  WhisperKitEngine.swift
//  MacWhisperLite
//

import Foundation
import WhisperKit

actor WhisperKitEngine: TranscriptionEngine {
    let name = "WhisperKit (Core ML)"
    
    private var whisperKit: WhisperKit?
    private var currentModel: WhisperModel?
    
    /// Tracks download progress (0.0 to 1.0)
        @MainActor var downloadProgress: Double = 0.0
   /*
    
    // this method downloads the whisperKit model from internet but buggy
        func loadModel(_ model: WhisperModel) async throws {
            let modelName = await model.modelName(for: .whisperKit) // "openai_whisper-large-v3-v20240930_turbo"
            
            // Return early if this exact model is already initialized and ready
            if let kit = whisperKit, currentModel == model, kit.modelState == .loaded {
                return
            }
            
            print("📥 Preparing WhisperKit model: \(modelName)...")
            
            // Step 1: Explicitly download the model folder from Hugging Face
            let modelFolder = try await WhisperKit.download(
                variant: modelName,
                downloadBase: nil, // Uses default Application Support directory
                
                progressCallback: { [weak self] progress in
                    Task { [weak self] in
                        await self?.updateProgress(progress.fractionCompleted)
                    }
                }
            )
            
            print("✅ Download/Check complete. Initializing CoreML context from: \(modelFolder.path)")
            
            // Step 2: Initialize WhisperKit directly from the verified local folder
            let kit = try await WhisperKit(modelFolder: modelFolder.path)
            
            // Step 3: Verify context state
            guard kit.modelState == .loaded else {
                throw NSError(
                    domain: "WhisperKitEngine",
                    code: -1001,
                    userInfo: [NSLocalizedDescriptionKey: "WhisperKit downloaded successfully, but CoreML initialization failed."]
                )
            }
            
            self.whisperKit = kit
            self.currentModel = model
            print("🚀 WhisperKit context successfully initialized!")
        }
    */
        //loads from main bundle for offline use ~1.6GB memory
    func loadModel(_ model: WhisperModel) async throws {
        let targetModelName = await model.modelName(for: .whisperKit)
print("📦 Main Bundle Path:\n\(Bundle.main.bundlePath)")
        
 if let path = Bundle.main.path(forResource: "openai_whisper-large-v3-v20240930_turbo", ofType: nil) {
            print("✅ Successfully found model in Main Bundle at: \(path)")
  } else {
            print("❌ Model directory NOT found in Main Bundle root.")
 }
        
        
        // Locate model folder inside App Bundle
        guard let bundledFolderURL = Bundle.main.url(forResource: targetModelName, withExtension: nil) else {
            throw NSError(
                domain: "WhisperKitEngine",
                code: -404,
                userInfo: [NSLocalizedDescriptionKey: "Model folder '\(targetModelName)' not found in main bundle."]
            )
        }
        
        // Load WhisperKit context directly from local bundle URL
        let kit = try await WhisperKit(
            modelFolder: bundledFolderURL.path,
            download: false
        )
        
        guard kit.modelState == .loaded else {
            throw NSError(
                domain: "WhisperKitEngine",
                code: -1001,
                userInfo: [NSLocalizedDescriptionKey: "Failed to load bundled CoreML model."]
            )
        }
        
        self.whisperKit = kit
        self.currentModel = model
    }
        private func updateProgress(_ fraction: Double) {
            Task { @MainActor in
                self.downloadProgress = fraction
            }
        }
    
    func transcribe(audioURL: URL) async throws -> String {
        guard let pipe = whisperKit else { throw WhisperError.initializationFailed }
        let results = try await pipe.transcribe(audioPath: audioURL.path)
        return results.compactMap { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func transcribe(pcmBuffer: [Float]) async throws -> String {
        guard let pipe = whisperKit else { throw WhisperError.initializationFailed }
        let results = try await pipe.transcribe(audioArray: pcmBuffer)
        return results.compactMap { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func transcribeSegment(audioURL: URL, startTime: Double, duration: Double) async throws -> String {
        // Force model initialization if context is missing or un-loaded
        if whisperKit == nil || whisperKit?.modelState != .loaded {
            let activeModel = currentModel ?? .large
            try await loadModel(activeModel)
        }
        
        guard let kit = whisperKit, kit.modelState == .loaded else {
            throw NSError(
                domain: "WhisperKitEngine",
                code: -1002,
                userInfo: [NSLocalizedDescriptionKey: "File transcription error: Failed to initialize the Whisper context."]
            )
        }
        
        var options = DecodingOptions()
        
        // 1. Force task to transcribe (prevent English translation)
        options.task = .transcribe
        
        
        // 2. Enable automatic language detection with prefill prompt
        options.detectLanguage = true
        options.usePrefillPrompt = true
        
        // FIX: Modify the property directly instead of overwriting the object
        options.clipTimestamps = [Float(startTime), Float(startTime + duration)]
        
        let results = try await kit.transcribe(audioPath: audioURL.path, decodeOptions: options)
        return results.first?.text ?? ""
    }

}
