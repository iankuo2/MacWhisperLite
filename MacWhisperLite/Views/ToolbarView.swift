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

    var body: some View {

        HStack {

            Button {

                showingImporter = true

            } label: {

                Label("Open", systemImage: "folder")
            }

            Button {

                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(
                    viewModel.transcript,
                    forType: .string
                )

            } label: {

                Label("Copy", systemImage: "doc.on.doc")
            }
            .disabled(viewModel.transcript.isEmpty)

            Button {

                viewModel.transcript = ""

            } label: {

                Label("Clear", systemImage: "trash")
            }
            .disabled(viewModel.transcript.isEmpty)

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
