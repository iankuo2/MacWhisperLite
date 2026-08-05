//
//  MacWhisperLiteApp.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-06-20.
//

import SwiftUI
import SwiftData

@main
struct MacWhisperLiteApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // injects the SwiftData storage into the environment
        .modelContainer(for: TranscriptItem.self)
    }
}
