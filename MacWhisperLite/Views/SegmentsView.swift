//
//  SegmentsView.swift
//  MacWhisperLite
//

import SwiftUI

struct SegmentsView: View {
    @State var text: String
    let fileName: String
    @Environment(\.dismiss) private var dismiss
    
    // State management
    @State private var segments: [TranscriptSegment] = []
    @State private var copiedIndex: Int? = nil
    
    // Search Tool state
    @State private var showSearchTool = false
    @State private var searchText = ""
    @State private var replaceText = ""
    @State private var showReplace = false
    @State private var currentMatchIndex = 0

    // MARK: - Computed Search Filters
    private var filteredSegments: [TranscriptSegment] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespaces)
        if trimmedQuery.isEmpty {
            return segments
        }
        return segments.filter { segment in
            segment.text.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }
    
    private var totalMatchCount: Int {
        guard !searchText.isEmpty else { return 0 }
        return filteredSegments.reduce(0) { count, segment in
            count + segment.text.components(separatedBy: searchText).count - 1
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Transcript Segments")
                        .font(.title2)
                        .bold()
                    Text(fileName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Search Toggle Button
                Button {
                    withAnimation {
                        showSearchTool.toggle()
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)

                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            
            // MARK: - Search Text Tool View
            if showSearchTool {
                SearchTextToolView(
                    searchText: $searchText,
                    replaceText: $replaceText,
                    showReplace: $showReplace,
                    matchCount: totalMatchCount,
                    currentMatchIndex: currentMatchIndex,
                    onNext: navigateNext,
                    onPrevious: navigatePrevious,
                    onReplace: performReplace,
                    onReplaceAll: performReplaceAll,
                    onClose: {
                        withAnimation {
                            showSearchTool = false
                            searchText = ""
                        }
                    }
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Divider()
            
            // MARK: - Segments List
            if filteredSegments.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "No segments available." : "No matching segments found.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredSegments, id: \.id) { (segment: TranscriptSegment) in
                                HStack(alignment: .top, spacing: 12) {
                                    // Timestamp Chip
                                    Text(segment.formattedTimestamp)
                                        .font(.caption)
                                        .monospacedDigit()
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor.opacity(0.15))
                                        .foregroundColor(.accentColor)
                                        .cornerRadius(6)
                                    
                                    // Highlighted Segment Text using AttributedString
                                    Text(highlightedAttributedString(for: segment.text, query: searchText))
                                        .font(.body)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    // Copy Segment Button
                                    Button {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(segment.text, forType: .string)
                                        copiedIndex = segment.index
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            if copiedIndex == segment.index {
                                                copiedIndex = nil
                                            }
                                        }
                                    } label: {
                                        Image(systemName: copiedIndex == segment.index ? "checkmark" : "doc.on.doc")
                                            .font(.caption)
                                            .foregroundColor(copiedIndex == segment.index ? .green : .secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .id(segment.id)
                                .padding(12)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .frame(minWidth: 620, minHeight: 450)
        .onAppear {
            self.segments = SegmenterService.segment(text: text)
        }
        .onChange(of: searchText) { _, _ in
            currentMatchIndex = 0
        }
    }
    
    // MARK: - Search Navigation Actions
    private func navigateNext() {
        guard totalMatchCount > 0 else { return }
        currentMatchIndex = (currentMatchIndex + 1) % totalMatchCount
    }
    
    private func navigatePrevious() {
        guard totalMatchCount > 0 else { return }
        currentMatchIndex = (currentMatchIndex - 1 + totalMatchCount) % totalMatchCount
    }
    
    // MARK: - Replace Operations
    private func performReplace() {
        guard !searchText.isEmpty else { return }
        if let range = text.range(of: searchText, options: .caseInsensitive) {
            text.replaceSubrange(range, with: replaceText)
            self.segments = SegmenterService.segment(text: text)
        }
    }
    
    private func performReplaceAll() {
        guard !searchText.isEmpty else { return }
        text = text.replacingOccurrences(of: searchText, with: replaceText, options: .caseInsensitive)
        self.segments = SegmenterService.segment(text: text)
    }

    // MARK: - AttributedString Highlight Generator
    private func highlightedAttributedString(for textString: String, query: String) -> AttributedString {
        var attributed = AttributedString(textString)
        guard !query.isEmpty else { return attributed }
        
        var searchRange = textString.startIndex..<textString.endIndex
        
        while let matchRange = textString.range(of: query, options: .caseInsensitive, range: searchRange) {
            if let attributedRange = Range(matchRange, in: attributed) {
                attributed[attributedRange].backgroundColor = .yellow
                attributed[attributedRange].foregroundColor = .black
            }
            searchRange = matchRange.upperBound..<textString.endIndex
        }
        
        return attributed
    }
}
