//
//  LiveCaptionsView.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-07-14.
//


//
//  LiveCaptionsView.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-07-14.
//

import SwiftUI
import SwiftData

struct LiveCaptionsView: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    @Environment(\.modelContext) private var modelContext
    
    // Tracks the current detected microphone name for the UI label
    @State private var detectedMicName: String = "No Microphone"
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Main Top Portion: Real-time Transcript Canvas
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        if viewModel.transcript.isEmpty {
                            Text("Click the microphone icon or start live recording to stream captions...")
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .italic()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 40)
                        } else {
                            Text(viewModel.transcript)
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .lineSpacing(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("BottomMarker") // Anchors autoscroll location
                        }
                    }
                    .padding(24)
                }
                // Automatically scroll down as more live text populates the canvas
                .onChange(of: viewModel.transcript) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("BottomMarker", anchor: .bottom)
                    }
                }
            }
            
            Divider()
            
            // MARK: - Bottom Utility Toolbar
            HStack(spacing: 16) {
                // Recording / Toggle Action Button
                Button {
                    viewModel.toggleLiveRecording(context: modelContext)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.isLiveRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .foregroundColor(viewModel.isLiveRecording ? .red : .blue)
                            .font(.title3)
                        Text(viewModel.isLiveRecording ? "Stop Captions" : "Start Captions")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.isLiveRecording ? Color.red.opacity(0.15) : Color.blue.opacity(0.15))
                .foregroundColor(viewModel.isLiveRecording ? .red : .blue)
                
                Spacer()
                
                // Audio Source Selector Dropdown Button
                Menu {
                    Menu("Microphone") {
                        Button {
                            viewModel.selectedDevice = .microphone
                        } label: {
                            HStack {
                                Text(detectedMicName)
                                if viewModel.selectedDevice == .microphone {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    
                    Button {
                        // Bind this to your specific system/loopback audio wrapper enum if available
                        // viewModel.selectedDevice = .systemAudio 
                    } label: {
                        HStack {
                            Text("All System Audio")
                            // Add checkmark toggle logic if your model tracks it
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.and.mic")
                        Text(detectedMicName)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                
                Divider()
                    .frame(height: 16)
                
                // Close Action (Closes app window wrapper on macOS)
                Button("Close") {
                    NSApplication.shared.keyWindow?.close()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .onAppear {
            refreshHardwareStatus()
        }
    }
    
    /// Queries hardware layer to display the active device string
    private func refreshHardwareStatus() {
        let status = AudioDeviceDetector.checkAudioInputStatus()
        if status.hasInputDevice {
            self.detectedMicName = status.deviceName ?? "Default Microphone"
        } else {
            self.detectedMicName = "No Mic Detected"
        }
    }
}
