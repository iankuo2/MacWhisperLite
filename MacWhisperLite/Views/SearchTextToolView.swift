//
//  SearchTextToolView.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-07-21.
//


//
//  SearchTextToolView.swift
//  MacWhisperLite
//

import SwiftUI

struct SearchTextToolView: View {
    @Binding var searchText: String
    @Binding var replaceText: String
    @Binding var showReplace: Bool
    
    var matchCount: Int
    var currentMatchIndex: Int
    
    var onNext: () -> Void
    var onPrevious: () -> Void
    var onReplace: () -> Void
    var onReplaceAll: () -> Void
    var onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // MARK: - Find Bar
            HStack(spacing: 8) {
                // Search Input Field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Find", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                
                // Match Count Display
                Text(matchCount > 0 ? "\(currentMatchIndex + 1) of \(matchCount)" : "0 matches")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(minWidth: 65, alignment: .trailing)
                
                // Navigation Buttons (< and >)
                HStack(spacing: 2) {
                    Button(action: onPrevious) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(matchCount == 0)
                    
                    Button(action: onNext) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(matchCount == 0)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                // Show/Hide Replace Controls Toggle
                Toggle("Replace", isOn: $showReplace)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                
                // Close Toolbar
                Button("Done", action: onClose)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            
            // MARK: - Replace Bar (Collapsible)
            if showReplace {
                HStack(spacing: 8) {
                    HStack {
                        Image(systemName: "pencil")
                            .foregroundColor(.secondary)
                        TextField("Replace with...", text: $replaceText)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    
                    Button("Replace", action: onReplace)
                        .disabled(matchCount == 0 || searchText.isEmpty)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    
                    Button("Replace All", action: onReplaceAll)
                        .disabled(matchCount == 0 || searchText.isEmpty)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(10)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: showReplace)
    }
}