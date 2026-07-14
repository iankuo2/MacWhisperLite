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
    case history
    case settings
}

struct ContentView: View {
    @StateObject private var viewModel = TranscriptionViewModel()
    @State private var selectedTab: SidebarSelection? = .newTranscription
    
    @Query(sort: \TranscriptItem.timestamp, order: .reverse) private var historyItems: [TranscriptItem]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedHistoryItem: TranscriptItem?
    
    var body: some View {
        // Use the native 3-column constructor
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
                            // Clear detail selection if the active item is deleted
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
                // Hide or empty the middle column for other tabs
                Text("")
                    .navigationSplitViewColumnWidth(0)
            }
            
        } detail: {
            // MARK: - Column 3: Main Detail View
            switch selectedTab {
            case .newTranscription, .none:
                transcriptionWorkspace
                
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
        }
        .frame(minWidth: 900, minHeight: 600)
    }
    
    // MARK: - Extracted Transcription View
    private var transcriptionWorkspace: some View {
        VStack(spacing: 0) {
            ToolbarView(viewModel: viewModel)
            Divider()
            if viewModel.transcript.isEmpty && !viewModel.isTranscribing {
                Spacer()
                DropZoneView(viewModel: viewModel)
                Spacer()
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
    
    // MARK: - Extracted History Detail View
    private func historyDetailWorkspace(for item: TranscriptItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.fileName)
                .font(.title)
                .bold()
            // Displays exact date and exact time side-by-side
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
