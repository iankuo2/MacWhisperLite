import Foundation

class WhisperService {
    
    func transcribe(audioURL: URL) async throws -> String {
        // 1. Secure Permission Step for Sandboxed Apps
        // Required when files are imported via fileImporter panel sheets
        guard audioURL.startAccessingSecurityScopedResource() else {
            throw NSError(
                domain: "Whisper",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Permission denied reading the source audio file path layout."]
            )
        }
        // Ensure access token cleanly detaches once code execution block unmounts
        defer { audioURL.stopAccessingSecurityScopedResource() }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    // Path to whisper executable binary
                    guard let whisperPath = Bundle.main.path(forResource: "whisper-cli", ofType: nil) else {
                        throw NSError(
                            domain: "Whisper",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Cannot find whisper executable."]
                        )
                    }
                    // Path to model
                    guard let modelPath = Bundle.main.path(forResource: "ggml-base.en", ofType: "bin") else {
                        throw NSError(
                            domain: "Whisper",
                            code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "Cannot find model."]
                        )
                    }
                    process.executableURL = URL(fileURLWithPath: whisperPath)
                    
                    // Optimization arguments for modern terminal deployments:
                    // "-nt" outputs raw clean transcript text without timestamp fragments
                    process.arguments = [
                        "-m", modelPath,
                        "-f", audioURL.path(percentEncoded: false),
                        "-nt"
                    ]
                    
                    let outputPipe = Pipe()
                    process.standardOutput = outputPipe
                    // Crucial: Create error pipelines to debug underlying model exceptions
                    let errorPipe = Pipe()
                    process.standardError = errorPipe
                    
                    try process.run()
                    
                    // FIX: Read pipeline bytes BEFORE waiting to avoid thread buffer deadlock freezes
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

