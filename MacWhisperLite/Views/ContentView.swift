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
    case history
    case settings
}

struct ContentView: View {
    @StateObject private var viewModel = TranscriptionViewModel()
    @State private var selectedTab: SidebarSelection? = .newTranscription
    
    // Track file picker presentation state
    @State private var isShowingFilePicker = false
    
    @Query(sort: \TranscriptItem.timestamp, order: .reverse) private var historyItems: [TranscriptItem]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedHistoryItem: TranscriptItem?
    
    // 1. Added state to track whether the user is actively dragging a file over the window
    @State private var isDraggingFile = false
    
    var body: some View {
        NavigationSplitView {
            // MARK: - Column 1: Sidebar
            List(selection: $selectedTab) {
                NavigationLink(value: SidebarSelection.newTranscription) {
                    Label("Home", systemImage: "house")
                }
                
                NavigationLink(value: SidebarSelection.history) {
                    Label("History", systemImage: "clock")
                }
                NavigationLink(value: SidebarSelection.settings) {
                    Label("Settings", systemImage: "gear")
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
            
        } content: {
            // MARK: - Column 2: Middle Column (Conditional)
            switch selectedTab {
            case .history:
                List(historyItems, selection: $selectedHistoryItem) { item in
                    NavigationLink(value: item) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.fileName)
                                .font(.headline)
                                .lineLimit(1)
                            Text(item.timestamp, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            if selectedHistoryItem == item {
                                selectedHistoryItem = nil
                            }
                            modelContext.delete(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
                
            default:
                Text("")
                    .navigationSplitViewColumnWidth(0)
            }
            
        } detail: {
            // MARK: - Column 3: Main Detail View
            ZStack {
                // Main workspace views
                switch selectedTab {
                case .newTranscription, .none:
                    transcriptionWorkspace
                    
                case .liveCaptions:
                    LiveCaptionsView(viewModel: viewModel)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                case .history:
                    if let item = selectedHistoryItem {
                        historyDetailWorkspace(for: item)
                    } else {
                        Text("Select a transcript from the list")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    
                case .settings:
                    Text("Settings Coming Soon")
                        .font(.title)
                        .foregroundColor(.secondary)
                }
                
                // 2. Full-screen DropZone Overlay
                // This takes up 100% of the remaining space next to the sidebar
                if isDraggingFile {
                    DropZoneView(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
                        .transition(.opacity)
                }
            }
            // 3. Registering the drop destination across the entire detail workspace
            .dropDestination(for: URL.self) { urls, _ in
                guard let droppedURL = urls.first else { return false }
                
                // Switch tab to home/new transcription if they dropped it elsewhere
                selectedTab = .newTranscription
                
                // Trigger the transcription
                Task {
                    await viewModel.transcribe(url: droppedURL, context: modelContext)
                }
                return true
            } isTargeted: { targeted in
                // Dynamic animation when file enters/leaves the window boundary
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.isDraggingFile = targeted
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        // 🚨 Attach the native file importer to the Column 3 Main Detail View container
        .fileImporter(
                    isPresented: $isShowingFilePicker,
                    allowedContentTypes: [.audio, .quickTimeMovie], // Adjust to your supported formats
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        guard let selectedURL = urls.first else { return }
                        
                        // Start transcription
                        Task {
                            await viewModel.transcribe(url: selectedURL, context: modelContext)
                        }
                    case .failure(let error):
                        print("Failed to select file: \(error.localizedDescription)")
                    }
                }
    }
    
    // MARK: - Extracted Transcription View (Home Tab)
        private var transcriptionWorkspace: some View {
            VStack(spacing: 0) {
                ToolbarView(viewModel: viewModel)
                Divider()
                
                if viewModel.transcript.isEmpty && !viewModel.isTranscribing {
                    // Show the interactive dashboard grid as the default landing view!
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
    }
    // MARK: - Dashboard Action Handler
        private func handleDashboardAction(_ action: DashboardAction) {
            switch action {
            case .liveCaptions:
                // Switch current Sidebar selection directly to Live Captions
                self.selectedTab = .liveCaptions
                
            case .openFiles:
                // Trigger my system file open picker logic
                // Toggle the state to trigger the file picker overlay
                self.isShowingFilePicker = true
                
           /* case .voiceMemo:
                // Optionally auto-toggle live record state instantly
                viewModel.toggleLiveRecording(context: modelContext)
            */
            default:
                print("Dashboard trigger: \(action)")
            }
        }
    // MARK: - Extracted History Detail View
    private func historyDetailWorkspace(for item: TranscriptItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.fileName)
                .font(.title)
                .bold()
            HStack(spacing: 4) {
                Text(item.timestamp, style: .date)
                Text("at")
                Text(item.timestamp, style: .time)
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
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

#Preview {
    ContentView()
}
