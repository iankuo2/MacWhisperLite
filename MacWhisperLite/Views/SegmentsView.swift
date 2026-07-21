//
//  SegmentsView.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-07-20.
//


//
//  SegmentsView.swift
//  MacWhisperLite
//

import SwiftUI

struct SegmentsView: View {
    let text: String
    let fileName: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var segments: [TranscriptSegment] = []
    @State private var copiedIndex: Int? = nil

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
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            
            Divider()
            
            // MARK: - Segments List
            if segments.isEmpty {
                VStack {
                    Spacer()
                    Text("No segments available.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(segments) { segment in
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
                                
                                // Segment Content
                                Text(segment.text)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Copy Single Segment Button
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
                            .padding(12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 550, minHeight: 400)
        .onAppear {
            self.segments = SegmenterService.segment(text: text)
        }
    }
}