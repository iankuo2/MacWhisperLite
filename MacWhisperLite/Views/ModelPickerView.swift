//
//  ModelPickerView.swift
//  MacWhisperLite
//
//  Created by ian kuo on 2026-07-01.
//  Modified on 2026-07-22.
//

import SwiftUI

struct ModelPickerView: View {
    @Binding var selectedEngine: EngineType
    @Binding var selectedModel: WhisperModel
    
    var isDisabled: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // MARK: - Engine Selector
            Picker("Engine", selection: $selectedEngine) {
                ForEach(EngineType.allCases) { engine in
                    Text(engine.rawValue).tag(engine)
                }
            }
            .pickerStyle(.menu)
            
            Divider()
                .frame(height: 14)

            // MARK: - Model Selector
            Picker("Model", selection: $selectedModel) {
                ForEach(WhisperModel.allCases) { model in
                    Text("\(model.displayName) – \(model.description) (\(model.memoryRequirement))")
                        .tag(model)
                }
            }
            .pickerStyle(.menu)
        }
        .disabled(isDisabled)
    }
}
