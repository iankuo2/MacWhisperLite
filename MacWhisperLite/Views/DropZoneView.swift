//
// DropZoneView.swift
//

import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {

    @ObservedObject var viewModel: TranscriptionViewModel

    @State private var isTargeted = false

    @State private var showingImporter = false

    var body: some View {

        VStack(spacing: 20) {

            Image(systemName: "waveform")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Drop audio files here")
                .font(.title2)

            Text("or click Open")
                .foregroundStyle(.secondary)

            Button("Open") {

                showingImporter = true
            }
            .buttonStyle(.borderedProminent)

        }
        .frame(width: 500,
               height: 250)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {

            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    isTargeted ? .blue : .gray,
                    style: StrokeStyle(
                        lineWidth: 3,
                        dash: [10]
                    )
                )
        }
        .dropDestination(for: URL.self) { urls, location in

            guard let url = urls.first else {
                return false
            }

            Task {

                await viewModel.transcribe(url: url)
            }

            return true

        } isTargeted: { inside in

            isTargeted = inside
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [
                .audio
            ]
        ) { result in

            switch result {

            case .success(let url):

                Task {

                    await viewModel.transcribe(url: url)
                }

            case .failure:

                break
            }
        }
    }
}
