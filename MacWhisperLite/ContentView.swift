//
//  ContentView.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-06-20.
//

import SwiftUI
import UniformTypeIdentifiers


struct ContentView: View {

    @StateObject private var vm = TranscriptionViewModel()
    @State private var importing = false

    var body: some View {

        VStack(spacing: 20) {

            Button("Open Audio File") {
                importing = true
            }

            if vm.isTranscribing {
                ProgressView()
            }

            TextEditor(text: $vm.transcript)
                .frame(minHeight: 300)

            Button("Copy Transcript") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(
                    vm.transcript,
                    forType: .string
                )
            }
        }
        .padding()
        
        .fileImporter(
            isPresented: $importing,
            allowedContentTypes: [.audio]
        ) { result in

            switch result {

            case .success(let url):
                Task {
                    await vm.transcribe(url: url)
                }

            case .failure(let error):
                print(error)
            }
        }
    }
}

#Preview {
    ContentView()
}
