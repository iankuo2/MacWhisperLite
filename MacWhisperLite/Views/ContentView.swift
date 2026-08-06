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
    @StateObject private var aiService = AIChatService()

    // Track the universal selection state for the entire sidebar list
    @State private var selectedTab: SidebarSelection? = .newTranscription
    
    @State private var isShowingFilePicker = false
    @Query(sort: \TranscriptItem.timestamp, order: .reverse) private var historyItems: [TranscriptItem]
    @Environment(\.modelContext) private var modelContext
    @State private var isDraggingFile = false
    
    // Store AI refined output locally for active sessions
    @State private var refinedTranscript: String = ""
    @State private var showingRefinedView: Bool = false
    
    var body: some View {
        NavigationSplitView {
            // MARK: - Column 1: Sidebar
            List(selection: Binding(
                get: { self.selectedTab },
                set: { newValue in
                    self.selectedTab = newValue
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
    
    // MARK: - Extracted Transcription View
    private func transcriptionWorkspace(historicalItem: TranscriptItem?) -> some View {
        let currentText = historicalItem?.text ?? viewModel.transcript
        let currentFileName = historicalItem?.fileName ?? "Untitled Transcription"
        
        // Button condition: Only show if NOT transcribing AND there is valid text
        let canRefineWithAI = !viewModel.isTranscribing && !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        return VStack(spacing: 0) {
            // Header Bar containing Toolbar and AI Refine trigger button
            HStack {
                ToolbarView(
                    viewModel: viewModel,
                    activeTranscriptText: currentText,
                    activeFileName: currentFileName
                )
                
                Spacer()
                
                // MARK: - AI Refine Button
                if canRefineWithAI {
                    Button {
                        Task {
                            let result = await aiService.processTranscript(currentText)
                            if !result.isEmpty {
                                self.refinedTranscript = result
                                self.showingRefinedView = true
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if aiService.isProcessing {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Refining...")
                            } else {
                                Image(systemName: "sparkles")
                                Text("AI Clean Up")
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(aiService.isProcessing)
                    .padding(.trailing, 12)
                }
            }
            
            Divider()
            
            if let item = historicalItem {
                historyDetailWorkspace(for: item)
            } else if viewModel.transcript.isEmpty && !viewModel.isTranscribing {
                DashboardGridView { action in
                    handleDashboardAction(action)
                }
            } else {
                ZStack(alignment: .bottomTrailing) {
                    if showingRefinedView && !refinedTranscript.isEmpty {
                        // Display Refined Text Output View with option to revert
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("✨ AI Refined Output")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.purple)
                                Spacer()
                                Button("Show Original") {
                                    showingRefinedView = false
                                }
                                .font(.caption)
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                            
                            TextEditor(text: $refinedTranscript)
                                .font(.body)
                                .padding(.horizontal)
                        }
                    } else {
                        // Original Transcript View
                        TextEditor(text: $viewModel.transcript)
                            .font(.body)
                            .padding()
                    }
                    
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
    private func prepareForNewView() {
        viewModel.transcript = ""
        refinedTranscript = ""
        showingRefinedView = false
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
                Text(showingRefinedView ? refinedTranscript : item.text)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
    }
}
