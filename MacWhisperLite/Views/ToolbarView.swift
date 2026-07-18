//
//  ToolbarView.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-06-24.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ToolbarView: View {

    @ObservedObject var viewModel: TranscriptionViewModel

    @State private var showingImporter = false
    
    // 1. Add environment property to the top of the view struct
    @Environment(\.modelContext) private var modelContext

    // 🚨 NEW: Pass down the text currently active in the main view wrapper
    var activeTranscriptText: String
    var activeFileName: String
    
    var body: some View {

        HStack {

            Button {

                showingImporter = true

            } label: {

                Label("Open", systemImage: "folder")
            }

            // MARK: - Clipboard Actions
            Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(activeTranscriptText, forType: .string)
                    } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                    }
                    .disabled(activeTranscriptText.isEmpty) // 🚨 Driven by active text

            

            Spacer()
            
            // MARK: - Export drop-down menu
                        Menu {
                            Button("Export as Text (.txt)") {
                                TranscriptExporter.export(
                                    text: activeTranscriptText,
                                    defaultFileName: activeFileName,
                                    format: .txt
                                )
                            }
                            
                            Button("Export as Subtitles (.srt)") {
                                TranscriptExporter.export(
                                    text: activeTranscriptText,
                                    defaultFileName: activeFileName,
                                    format: .srt
                                )
                            }
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .disabled(activeTranscriptText.isEmpty) // 🚨 Driven by active text
            Spacer()
     
            ModelPickerView(
                selectedModel: $viewModel.selectedModel
            )

            Spacer()
            if viewModel.isTranscribing {

                ProgressView()
            }

        }
        .padding()
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.audio]
        ) { result in

            switch result {

            case .success(let url):

                Task {

                    await viewModel.transcribe(url: url, context: modelContext)
                }

            case .failure:

                break
            }
        }
    }
}
