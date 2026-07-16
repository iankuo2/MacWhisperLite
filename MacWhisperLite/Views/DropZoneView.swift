//
// DropZoneView.swift
//

import SwiftUI
import UniformTypeIdentifiers
import SwiftData

struct DropZoneView: View {

    @ObservedObject var viewModel: TranscriptionViewModel

    @State private var isTargeted = false

    @State private var showingImporter = false

    // 1. Add environment property to the top of the view struct
    @Environment(\.modelContext) private var modelContext
    var body: some View {

        VStack() {

           
        }
        // A transparent view that expands to fill all available space in the parent container
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // Overlay a thin border around the edge that only highlights blue when a drag hover is active
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue, lineWidth: 3)
                    )
                    .padding(16) // Generates a clean margin between the window edge and the highlighted border

        .dropDestination(for: URL.self) { urls, location in

            guard let url = urls.first else {
                return false
            }

            // Explicitly gain sandboxed read permissions immediately during the drop action loop
            guard url.startAccessingSecurityScopedResource() else {
                return false
            }

            Task {
                // Hand off the URL. ViewModel/Service will need to release it when done.
                await viewModel.transcribe(url: url, context: modelContext)
            }

            return true

        } isTargeted: { inside in
            isTargeted = inside
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.audio]
        ) { result in
            switch result {
            case .success(let url):
                // Match the same logic: secure right away on selection
                guard url.startAccessingSecurityScopedResource() else { return }
                Task {
                    await viewModel.transcribe(url: url, context: modelContext)
                }
            case .failure:
                break
            }
        }

    }
}
