//
//  DashboardGridView.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-07-15.
//

import SwiftUI

// 1. Define the Action Types
enum DashboardAction {
    case voiceMemo
    case openFiles
    case liveCaptions
    case manageModels
    
}

// 2. Define the Data Structure
struct DashboardItem: Identifiable {
    let id = UUID()
    let title: String
    let iconName: String
    let isSystemIcon: Bool
    let action: DashboardAction
    var isHighlighted: Bool = false
}

struct DashboardGridView: View {
    // Parent callback handling tile actions
    var onSelect: (DashboardAction) -> Void
    
    // Sample Data representing your layout
    let items = [
        DashboardItem(title: "Voice Memo", iconName: "mic", isSystemIcon: true, action: .voiceMemo),
        DashboardItem(title: "Open Files", iconName: "folder.badge.plus", isSystemIcon: true, action: .openFiles),
                
        DashboardItem(title: "Live Captions", iconName: "captions.bubble", isSystemIcon: true, action: .liveCaptions),
        DashboardItem(title: "Manage Models", iconName: "shippingbox", isSystemIcon: true, action: .manageModels)
    ]
    
    let columns = [
        GridItem(.adaptive(minimum: 140, maximum: .infinity), spacing: 12)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items) { item in
                    GridButton(item: item) {
                        onSelect(item.action)
                    }
                }
            }
            .padding()
        }
        // Converted UIKit system background to macOS AppKit alternative
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// 4. Reusable Grid Button Component
struct GridButton: View {
    let item: DashboardItem
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Icon Setup
                if item.isSystemIcon {
                    Image(systemName: item.iconName)
                        .font(.title2)
                        .foregroundColor(item.isHighlighted ? .white : .blue)
                } else {
                    Image(item.iconName)
                        .resizable()
                        .frame(width: 24, height: 24)
                }
                
                Spacer()
                
                // Label Setup
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(item.isHighlighted ? .white : .primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
            .padding()
            // Adaptive backgrounds for macOS Light/Dark appearance states
            .background(
                item.isHighlighted ?
                LinearGradient(colors: [Color.blue.opacity(0.85), Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing) :
                LinearGradient(colors: [Color(NSColor.controlBackgroundColor)], startPoint: .top, endPoint: .bottom)
            )
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
