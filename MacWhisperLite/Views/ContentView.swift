//
//  ContentView.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-06-20.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {

    @StateObject private var viewModel = TranscriptionViewModel()

    var body: some View {

        VStack(spacing: 0) {

            ToolbarView(viewModel: viewModel)

            Divider()

            if viewModel.transcript.isEmpty && !viewModel.isTranscribing {

                Spacer()

                DropZoneView(viewModel: viewModel)

                Spacer()

            } else {

                VStack(spacing: 12) {

                    if viewModel.isTranscribing {

                        ProgressView("Transcribing...")
                            .padding()
                    }

                    TextEditor(text: $viewModel.transcript)
                        .font(.body)
                        .padding()
                }
            }
        }
        .frame(minWidth: 800,
               minHeight: 600)
    }
}

#Preview {
    ContentView()
}
