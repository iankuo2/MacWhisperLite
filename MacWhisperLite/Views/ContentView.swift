//  ContentView.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-06-20.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum SidebarSelection: Hashable {
    case newTranscription
    case liveCaptions
    case settings
    case historyItem(TranscriptItem)
}

struct ContentView: View {
    @StateObject private var viewModel = TranscriptionViewModel()

    // Track the universal selection state for the entire sidebar list
    @State private var selectedTab: SidebarSelection? = .newTranscription
    
    @State private var isShowingFilePicker = false
    @Query(sort: \TranscriptItem.timestamp, order: .reverse) private var historyItems: [TranscriptItem]
    @Environment(\.modelContext) private var modelContext
    @State private var isDraggingFile = false
    
    var body: some View {
        NavigationSplitView {
            // MARK: - Column 1: Sidebar
            // 🚨 Binding selection here ensures the blue highlighting follows user clicks instantly
            List(selection: Binding(
                get: { self.selectedTab },
                set: { newValue in
                    self.selectedTab = newValue
                    // 🚨 Intercept sidebar clicks to clear out old active states cleanly
                    if newValue == .newTranscription || newValue == .liveCaptions {
                        prepareForNewView()
                    }
                }
            )) {
                Section {
                    NavigationLink(value: SidebarSelection.newTranscription) {
                        Label("Home", systemImage: "house")
                    }
                    
                    NavigationLink(value: SidebarSelection.liveCaptions) {
                        Label("Live Captions", systemImage: "captions.bubble")
                    }
                    
                    NavigationLink(value: SidebarSelection.settings) {
                        Label("Settings", systemImage: "gear")
                    }
                }
                
                // Saved Transcripts Section
                if !historyItems.isEmpty {
                    Section("Saved Transcripts") {
                        ForEach(historyItems) { item in
                            NavigationLink(value: SidebarSelection.historyItem(item)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.fileName)
                                        .font(.body)
                                        .lineLimit(1)
                                    Text(item.timestamp, style: .date)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                     // If we delete the currently viewed item, revert selection to home
                                    if case .historyItem(let selectedItem) = selectedTab, selectedItem == item {
                                        selectedTab = .newTranscription
                                        prepareForNewView()
                                    }
                                    modelContext.delete(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                
                // History Section
                Section("History") {
                    Text("No deep history logs available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
            
        } content: {
            Text("").navigationSplitViewColumnWidth(0)
            
        } detail: {
            // MARK: - Column 3: Main Detail View
            ZStack {
                switch selectedTab {
                case .newTranscription, .none:
                    transcriptionWorkspace(historicalItem: nil)
                    
                case .liveCaptions:
                    LiveCaptionsView(viewModel: viewModel)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                case .settings:
                    Text("Settings Coming Soon")
                        .font(.title)
                        .foregroundColor(.secondary)
                    
                case .historyItem(let item):
                    transcriptionWorkspace(historicalItem: item)
                }
                
                if isDraggingFile {
                    DropZoneView(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
                        .transition(.opacity)
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                guard let droppedURL = urls.first else { return false }
                guard droppedURL.startAccessingSecurityScopedResource() else { return false }
                
                // Clear state ready for the fresh file drop import
                prepareForNewView()
                selectedTab = .newTranscription
                
                Task {
                    await viewModel.transcribe(url: droppedURL, context: modelContext)
                }
                return true
            } isTargeted: { targeted in
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.isDraggingFile = targeted
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.audio, .quickTimeMovie],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let selectedURL = urls.first else { return }
                guard selectedURL.startAccessingSecurityScopedResource() else { return }
                
                prepareForNewView()
                selectedTab = .newTranscription
                
                Task {
                    await viewModel.transcribe(url: selectedURL, context: modelContext)
                }
            case .failure(let error):
                print("Failed to select file: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Extracted Transcription View (Update inside ContentView.swift)
    private func transcriptionWorkspace(historicalItem: TranscriptItem?) -> some View {
        // 🚨 1. Determine what text and file name are currently active
        let currentText = historicalItem?.text ?? viewModel.transcript
        let currentFileName = historicalItem?.fileName ?? "Untitled Transcription"
        
        return VStack(spacing: 0) {
            // 🚨 2. Pass the computed active strings straight into the toolbar structure
            ToolbarView(
                viewModel: viewModel,
                activeTranscriptText: currentText,
                activeFileName: currentFileName
            )
            Divider()
            
            if let item = historicalItem {
                historyDetailWorkspace(for: item)
            } else if viewModel.transcript.isEmpty && !viewModel.isTranscribing {
                DashboardGridView { action in
                    handleDashboardAction(action)
                }
            } else {
                ZStack(alignment: .bottomTrailing) {
                    TextEditor(text: $viewModel.transcript)
                        .font(.body)
                        .padding()
                    if viewModel.isTranscribing {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Streaming text...").font(.caption).foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
                        .cornerRadius(6)
                        .padding()
                    }
                }
            }
        }
    }
    
    // MARK: - State Management Helper
    // 🚨 Resets data layers clean so view configurations can toggle dynamic dashboard layout rules safely
    private func prepareForNewView() {
        viewModel.transcript = ""
    }
    
    // MARK: - Dashboard Action Handler
    private func handleDashboardAction(_ action: DashboardAction) {
        switch action {
        case .liveCaptions:
            prepareForNewView()
            self.selectedTab = .liveCaptions
        case .openFiles:
            self.isShowingFilePicker = true
        default:
            print("Dashboard trigger: \(action)")
        }
    }
    
    // MARK: - Extracted History Detail View
    private func historyDetailWorkspace(for item: TranscriptItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.fileName).font(.title).bold()
                    HStack(spacing: 4) {
                        Text(item.timestamp, style: .date)
                        Text("at")
                        Text(item.timestamp, style: .time)
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    // Clicking X cleanly resets the highlight state back to Home!
                    selectedTab = .newTranscription
                    prepareForNewView()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            ScrollView {
                Text(item.text)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
    }
}
