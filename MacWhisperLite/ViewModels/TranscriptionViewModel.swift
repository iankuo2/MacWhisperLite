//
//  TranscriptionViewModel.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-06-20.
//


import Foundation
internal import Combine

@MainActor
class TranscriptionViewModel: ObservableObject {

    @Published var transcript = ""
    @Published var isTranscribing = false

    private let whisper = WhisperService()

    func transcribe(url: URL) async {

        isTranscribing = true

        do {

            transcript = try await whisper.transcribe(
                audioURL: url
            )

        } catch {

            transcript = error.localizedDescription
        }

        isTranscribing = false
    }
}
