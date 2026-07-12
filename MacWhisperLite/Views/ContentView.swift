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

            // If completely empty and idle, show drop zone
            if viewModel.transcript.isEmpty && !viewModel.isTranscribing {

                Spacer()

                DropZoneView(viewModel: viewModel)

                Spacer()

            } else {

                // Show the TextEditor immediately as text starts streaming
                ZStack(alignment: .bottomTrailing) {
                    
                    TextEditor(text: $viewModel.transcript)
                        .font(.body)
                        .padding()
                    
                    // A subtle, non-intrusive indicator in the corner instead of blocking the screen
                    if viewModel.isTranscribing {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Streaming text...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
                        .cornerRadius(6)
                        .padding()
                    }
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
