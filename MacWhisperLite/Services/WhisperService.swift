//
//  WhisperService.swift
//  MacWhisperLite
//

import Foundation

class WhisperService {
    
    func transcribe(audioURL: URL, model: WhisperModel) async throws -> String {
        // Ensure access token cleanly detaches once execution finishes
        defer { audioURL.stopAccessingSecurityScopedResource() }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    
                    guard let whisperPath = Bundle.main.path(forResource: "whisper-cli", ofType: nil) else {
                        throw NSError(
                            domain: "Whisper",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Cannot find whisper executable."]
                        )
                    }
                    //debug print everything in bundle
                   // print(Bundle.main.bundlePath)
                    
                    
                    //debug
                    guard let modelPath = Bundle.main.path(
                        forResource: model.filename,
                        ofType: "bin",
                        
                    )
                   /* print("========== Bundle ==========")

                    let resourceURL = Bundle.main.resourceURL!

                    let enumerator = FileManager.default.enumerator(
                        at: resourceURL,
                        includingPropertiesForKeys: nil
                    )!

                    for case let file as URL in enumerator {

                        print(file.path)
                    }

                    print("============================")
                    */
                    else {

                        throw NSError(
                            domain: "Whisper",
                            code: 2,
                            userInfo: [
                                NSLocalizedDescriptionKey:
                                "Cannot find \(model.displayName) model."
                            ]
                        )
                    }
               
                    process.executableURL = URL(fileURLWithPath: whisperPath)
                    
                    process.arguments = [
                        "-m", modelPath,
                        "-f", audioURL.path(percentEncoded: false),
                        "-nt"
                    ]
                    
                    let outputPipe = Pipe()
                    process.standardOutput = outputPipe
                    let errorPipe = Pipe()
                    process.standardError = errorPipe
                    
                    try process.run()
                    
                    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    process.waitUntilExit()
                    
                    if process.terminationStatus != 0 {
                        let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown binary exit failure."
                        throw NSError(
                            domain: "Whisper",
                            code: Int(process.terminationStatus),
                            userInfo: [NSLocalizedDescriptionKey: "Whisper CLI execution failed: \(errorString)"]
                        )
                    }
                    
                    let result = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: result.trimmingCharacters(in: .whitespacesAndNewlines))
                
            
                    
                } catch {
                    continuation.resume(throwing: error)
                }
                
            }
        }
    }
}
