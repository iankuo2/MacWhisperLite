//
//  ModelPickerView.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-07-01.
//


import SwiftUI

struct ModelPickerView: View {

    @Binding
    var selectedModel: WhisperModel
    

    var body: some View {

        Picker("Model", selection: $selectedModel) {

            ForEach(WhisperModel.allCases) { model in

                Text("\(model.displayName) – \(model.description) - \(model.memoryRequirement)")
                    .tag(model)
            }
        }
        .pickerStyle(.menu)
    }
}
